import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../core/crypto.dart';
import '../core/firebase_config.dart';

enum ConnState { offline, connecting, online }

class ConnectionException implements Exception {
  final String code;
  ConnectionException(this.code);
  @override
  String toString() => 'ConnectionException($code)';
}

/// Transport over Firebase: every identity has a Firestore queue of opaque,
/// end-to-end encrypted envelopes; blobs live encrypted in Cloud Storage.
/// Exposes the same small message protocol the app used with the relay.
class Connection {
  final String url;
  final String id;
  final Uint8List secretKey;
  final String mode;

  Connection({this.url = '', required this.id, required this.secretKey, this.mode = 'full'});

  final _incoming = StreamController<Map<String, dynamic>>.broadcast();
  final _state = StreamController<ConnState>.broadcast();
  StreamSubscription? _sub;
  ConnState state = ConnState.offline;
  String? token;
  List<Map<String, dynamic>> iceServers = [
    {
      'urls': ['stun:stun.l.google.com:19302']
    }
  ];
  int serverTimeOffset = 0;
  bool _closed = false;
  int _attempt = 0;
  Timer? _retry;
  final Set<String> _seen = {};
  void Function()? onAuthed;

  Stream<Map<String, dynamic>> get messages => _incoming.stream;
  Stream<ConnState> get states => _state.stream;

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  void _setState(ConnState s) {
    if (state == s) return;
    state = s;
    _state.add(s);
  }

  /// Creates a new identity for [publicKey]. Returns the assigned ID.
  static Future<String> register(String url, Uint8List publicKey) async {
    try {
      await FirebaseConfig.init();
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) await auth.signOut();
      await auth.signInAnonymously();
      final r = await FirebaseConfig.functions.httpsCallable('register').call({'pk': base64.encode(publicKey)});
      await auth.currentUser!.getIdToken(true);
      return (r.data as Map)['id'] as String;
    } on FirebaseException catch (e) {
      debugPrint('register: ${e.code} ${e.message}');
      throw ConnectionException(e.code);
    }
  }

  void start() {
    _closed = false;
    _connect();
  }

  Future<void> _connect() async {
    if (_closed || state != ConnState.offline) return;
    _setState(ConnState.connecting);
    try {
      await FirebaseConfig.init();
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
      var claims = (await user.getIdTokenResult()).claims ?? {};
      if (claims['nid'] != id) {
        await _bind();
        claims = (await user.getIdTokenResult(true)).claims ?? {};
        if (claims['nid'] != id) throw ConnectionException('auth_failed');
      }
      token = user.uid;
      await _loadIce();
      if (_closed) return;
      _sub = _db
          .collection('queues/$id/msgs')
          .orderBy('ts')
          .snapshots(includeMetadataChanges: true)
          .listen(_onSnapshot, onError: (e) {
        debugPrint('queue listener: $e');
        _onClosed();
      });
    } catch (e) {
      debugPrint('connect: $e');
      if (e is FirebaseException && (e.code == 'not-found' || e.code == 'permission-denied')) {
        _incoming.add({'t': 'error', 'error': e.code == 'not-found' ? 'unknown_id' : 'auth_failed'});
      }
      _onClosed();
    }
  }

  /// Proves possession of the identity key to bind it to this Firebase account.
  Future<void> _bind() async {
    final ch = await FirebaseConfig.functions.httpsCallable('bindChallenge').call();
    final data = Map<String, dynamic>.from(ch.data as Map);
    final n = Crypto.random(24);
    final box = Crypto.box(base64.decode(data['challenge'] as String), n, base64.decode(data['serverPk'] as String), secretKey);
    await FirebaseConfig.functions
        .httpsCallable('bind')
        .call({'id': id, 'n': base64.encode(n), 'box': base64.encode(box)});
  }

  Future<void> _loadIce() async {
    try {
      final r = await FirebaseConfig.functions.httpsCallable('ice').call();
      final data = Map<String, dynamic>.from(r.data as Map);
      final ice = (data['ice'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (ice != null && ice.isNotEmpty) iceServers = ice;
      final t = (data['time'] as num?)?.toInt();
      if (t != null) serverTimeOffset = t - DateTime.now().millisecondsSinceEpoch;
    } catch (e) {
      debugPrint('ice: $e');
    }
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!snap.metadata.isFromCache && state != ConnState.online) {
      _attempt = 0;
      _setState(ConnState.online);
      onAuthed?.call();
    } else if (snap.metadata.isFromCache && state == ConnState.online) {
      _setState(ConnState.connecting);
    }
    for (final ch in snap.docChanges) {
      if (ch.type != DocumentChangeType.added) continue;
      final d = ch.doc;
      if (d.metadata.hasPendingWrites || !_seen.add(d.id)) continue;
      final v = d.data();
      if (v == null) continue;
      final ts = (v['ts'] as Timestamp?)?.millisecondsSinceEpoch ?? serverNow;
      if (v['kind'] == 'eph') d.reference.delete().catchError((_) {});
      _incoming.add({'t': 'msg', 'mid': d.id, 'from': v['from'], 'data': v['data'], 'kind': v['kind'], 'ts': ts});
    }
  }

  void _onClosed() {
    _sub?.cancel();
    _sub = null;
    _setState(ConnState.offline);
    if (_closed) return;
    final delay = min(60, pow(2, _attempt).toInt()) + Random().nextInt(3);
    _attempt = min(_attempt + 1, 6);
    _retry?.cancel();
    _retry = Timer(Duration(seconds: delay), _connect);
  }

  /// Reconnect immediately (e.g. when network or app state changes).
  void kick() {
    if (_closed) return;
    if (state == ConnState.offline) {
      _retry?.cancel();
      _attempt = 0;
      _connect();
    }
  }

  void sendRaw(Map<String, dynamic> m) {
    if (state != ConnState.online) return;
    switch (m['t']) {
      case 'send':
        final to = m['to'] as String;
        final mid = m['mid'] as String;
        _db.doc('queues/$to/msgs/$mid').set({
          'from': id,
          'data': m['data'],
          'kind': m['kind'] ?? 'msg',
          'ts': FieldValue.serverTimestamp(),
        }).then((_) {
          _incoming.add({'t': 'sent', 'mid': mid, 'to': to, 'ts': serverNow});
        }).catchError((Object e) {
          debugPrint('send to $to failed: $e');
        });
        break;
      case 'ack':
        _db.doc('queues/$id/msgs/${m['mid']}').delete().catchError((_) {});
        break;
    }
  }

  Future<Map<String, dynamic>> request(Map<String, dynamic> m, {Duration timeout = const Duration(seconds: 20)}) async {
    if (state != ConnState.online) throw ConnectionException('offline');
    try {
      switch (m['t']) {
        case 'lookup':
          final d = await _db.doc('ids/${m['id']}').get().timeout(timeout);
          return {'t': 'key', 'id': m['id'], 'pk': d.data()?['pk']};
        case 'delete_identity':
          await FirebaseConfig.functions.httpsCallable('deleteIdentity').call();
          await FirebaseAuth.instance.signOut();
          return {'t': 'deleted'};
      }
    } on TimeoutException {
      throw ConnectionException('timeout');
    } on FirebaseException catch (e) {
      throw ConnectionException(e.code);
    }
    throw ConnectionException('unsupported');
  }

  /// Uploads an already encrypted blob. Returns its random ID.
  Future<String> uploadBlob(Uint8List data) async {
    final blobId = base64Url.encode(Crypto.random(18));
    await FirebaseStorage.instance
        .ref('blobs/$blobId')
        .putData(data, SettableMetadata(contentType: 'application/octet-stream'));
    return blobId;
  }

  Future<Uint8List?> downloadBlob(String blobId) =>
      FirebaseStorage.instance.ref('blobs/$blobId').getData(110 * 1024 * 1024);

  int get serverNow => DateTime.now().millisecondsSinceEpoch + serverTimeOffset;

  Future<void> close() async {
    _closed = true;
    _retry?.cancel();
    await _sub?.cancel();
    _sub = null;
    _setState(ConnState.offline);
  }
}

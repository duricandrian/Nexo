import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/crypto.dart';

enum ConnState { offline, connecting, online }

class ConnectionException implements Exception {
  final String code;
  ConnectionException(this.code);
  @override
  String toString() => 'ConnectionException($code)';
}

/// Authenticated WebSocket link to the relay server with automatic reconnect.
class Connection {
  final String url;
  final String id;
  final Uint8List secretKey;
  final String mode;

  Connection({required this.url, required this.id, required this.secretKey, this.mode = 'full'});

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  int _rid = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  final _incoming = StreamController<Map<String, dynamic>>.broadcast();
  final _state = StreamController<ConnState>.broadcast();
  ConnState state = ConnState.offline;
  String? token;
  List<Map<String, dynamic>> iceServers = [];
  int serverTimeOffset = 0;
  bool _closed = false;
  int _attempt = 0;
  Timer? _retry;
  void Function()? onAuthed;

  Stream<Map<String, dynamic>> get messages => _incoming.stream;
  Stream<ConnState> get states => _state.stream;

  void _setState(ConnState s) {
    state = s;
    _state.add(s);
  }

  /// Creates a new identity on the server. Returns the assigned ID.
  static Future<String> register(String url, Uint8List publicKey) async {
    final ch = IOWebSocketChannel.connect(Uri.parse(url), connectTimeout: const Duration(seconds: 15));
    await ch.ready;
    final it = StreamIterator(ch.stream);
    try {
      if (!await it.moveNext().timeout(const Duration(seconds: 15))) throw ConnectionException('closed');
      ch.sink.add(jsonEncode({'t': 'register', 'pk': base64.encode(publicKey)}));
      if (!await it.moveNext().timeout(const Duration(seconds: 15))) throw ConnectionException('closed');
      final m = jsonDecode(it.current as String) as Map<String, dynamic>;
      if (m['t'] != 'registered') throw ConnectionException(m['error']?.toString() ?? 'register_failed');
      return m['id'] as String;
    } finally {
      await it.cancel();
      await ch.sink.close();
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
      final ch = IOWebSocketChannel.connect(Uri.parse(url),
          pingInterval: const Duration(seconds: 25), connectTimeout: const Duration(seconds: 15));
      await ch.ready;
      _ch = ch;
      _sub = ch.stream.listen(_onData, onDone: _onClosed, onError: (_) => _onClosed());
    } catch (_) {
      _onClosed();
    }
  }

  void _onData(dynamic raw) {
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (m['t'] == 'challenge') {
      final challenge = base64.decode(m['challenge'] as String);
      final serverPk = base64.decode(m['serverPk'] as String);
      final n = Crypto.random(24);
      final box = Crypto.box(challenge, n, serverPk, secretKey);
      _send({'t': 'auth', 'rid': 0, 'id': id, 'n': base64.encode(n), 'box': base64.encode(box), 'mode': mode});
      return;
    }
    if (m['t'] == 'authed') {
      token = m['token'] as String?;
      iceServers = ((m['ice'] as List?) ?? []).cast<Map<String, dynamic>>();
      serverTimeOffset = ((m['time'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch) -
          DateTime.now().millisecondsSinceEpoch;
      _attempt = 0;
      _setState(ConnState.online);
      onAuthed?.call();
      return;
    }
    if (m['t'] == 'error' && (m['error'] == 'auth_failed' || m['error'] == 'unknown_id')) {
      _incoming.add(m);
      close();
      return;
    }
    final rid = m['rid'];
    if (rid is int && rid > 0 && _pending.containsKey(rid)) {
      final c = _pending.remove(rid)!;
      if (m['t'] == 'error') {
        c.completeError(ConnectionException(m['error']?.toString() ?? 'error'));
      } else {
        c.complete(m);
      }
      if (m['t'] != 'sent') return;
    }
    _incoming.add(m);
  }

  void _onClosed() {
    _sub?.cancel();
    _sub = null;
    _ch = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(ConnectionException('disconnected'));
    }
    _pending.clear();
    if (state != ConnState.offline) _setState(ConnState.offline);
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

  void _send(Map<String, dynamic> m) => _ch?.sink.add(jsonEncode(m));

  void sendRaw(Map<String, dynamic> m) {
    if (state == ConnState.online) _send(m);
  }

  Future<Map<String, dynamic>> request(Map<String, dynamic> m, {Duration timeout = const Duration(seconds: 20)}) {
    if (state != ConnState.online) return Future.error(ConnectionException('offline'));
    final rid = ++_rid;
    final c = Completer<Map<String, dynamic>>();
    _pending[rid] = c;
    _send({...m, 'rid': rid});
    return c.future.timeout(timeout, onTimeout: () {
      _pending.remove(rid);
      throw ConnectionException('timeout');
    });
  }

  int get serverNow => DateTime.now().millisecondsSinceEpoch + serverTimeOffset;

  Future<void> close() async {
    _closed = true;
    _retry?.cancel();
    await _sub?.cancel();
    await _ch?.sink.close();
    _ch = null;
    _sub = null;
    if (state != ConnState.offline) _setState(ConnState.offline);
  }
}

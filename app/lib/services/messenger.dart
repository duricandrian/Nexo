import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';
import '../core/crypto.dart';
import '../data/db.dart';
import '../data/models.dart';
import 'background.dart';
import 'connection.dart';
import 'identity.dart';
import 'notifications.dart';

class CallSignal {
  final String from;
  final Map<String, dynamic> payload;
  final int ts;
  CallSignal(this.from, this.payload, this.ts);
}

class ContactException implements Exception {
  final String code;
  ContactException(this.code);
}

/// Core messaging engine: contacts, groups, chats, E2E messages, receipts.
class Messenger extends ChangeNotifier {
  final Identity me;
  final Database db;
  final String serverUrl;
  late final Connection conn;
  final _uuid = const Uuid();

  final Map<String, Contact> contacts = {};
  final Map<String, Group> groups = {};
  final Map<String, Chat> chatMap = {};
  final Map<String, Map<String, DateTime>> _typing = {};
  final _chatChanges = StreamController<String>.broadcast();
  final _callSignals = StreamController<CallSignal>.broadcast();

  String nickname = '';
  bool readReceipts = true;
  bool typingIndicators = true;
  String? activeChat;
  bool inForeground = true;
  bool identityRevoked = false;
  Future<void> _queue = Future.value();
  Directory? _mediaDir;

  Messenger._(this.me, this.db, this.serverUrl);

  Stream<String> get chatChanges => _chatChanges.stream;
  Stream<CallSignal> get callSignals => _callSignals.stream;
  ConnState get connState => conn.state;

  static Future<Messenger> create(Identity me) async {
    final m = Messenger._(me, await AppDatabase.open(), await AppConfig.serverUrl());
    await m._load();
    return m;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    nickname = prefs.getString('nickname') ?? '';
    readReceipts = prefs.getBool('read_receipts') ?? true;
    typingIndicators = prefs.getBool('typing_indicators') ?? true;
    for (final r in await db.query('contacts')) {
      final c = Contact.fromRow(r);
      contacts[c.id] = c;
    }
    for (final r in await db.query('groups')) {
      final g = Group.fromRow(r);
      groups[g.key] = g;
    }
    for (final r in await db.query('chats')) {
      final c = Chat.fromRow(r);
      chatMap[c.key] = c;
    }
    _mediaDir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'media'));
    await _mediaDir!.create(recursive: true);
  }

  void start() {
    conn = Connection(url: serverUrl, id: me.id, secretKey: me.secretKey);
    conn.onAuthed = () {
      PushService.register(me.id);
      _flushOutbox();
      _retryUploads();
    };
    conn.messages.listen((m) => _queue = _queue.then((_) => _onServer(m)).catchError((e) => debugPrint('msg error $e')));
    conn.states.listen((_) => notifyListeners());
    conn.start();
  }

  @override
  void dispose() {
    conn.close();
    super.dispose();
  }

  // ---------------------------------------------------------------- settings

  Future<void> setNickname(String v) async {
    nickname = v.trim();
    (await SharedPreferences.getInstance()).setString('nickname', nickname);
    notifyListeners();
  }

  Future<void> setReadReceipts(bool v) async {
    readReceipts = v;
    (await SharedPreferences.getInstance()).setBool('read_receipts', v);
    notifyListeners();
  }

  Future<void> setTypingIndicators(bool v) async {
    typingIndicators = v;
    (await SharedPreferences.getInstance()).setBool('typing_indicators', v);
    notifyListeners();
  }

  // ---------------------------------------------------------------- queries

  List<Chat> get chats {
    final list = chatMap.values.where((c) {
      if (c.isGroup) return groups.containsKey(c.key);
      final contact = contacts[c.contactId];
      return contact != null && !contact.blocked;
    }).toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.lastTs.compareTo(a.lastTs);
    });
    return list;
  }

  List<Contact> get visibleContacts {
    final list = contacts.values.where((c) => !c.hidden).toList();
    list.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return list;
  }

  int get totalUnread => chatMap.values.fold(0, (s, c) => s + c.unread);

  String chatTitle(String key) {
    if (key.startsWith('g:')) return groups[key]?.name ?? '?';
    return nameOf(key.substring(2));
  }

  String nameOf(String id) => id == me.id ? (nickname.isEmpty ? me.id : nickname) : (contacts[id]?.displayName ?? id);

  bool isTyping(String chat) {
    final m = _typing[chat];
    if (m == null) return false;
    m.removeWhere((_, t) => DateTime.now().difference(t).inSeconds > 6);
    return m.isNotEmpty;
  }

  Future<List<Message>> loadMessages(String chat, {int limit = 60, int? beforeTs}) async {
    final rows = await db.query('messages',
        where: beforeTs == null ? 'chat = ?' : 'chat = ? AND ts < ?',
        whereArgs: beforeTs == null ? [chat] : [chat, beforeTs],
        orderBy: 'ts DESC',
        limit: limit);
    return rows.map(Message.fromRow).toList();
  }

  Future<List<Message>> searchMessages(String chat, String q) async {
    final rows = await db.query('messages',
        where: 'chat = ? AND deleted = 0 AND body LIKE ?', whereArgs: [chat, '%$q%'], orderBy: 'ts DESC', limit: 100);
    return rows.map(Message.fromRow).toList();
  }

  Future<List<Message>> mediaMessages(String chat) async {
    final rows = await db.query('messages',
        where: "chat = ? AND deleted = 0 AND type IN ('image','file','audio') AND local_path IS NOT NULL",
        whereArgs: [chat],
        orderBy: 'ts DESC');
    return rows.map(Message.fromRow).toList();
  }

  Future<Message?> getMessage(String chat, String id) async {
    final rows = await db.query('messages', where: 'chat = ? AND id = ?', whereArgs: [chat, id]);
    return rows.isEmpty ? null : Message.fromRow(rows.first);
  }

  Future<List<CallRecord>> callHistory() async =>
      (await db.query('calls', orderBy: 'ts DESC', limit: 200)).map(CallRecord.fromRow).toList();

  // ---------------------------------------------------------------- contacts

  static String qrPayload(Identity me) => 'nexo:${me.id}:${base64Url.encode(me.publicKey)}';

  Future<Contact> addContactById(String rawId) async {
    final id = rawId.trim().toUpperCase();
    if (id == me.id) throw ContactException('self');
    if (!RegExp(r'^[A-Z0-9]{8}$').hasMatch(id)) throw ContactException('invalid');
    final existing = contacts[id];
    if (existing != null) {
      if (existing.hidden) {
        existing.hidden = false;
        await _saveContact(existing);
      }
      return existing;
    }
    final c = await _fetchContact(id);
    if (c == null) throw ContactException('not_found');
    return c;
  }

  Future<Contact> addContactFromQr(String data) async {
    final parts = data.trim().split(':');
    if (parts.length != 3 || parts[0] != 'nexo') throw ContactException('invalid');
    final id = parts[1].toUpperCase();
    if (id == me.id) throw ContactException('self');
    final pk = base64Url.decode(parts[2]);
    final existing = contacts[id];
    if (existing != null) {
      if (!listEquals(existing.pk, pk)) throw ContactException('key_mismatch');
      existing.verified = 3;
      existing.hidden = false;
      await _saveContact(existing);
      return existing;
    }
    if (conn.state == ConnState.online) {
      final r = await conn.request({'t': 'lookup', 'id': id});
      if (r['pk'] == null) throw ContactException('not_found');
      if (!listEquals(base64.decode(r['pk'] as String), pk)) throw ContactException('key_mismatch');
    }
    final c = Contact(id: id, pk: Uint8List.fromList(pk), verified: 3);
    await _saveContact(c);
    return c;
  }

  Future<Contact?> _fetchContact(String id, {bool hidden = false}) async {
    if (contacts.containsKey(id)) return contacts[id];
    if (conn.state != ConnState.online) throw ContactException('offline');
    final r = await conn.request({'t': 'lookup', 'id': id});
    if (r['pk'] == null) return null;
    final c = Contact(id: id, pk: base64.decode(r['pk'] as String), hidden: hidden);
    await _saveContact(c);
    return c;
  }

  Future<void> _saveContact(Contact c) async {
    contacts[c.id] = c;
    await db.insert('contacts', c.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }

  Future<void> renameContact(Contact c, String name) async {
    c.name = name.trim().isEmpty ? null : name.trim();
    await _saveContact(c);
  }

  Future<void> setBlocked(Contact c, bool blocked) async {
    c.blocked = blocked;
    await _saveContact(c);
  }

  Future<void> deleteContact(Contact c) async {
    final inGroup = groups.values.any((g) => !g.left && g.members.contains(c.id));
    await deleteChat(Chat.forContact(c.id));
    if (inGroup) {
      c.hidden = true;
      await _saveContact(c);
    } else {
      contacts.remove(c.id);
      await db.delete('contacts', where: 'id = ?', whereArgs: [c.id]);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- chats

  Chat chatFor(String key) => chatMap.putIfAbsent(key, () => Chat(key: key));

  Future<void> _saveChat(Chat c) async {
    chatMap[c.key] = c;
    await db.insert('chats', c.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // A chat screen can be pushed again before the old one is disposed
  // (e.g. from a notification), so track how many screens show each chat.
  final Map<String, int> _openScreens = {};

  Future<void> openChat(String key) async {
    _openScreens[key] = (_openScreens[key] ?? 0) + 1;
    activeChat = key;
    await markRead(key);
    Notifications.cancelChat(key);
  }

  void closeChat(String key) {
    final n = (_openScreens[key] ?? 1) - 1;
    if (n > 0) {
      _openScreens[key] = n;
      return;
    }
    _openScreens.remove(key);
    if (activeChat == key) activeChat = _openScreens.keys.isEmpty ? null : _openScreens.keys.last;
  }

  Future<void> setDraft(String key, String draft) async {
    final c = chatFor(key);
    c.draft = draft.isEmpty ? null : draft;
    await _saveChat(c);
  }

  Future<void> setMuted(String key, bool muted) async {
    final c = chatFor(key)..muted = muted;
    await _saveChat(c);
    notifyListeners();
  }

  Future<void> setPinned(String key, bool pinned) async {
    final c = chatFor(key)..pinned = pinned;
    await _saveChat(c);
    notifyListeners();
  }

  Future<void> clearChat(String key) async {
    for (final r in await db.query('messages', columns: ['local_path'], where: 'chat = ? AND local_path IS NOT NULL', whereArgs: [key])) {
      _deleteFile(r['local_path'] as String?);
    }
    await db.delete('messages', where: 'chat = ?', whereArgs: [key]);
    final c = chatFor(key)
      ..lastText = null
      ..unread = 0;
    await _saveChat(c);
    _chatChanges.add(key);
    notifyListeners();
  }

  Future<void> deleteChat(String key) async {
    await clearChat(key);
    chatMap.remove(key);
    await db.delete('chats', where: 'key = ?', whereArgs: [key]);
    notifyListeners();
  }

  Future<void> markRead(String key) async {
    final c = chatMap[key];
    if (c != null && c.unread > 0) {
      c.unread = 0;
      await _saveChat(c);
      notifyListeners();
    }
    if (key.startsWith('c:')) {
      final rows = await db.query('messages',
          columns: ['id'], where: 'chat = ? AND outgoing = 0 AND status = ?', whereArgs: [key, MsgStatus.received]);
      if (rows.isEmpty) return;
      final ids = rows.map((r) => r['id'] as String).toList();
      await db.update('messages', {'status': MsgStatus.read}, where: 'chat = ? AND outgoing = 0 AND status = ?', whereArgs: [key, MsgStatus.received]);
      if (readReceipts) {
        await _sendTo(key.substring(2), {'type': 'receipt', 'status': MsgStatus.read, 'ids': ids});
      }
    }
  }

  void _touchChat(String key, String? text, int ts, {bool incoming = false}) {
    final c = chatFor(key);
    c.lastText = text;
    if (ts >= c.lastTs) c.lastTs = ts;
    if (incoming && !(inForeground && activeChat == key)) c.unread += 1;
    _saveChat(c);
  }

  static String previewOf(Message m) {
    if (m.deleted) return '🚫';
    switch (m.type) {
      case 'image':
        return '📷 ${m.body ?? ''}'.trim();
      case 'file':
        return '📎 ${m.meta['name'] ?? ''}';
      case 'audio':
        return '🎤 ${_fmtDur(m.meta['dur'] as int? ?? 0)}';
      case 'location':
        return '📍';
      default:
        return m.body ?? '';
    }
  }

  static String _fmtDur(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------- sending

  String newId() => _uuid.v4().replaceAll('-', '');

  Future<void> _sendTo(String recipient, Map<String, dynamic> payload,
      {String kind = 'msg', String? chat, String? msgId, String? mid}) async {
    final c = contacts[recipient];
    if (c == null) return;
    final full = {...payload, 'nick': nickname, 'ts': payload['ts'] ?? conn.serverNow};
    final data = Crypto.sealEnvelope(full, c.pk, me.secretKey);
    final envelopeId = mid ?? newId();
    if (kind != 'eph') {
      await db.insert(
          'outbox',
          {
            'mid': envelopeId,
            'recipient': recipient,
            'data': data,
            'kind': kind,
            'chat': chat,
            'msg_id': msgId,
            'created': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    conn.sendRaw({'t': 'send', 'to': recipient, 'mid': envelopeId, 'data': data, 'kind': kind});
  }

  /// Sends [payload] to all participants of [chat] (one envelope per member).
  Future<void> _sendToChat(String chat, Map<String, dynamic> payload, {String kind = 'msg', String? msgId}) async {
    if (chat.startsWith('g:')) {
      final g = groups[chat];
      if (g == null || g.left) return;
      final withGroup = {...payload, 'g': {'c': g.creator, 'g': g.gid}};
      for (final member in g.members) {
        if (member == me.id) continue;
        await _sendTo(member, withGroup, kind: kind, chat: chat, msgId: msgId, mid: msgId);
      }
    } else {
      await _sendTo(chat.substring(2), payload, kind: kind, chat: chat, msgId: msgId, mid: msgId);
    }
  }

  /// Sends a call signaling payload to one peer (optionally scoped to a group).
  Future<void> sendCallSignal(String peer, Map<String, dynamic> payload, {bool ephemeral = false}) async {
    if (!contacts.containsKey(peer)) await _fetchContact(peer, hidden: true);
    await _sendTo(peer, payload, kind: ephemeral ? 'eph' : (payload['type'] == 'call-offer' ? 'call' : 'msg'));
  }

  Future<void> sendGroupCallSignal(String groupKey, Map<String, dynamic> payload) =>
      _sendToChat(groupKey, payload, kind: payload['type'] == 'gcall-start' ? 'call' : 'msg');

  Future<void> _flushOutbox() async {
    final rows = await db.query('outbox', orderBy: 'created');
    final cutoff = DateTime.now().millisecondsSinceEpoch - 60000;
    for (final r in rows) {
      // Stale call signaling is useless; drop it instead of replaying it.
      if (r['kind'] == 'call' && (r['created'] as int) < cutoff) {
        await db.delete('outbox', where: 'mid = ? AND recipient = ?', whereArgs: [r['mid'], r['recipient']]);
        continue;
      }
      conn.sendRaw({'t': 'send', 'to': r['recipient'], 'mid': r['mid'], 'data': r['data'], 'kind': r['kind']});
    }
  }

  Future<Message> _insertOutgoing(String chat, String type, {String? body, Map<String, dynamic>? meta, String? localPath}) async {
    final msg = Message(
      chat: chat,
      id: newId(),
      sender: me.id,
      outgoing: true,
      type: type,
      body: body,
      meta: meta,
      status: MsgStatus.pending,
      ts: conn.serverNow,
      localPath: localPath,
    );
    await db.insert('messages', msg.toRow());
    _touchChat(chat, previewOf(msg), msg.ts);
    _chatChanges.add(chat);
    notifyListeners();
    return msg;
  }

  Map<String, dynamic>? _replyMeta(Message? reply) => reply == null
      ? null
      : {'id': reply.id, 'sender': reply.sender, 'preview': previewOf(reply).characters.take(120).toString()};

  Future<void> sendText(String chat, String text, {Message? replyTo}) async {
    final reply = _replyMeta(replyTo);
    final msg = await _insertOutgoing(chat, 'text', body: text, meta: reply == null ? null : {'reply': reply});
    await _sendToChat(chat, {'type': 'text', 'id': msg.id, 'ts': msg.ts, 'text': text, 'reply': ?reply},
        msgId: msg.id);
  }

  Future<void> sendLocation(String chat, double lat, double lon) async {
    final msg = await _insertOutgoing(chat, 'location', meta: {'lat': lat, 'lon': lon});
    await _sendToChat(chat, {'type': 'location', 'id': msg.id, 'ts': msg.ts, 'lat': lat, 'lon': lon}, msgId: msg.id);
  }

  /// Copies [file] into app storage and sends it as image/file/audio.
  Future<void> sendMedia(String chat, File file, String type,
      {String? caption, String? name, Map<String, dynamic>? extra, Message? replyTo}) async {
    final fileName = name ?? p.basename(file.path);
    final local = await _storeLocal(await file.readAsBytes(), fileName);
    final reply = _replyMeta(replyTo);
    final meta = <String, dynamic>{
      'name': fileName,
      'size': await local.length(),
      ...?extra,
      'reply': ?reply,
    };
    final msg = await _insertOutgoing(chat, type, body: caption, meta: meta, localPath: local.path);
    await _uploadAndSend(msg);
  }

  Future<File> _storeLocal(Uint8List bytes, String name) async {
    final safe = name.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final f = File(p.join(_mediaDir!.path, '${newId().substring(0, 12)}_$safe'));
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  Future<void> _uploadAndSend(Message msg) async {
    if (conn.state != ConnState.online || conn.token == null || msg.localPath == null) return;
    try {
      final bytes = await File(msg.localPath!).readAsBytes();
      final enc = await Crypto.encryptBlob(bytes);
      final blobId = await conn.uploadBlob(enc.data).timeout(const Duration(minutes: 5));
      msg.meta['blob'] = blobId;
      msg.meta['key'] = base64.encode(enc.key);
      await db.update('messages', {'meta': jsonEncode(msg.meta)}, where: 'chat = ? AND id = ?', whereArgs: [msg.chat, msg.id]);
      await _sendToChat(
          msg.chat,
          {
            'type': msg.type,
            'id': msg.id,
            'ts': msg.ts,
            if (msg.body != null) 'caption': msg.body,
            ...msg.meta,
          },
          msgId: msg.id);
    } catch (e) {
      debugPrint('upload failed: $e');
    }
  }

  Future<void> _retryUploads() async {
    final rows = await db.query('messages',
        where: "outgoing = 1 AND status = ? AND type IN ('image','file','audio')", whereArgs: [MsgStatus.pending]);
    for (final r in rows) {
      final m = Message.fromRow(r);
      if (m.meta['blob'] == null) await _uploadAndSend(m);
    }
  }

  Future<void> retry(Message msg) async {
    if (msg.meta['blob'] == null && msg.localPath != null) {
      await _uploadAndSend(msg);
    } else {
      await _flushOutbox();
    }
  }

  Future<void> react(Message msg, String emoji) async {
    final current = msg.reactions[me.id];
    final value = current == emoji ? '' : emoji;
    if (value.isEmpty) {
      msg.reactions.remove(me.id);
    } else {
      msg.reactions[me.id] = value;
    }
    await db.update('messages', {'reactions': jsonEncode(msg.reactions)}, where: 'chat = ? AND id = ?', whereArgs: [msg.chat, msg.id]);
    _chatChanges.add(msg.chat);
    await _sendToChat(msg.chat, {'type': 'reaction', 'target': msg.id, 'emoji': value});
  }

  Future<void> deleteForMe(Message msg) async {
    _deleteFile(msg.localPath);
    await db.delete('messages', where: 'chat = ? AND id = ?', whereArgs: [msg.chat, msg.id]);
    _chatChanges.add(msg.chat);
  }

  Future<void> deleteForEveryone(Message msg) async {
    if (!msg.outgoing) return;
    await _markDeleted(msg);
    await _sendToChat(msg.chat, {'type': 'delete', 'target': msg.id});
  }

  Future<void> _markDeleted(Message msg) async {
    _deleteFile(msg.localPath);
    await db.update('messages', {'deleted': 1, 'body': null, 'meta': '{}', 'local_path': null, 'reactions': '{}'},
        where: 'chat = ? AND id = ?', whereArgs: [msg.chat, msg.id]);
    _chatChanges.add(msg.chat);
  }

  Future<void> editMessage(Message msg, String text) async {
    if (!msg.outgoing || msg.type != 'text') return;
    await db.update('messages', {'body': text, 'edited': 1}, where: 'chat = ? AND id = ?', whereArgs: [msg.chat, msg.id]);
    _chatChanges.add(msg.chat);
    await _sendToChat(msg.chat, {'type': 'edit', 'target': msg.id, 'text': text});
  }

  DateTime _lastTypingSent = DateTime(2000);
  void sendTyping(String chat) {
    if (!typingIndicators || chat.startsWith('g:') || conn.state != ConnState.online) return;
    if (DateTime.now().difference(_lastTypingSent).inSeconds < 4) return;
    _lastTypingSent = DateTime.now();
    _sendToChat(chat, {'type': 'typing'}, kind: 'eph');
  }

  void _deleteFile(String? path) {
    if (path == null) return;
    final f = File(path);
    f.exists().then((e) {
      if (e) f.delete().ignore();
    });
  }

  Future<void> addCallRecord(CallRecord r) async {
    await db.insert('calls', r.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }

  Future<void> clearCallHistory() async {
    await db.delete('calls');
    notifyListeners();
  }

  // ---------------------------------------------------------------- groups

  Future<Group> createGroup(String name, List<String> memberIds) async {
    final g = Group(gid: newId().substring(0, 16), creator: me.id, name: name.trim(), members: [me.id, ...memberIds]);
    await _saveGroup(g);
    final chat = chatFor(g.key)..lastTs = conn.serverNow;
    await _saveChat(chat);
    await _addSystem(g.key, 'group_created', {'by': me.id});
    await _sendGroupSetup(g, g.members);
    notifyListeners();
    return g;
  }

  Future<void> updateGroup(Group g, {String? name, List<String>? members}) async {
    if (g.creator != me.id) return;
    final recipients = {...g.members, ...?members}.toList();
    if (name != null && name.trim().isNotEmpty && name != g.name) {
      g.name = name.trim();
      await _addSystem(g.key, 'group_renamed', {'by': me.id, 'name': g.name});
    }
    if (members != null) {
      final newSet = {me.id, ...members};
      for (final added in newSet.difference(g.members.toSet())) {
        await _addSystem(g.key, 'member_added', {'by': me.id, 'id': added});
      }
      for (final removed in g.members.toSet().difference(newSet)) {
        await _addSystem(g.key, 'member_removed', {'by': me.id, 'id': removed});
      }
      g.members = newSet.toList();
    }
    await _saveGroup(g);
    await _sendGroupSetup(g, recipients);
    notifyListeners();
  }

  Future<void> _sendGroupSetup(Group g, List<String> recipients) async {
    for (final r in recipients) {
      if (r == me.id) continue;
      await _sendTo(r, {
        'type': 'group-setup',
        'g': {'c': g.creator, 'g': g.gid},
        'name': g.name,
        'members': g.members,
      });
    }
  }

  Future<void> leaveGroup(Group g) async {
    if (g.creator == me.id) {
      final old = g.members;
      g.members = [];
      await _sendGroupSetup(g, old);
    } else {
      await _sendToChat(g.key, {'type': 'group-leave'});
    }
    g.left = true;
    await _saveGroup(g);
    await _addSystem(g.key, 'you_left', {});
    notifyListeners();
  }

  Future<void> deleteGroup(Group g) async {
    if (!g.left) await leaveGroup(g);
    await deleteChat(g.key);
    groups.remove(g.key);
    await db.delete('groups', where: 'key = ?', whereArgs: [g.key]);
    notifyListeners();
  }

  Future<void> _saveGroup(Group g) async {
    groups[g.key] = g;
    await db.insert('groups', g.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _addSystem(String chat, String event, Map<String, dynamic> meta) async {
    final msg = Message(
      chat: chat,
      id: newId(),
      sender: me.id,
      outgoing: false,
      type: 'system',
      body: event,
      meta: meta,
      status: MsgStatus.read,
      ts: conn.serverNow,
    );
    await db.insert('messages', msg.toRow());
    _chatChanges.add(chat);
  }

  // ---------------------------------------------------------------- receiving

  Future<void> _onServer(Map<String, dynamic> m) async {
    switch (m['t']) {
      case 'msg':
        try {
          await _onEnvelope(m);
        } finally {
          if (m['kind'] != 'eph') conn.sendRaw({'t': 'ack', 'mid': m['mid']});
        }
        break;
      case 'sent':
        await _onSent(m['mid'] as String, m['to'] as String?);
        break;
      case 'error':
        if (m['error'] == 'auth_failed' || m['error'] == 'unknown_id') {
          identityRevoked = true;
          notifyListeners();
        } else if (m['error'] == 'unknown_recipient' && m['mid'] != null) {
          await db.delete('outbox', where: 'mid = ?', whereArgs: [m['mid']]);
        }
        break;
    }
  }

  Future<void> _onSent(String mid, String? to) async {
    final rows = await db.query('outbox', where: 'mid = ? AND recipient = ?', whereArgs: [mid, to]);
    if (rows.isEmpty) return;
    final chat = rows.first['chat'] as String?;
    final msgId = rows.first['msg_id'] as String?;
    await db.delete('outbox', where: 'mid = ? AND recipient = ?', whereArgs: [mid, to]);
    if (chat == null || msgId == null) return;
    final remaining = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM outbox WHERE msg_id = ?', [msgId])) ?? 0;
    if (remaining == 0) {
      await db.update('messages', {'status': MsgStatus.sent},
          where: 'chat = ? AND id = ? AND status = ?', whereArgs: [chat, msgId, MsgStatus.pending]);
      _chatChanges.add(chat);
    }
  }

  Future<void> _onEnvelope(Map<String, dynamic> m) async {
    final from = m['from'] as String;
    var contact = contacts[from];
    contact ??= await _fetchContact(from, hidden: false);
    if (contact == null || contact.blocked) return;
    final payload = Crypto.openEnvelope(m['data'] as String, contact.pk, me.secretKey);
    if (payload == null) return;
    final serverTs = (m['ts'] as num?)?.toInt() ?? conn.serverNow;
    final ts = (payload['ts'] as num?)?.toInt() ?? serverTs;

    final nick = payload['nick'] as String?;
    if (nick != null && nick != contact.nick) {
      contact.nick = nick;
      await _saveContact(contact);
    }

    final type = payload['type'] as String? ?? '';
    final g = payload['g'];
    String chat = Chat.forContact(from);
    if (g is Map) {
      final key = 'g:${g['c']}:${g['g']}';
      if (type == 'group-setup') return _onGroupSetup(from, g, payload);
      final group = groups[key];
      if (group == null || group.left || !group.members.contains(from)) return;
      chat = key;
    } else if (contact.hidden && const {'text', 'image', 'file', 'audio', 'location'}.contains(type)) {
      contact.hidden = false;
      await _saveContact(contact);
    }

    switch (type) {
      case 'text':
      case 'image':
      case 'file':
      case 'audio':
      case 'location':
        await _onContent(chat, from, type, payload, ts);
        break;
      case 'receipt':
        await _onReceipt(Chat.forContact(from), payload);
        break;
      case 'typing':
        (_typing[chat] ??= {})[from] = DateTime.now();
        _chatChanges.add(chat);
        notifyListeners();
        Timer(const Duration(seconds: 7), () {
          _chatChanges.add(chat);
          notifyListeners();
        });
        break;
      case 'reaction':
        final msg = await getMessage(chat, payload['target'] as String? ?? '');
        if (msg == null) return;
        final emoji = payload['emoji'] as String? ?? '';
        if (emoji.isEmpty) {
          msg.reactions.remove(from);
        } else {
          msg.reactions[from] = emoji.characters.take(1).toString();
        }
        await db.update('messages', {'reactions': jsonEncode(msg.reactions)}, where: 'chat = ? AND id = ?', whereArgs: [chat, msg.id]);
        _chatChanges.add(chat);
        break;
      case 'delete':
        final msg = await getMessage(chat, payload['target'] as String? ?? '');
        if (msg != null && msg.sender == from) await _markDeleted(msg);
        break;
      case 'edit':
        final msg = await getMessage(chat, payload['target'] as String? ?? '');
        if (msg != null && msg.sender == from && msg.type == 'text') {
          await db.update('messages', {'body': payload['text'], 'edited': 1}, where: 'chat = ? AND id = ?', whereArgs: [chat, msg.id]);
          _chatChanges.add(chat);
        }
        break;
      case 'group-leave':
        final group = groups[chat];
        if (group != null) {
          group.members.remove(from);
          await _saveGroup(group);
          await _addSystem(chat, 'member_left', {'id': from});
          notifyListeners();
        }
        break;
      default:
        if (type.startsWith('call-') || type.startsWith('gcall-')) {
          if (g is Map) payload['group'] = chat;
          _callSignals.add(CallSignal(from, payload, serverTs));
        }
    }
  }

  Future<void> _onContent(String chat, String from, String type, Map<String, dynamic> p, int ts) async {
    final id = p['id'] as String?;
    if (id == null || await getMessage(chat, id) != null) return;
    final meta = <String, dynamic>{};
    for (final k in const ['blob', 'key', 'name', 'size', 'mime', 'dur', 'w', 'h', 'thumb', 'reply', 'lat', 'lon', 'wave']) {
      if (p[k] != null) meta[k] = p[k];
    }
    final msg = Message(
      chat: chat,
      id: id,
      sender: from,
      outgoing: false,
      type: type,
      body: type == 'text' ? p['text'] as String? : p['caption'] as String?,
      meta: meta,
      status: MsgStatus.received,
      ts: ts,
    );
    await db.insert('messages', msg.toRow(), conflictAlgorithm: ConflictAlgorithm.ignore);
    _touchChat(chat, previewOf(msg), ts, incoming: true);
    if (chat.startsWith('c:')) {
      await _sendTo(from, {'type': 'receipt', 'status': MsgStatus.delivered, 'ids': [id]});
      if (inForeground && activeChat == chat) await markRead(chat);
    }
    _chatChanges.add(chat);
    notifyListeners();
    final c = chatMap[chat];
    if (!(inForeground && activeChat == chat) && !(c?.muted ?? false)) {
      final title = chat.startsWith('g:') ? '${chatTitle(chat)}: ${nameOf(from)}' : nameOf(from);
      Notifications.showMessage(chat: chat, title: title, body: previewOf(msg));
    }
    final size = (meta['size'] as num?)?.toInt() ?? 0;
    if ((type == 'image' || type == 'audio') && size < 20 * 1024 * 1024) {
      unawaited(downloadMedia(msg));
    }
  }

  Future<void> _onReceipt(String chat, Map<String, dynamic> p) async {
    final status = p['status'] as String?;
    final ids = (p['ids'] as List?)?.cast<String>() ?? [];
    if (!MsgStatus.order.contains(status)) return;
    final rank = MsgStatus.order.indexOf(status!);
    for (final id in ids) {
      final msg = await getMessage(chat, id);
      if (msg == null || !msg.outgoing) continue;
      if (MsgStatus.order.indexOf(msg.status) < rank) {
        await db.update('messages', {'status': status}, where: 'chat = ? AND id = ?', whereArgs: [chat, id]);
      }
    }
    _chatChanges.add(chat);
  }

  Future<void> _onGroupSetup(String from, Map g, Map<String, dynamic> p) async {
    final creator = g['c'] as String;
    if (creator != from) return;
    final key = 'g:$creator:${g['g']}';
    final members = ((p['members'] as List?) ?? []).cast<String>();
    final existing = groups[key];
    if (!members.contains(me.id)) {
      if (existing != null && !existing.left) {
        existing.left = true;
        await _saveGroup(existing);
        await _addSystem(key, 'you_were_removed', {});
        notifyListeners();
      }
      return;
    }
    for (final id in members) {
      if (id != me.id && !contacts.containsKey(id)) {
        try {
          await _fetchContact(id, hidden: true);
        } catch (_) {}
      }
    }
    final group = existing ?? Group(gid: g['g'] as String, creator: creator, name: '', members: []);
    final isNew = existing == null || existing.left;
    final name = (p['name'] as String? ?? '').trim();
    if (!isNew && name != group.name) await _addSystem(key, 'group_renamed', {'by': from, 'name': name});
    group
      ..name = name.isEmpty ? '?' : name
      ..members = members
      ..left = false;
    await _saveGroup(group);
    if (isNew) {
      await _addSystem(key, 'added_to_group', {'by': from});
      _touchChat(key, null, conn.serverNow);
    }
    notifyListeners();
  }

  Future<String?> downloadMedia(Message msg) async {
    if (msg.localPath != null && await File(msg.localPath!).exists()) return msg.localPath;
    final blob = msg.meta['blob'] as String?;
    final key = msg.meta['key'] as String?;
    if (blob == null || key == null || conn.token == null) return null;
    try {
      final data = await conn.downloadBlob(blob).timeout(const Duration(minutes: 5));
      if (data == null) return null;
      final plain = await Crypto.decryptBlob(data, base64.decode(key));
      if (plain == null) return null;
      final f = await _storeLocal(plain, msg.meta['name'] as String? ?? '${msg.type}_${msg.id}');
      await db.update('messages', {'local_path': f.path}, where: 'chat = ? AND id = ?', whereArgs: [msg.chat, msg.id]);
      msg.localPath = f.path;
      _chatChanges.add(msg.chat);
      return f.path;
    } catch (e) {
      debugPrint('download failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------- identity

  Future<String> exportBackup(String password) =>
      Crypto.createBackup({...me.toJson(), 'nick': nickname, 'server': serverUrl}, password);

  Future<void> deleteIdentity() async {
    try {
      await conn.request({'t': 'delete_identity'});
    } catch (_) {}
    await conn.close();
    await Identity.delete();
    await AppDatabase.wipe();
    if (_mediaDir != null && await _mediaDir!.exists()) await _mediaDir!.delete(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

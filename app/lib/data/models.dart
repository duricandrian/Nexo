import 'dart:convert';
import 'dart:typed_data';

import 'db.dart';

enum Verification { server, groupMember, verified }

class Contact {
  final String id;
  final Uint8List pk;
  String? name;
  String? nick;
  int verified;
  bool blocked;
  bool hidden;
  final int created;

  Contact({
    required this.id,
    required this.pk,
    this.name,
    this.nick,
    this.verified = 1,
    this.blocked = false,
    this.hidden = false,
    int? created,
  }) : created = created ?? DateTime.now().millisecondsSinceEpoch;

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!;
    if (nick != null && nick!.trim().isNotEmpty) return '~$nick';
    return id;
  }

  factory Contact.fromRow(Map<String, Object?> r) => Contact(
        id: r['id'] as String,
        pk: base64.decode(r['pk'] as String),
        name: r['name'] as String?,
        nick: r['nick'] as String?,
        verified: r['verified'] as int,
        blocked: r['blocked'] == 1,
        hidden: r['hidden'] == 1,
        created: r['created'] as int,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'pk': base64.encode(pk),
        'name': name,
        'nick': nick,
        'verified': verified,
        'blocked': blocked ? 1 : 0,
        'hidden': hidden ? 1 : 0,
        'created': created,
      };
}

class Group {
  final String gid;
  final String creator;
  String name;
  List<String> members;
  bool left;

  Group({required this.gid, required this.creator, required this.name, required this.members, this.left = false});

  String get key => 'g:$creator:$gid';

  factory Group.fromRow(Map<String, Object?> r) => Group(
        gid: r['gid'] as String,
        creator: r['creator'] as String,
        name: r['name'] as String,
        members: (jsonDecode(r['members'] as String) as List).cast<String>(),
        left: r['left_group'] == 1,
      );

  Map<String, Object?> toRow() => {
        'key': key,
        'gid': gid,
        'creator': creator,
        'name': name,
        'members': jsonEncode(members),
        'left_group': left ? 1 : 0,
      };
}

class Chat {
  final String key;
  String? lastText;
  int lastTs;
  int unread;
  bool muted;
  bool pinned;
  String? draft;

  Chat({required this.key, this.lastText, this.lastTs = 0, this.unread = 0, this.muted = false, this.pinned = false, this.draft});

  bool get isGroup => key.startsWith('g:');
  String get contactId => key.substring(2);

  static String forContact(String id) => 'c:$id';

  factory Chat.fromRow(Map<String, Object?> r) => Chat(
        key: r['key'] as String,
        lastText: r['last_text'] as String?,
        lastTs: r['last_ts'] as int,
        unread: r['unread'] as int,
        muted: r['muted'] == 1,
        pinned: r['pinned'] == 1,
        draft: r['draft'] as String?,
      );

  Map<String, Object?> toRow() => {
        'key': key,
        'last_text': lastText,
        'last_ts': lastTs,
        'unread': unread,
        'muted': muted ? 1 : 0,
        'pinned': pinned ? 1 : 0,
        'draft': draft,
      };
}

class MsgStatus {
  static const pending = 'pending';
  static const sent = 'sent';
  static const delivered = 'delivered';
  static const read = 'read';
  static const failed = 'failed';
  static const received = 'received';
  static const order = [pending, sent, delivered, read];
}

class Message {
  final String chat;
  final String id;
  final String sender;
  final bool outgoing;
  final String type; // text, image, file, audio, system
  String? body;
  Map<String, dynamic> meta;
  String status;
  final int ts;
  bool edited;
  bool deleted;
  Map<String, String> reactions;
  String? localPath;

  Message({
    required this.chat,
    required this.id,
    required this.sender,
    required this.outgoing,
    required this.type,
    this.body,
    Map<String, dynamic>? meta,
    required this.status,
    required this.ts,
    this.edited = false,
    this.deleted = false,
    Map<String, String>? reactions,
    this.localPath,
  })  : meta = meta ?? {},
        reactions = reactions ?? {};

  factory Message.fromRow(Map<String, Object?> r) => Message(
        chat: r['chat'] as String,
        id: r['id'] as String,
        sender: r['sender'] as String,
        outgoing: r['outgoing'] == 1,
        type: r['type'] as String,
        body: r['body'] as String?,
        meta: decodeJson(r['meta'] as String?),
        status: r['status'] as String,
        ts: r['ts'] as int,
        edited: r['edited'] == 1,
        deleted: r['deleted'] == 1,
        reactions: decodeJson(r['reactions'] as String?).map((k, v) => MapEntry(k, v.toString())),
        localPath: r['local_path'] as String?,
      );

  Map<String, Object?> toRow() => {
        'chat': chat,
        'id': id,
        'sender': sender,
        'outgoing': outgoing ? 1 : 0,
        'type': type,
        'body': body,
        'meta': jsonEncode(meta),
        'status': status,
        'ts': ts,
        'edited': edited ? 1 : 0,
        'deleted': deleted ? 1 : 0,
        'reactions': jsonEncode(reactions),
        'local_path': localPath,
      };
}

class CallRecord {
  final String id;
  final String chat;
  final String peer;
  final bool outgoing;
  final bool video;
  final String status; // missed, answered, declined, cancelled
  final int ts;
  final int duration;

  CallRecord({
    required this.id,
    required this.chat,
    required this.peer,
    required this.outgoing,
    required this.video,
    required this.status,
    required this.ts,
    this.duration = 0,
  });

  factory CallRecord.fromRow(Map<String, Object?> r) => CallRecord(
        id: r['id'] as String,
        chat: r['chat'] as String,
        peer: r['peer'] as String,
        outgoing: r['outgoing'] == 1,
        video: r['video'] == 1,
        status: r['status'] as String,
        ts: r['ts'] as int,
        duration: r['duration'] as int,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'chat': chat,
        'peer': peer,
        'outgoing': outgoing ? 1 : 0,
        'video': video ? 1 : 0,
        'status': status,
        'ts': ts,
        'duration': duration,
      };
}

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> open() async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'arcana.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('''CREATE TABLE contacts(
        id TEXT PRIMARY KEY, pk TEXT NOT NULL, name TEXT, nick TEXT,
        verified INTEGER NOT NULL DEFAULT 1, blocked INTEGER NOT NULL DEFAULT 0,
        hidden INTEGER NOT NULL DEFAULT 0, created INTEGER NOT NULL)''');
      await db.execute('''CREATE TABLE groups(
        key TEXT PRIMARY KEY, gid TEXT NOT NULL, creator TEXT NOT NULL, name TEXT NOT NULL,
        members TEXT NOT NULL, left_group INTEGER NOT NULL DEFAULT 0)''');
      await db.execute('''CREATE TABLE chats(
        key TEXT PRIMARY KEY, last_text TEXT, last_ts INTEGER NOT NULL DEFAULT 0,
        unread INTEGER NOT NULL DEFAULT 0, muted INTEGER NOT NULL DEFAULT 0,
        pinned INTEGER NOT NULL DEFAULT 0, draft TEXT)''');
      await db.execute('''CREATE TABLE messages(
        chat TEXT NOT NULL, id TEXT NOT NULL, sender TEXT NOT NULL, outgoing INTEGER NOT NULL,
        type TEXT NOT NULL, body TEXT, meta TEXT, status TEXT NOT NULL, ts INTEGER NOT NULL,
        edited INTEGER NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0,
        reactions TEXT, local_path TEXT, PRIMARY KEY(chat, id))''');
      await db.execute('CREATE INDEX messages_chat_ts ON messages(chat, ts)');
      await db.execute('''CREATE TABLE outbox(
        mid TEXT NOT NULL, recipient TEXT NOT NULL, data TEXT NOT NULL, kind TEXT NOT NULL,
        chat TEXT, msg_id TEXT, created INTEGER NOT NULL, PRIMARY KEY(mid, recipient))''');
      await db.execute('''CREATE TABLE calls(
        id TEXT PRIMARY KEY, chat TEXT NOT NULL, peer TEXT NOT NULL, outgoing INTEGER NOT NULL,
        video INTEGER NOT NULL, status TEXT NOT NULL, ts INTEGER NOT NULL, duration INTEGER NOT NULL DEFAULT 0)''');
    });
    return _db!;
  }

  static Future<void> wipe() async {
    final path = p.join(await getDatabasesPath(), 'arcana.db');
    await _db?.close();
    _db = null;
    await deleteDatabase(path);
  }
}

Map<String, dynamic> decodeJson(String? s) {
  if (s == null || s.isEmpty) return {};
  try {
    return (jsonDecode(s) as Map).cast<String, dynamic>();
  } catch (_) {
    return {};
  }
}

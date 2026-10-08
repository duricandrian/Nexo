import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/crypto.dart';

class Identity {
  final String id;
  final Uint8List publicKey;
  final Uint8List secretKey;

  Identity(this.id, this.publicKey, this.secretKey);

  static const _storage = FlutterSecureStorage();
  static const _key = 'identity_v1';

  Map<String, dynamic> toJson() => {'id': id, 'sk': base64.encode(secretKey)};

  static Identity fromJson(Map<String, dynamic> j) {
    final sk = base64.decode(j['sk'] as String);
    return Identity(j['id'] as String, Crypto.publicFromSecret(sk), sk);
  }

  static Future<Identity?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    return fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save() => _storage.write(key: _key, value: jsonEncode(toJson()));

  static Future<void> delete() => _storage.delete(key: _key);
}

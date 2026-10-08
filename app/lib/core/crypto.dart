import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:pinenacl/tweetnacl.dart';

class KeyPair {
  final Uint8List publicKey;
  final Uint8List secretKey;
  const KeyPair(this.publicKey, this.secretKey);
}

/// NaCl primitives (X25519 + XSalsa20-Poly1305), wire compatible with
/// libsodium / tweetnacl-js `box` and `secretbox`.
class Crypto {
  static const nonceLength = 24;
  static final Map<String, Uint8List> _sharedKeys = {};

  static Uint8List random(int length) => TweetNaCl.randombytes(length);

  static KeyPair generateKeyPair() {
    final pk = Uint8List(32);
    final sk = Uint8List(32);
    TweetNaCl.crypto_box_keypair(pk, sk);
    return KeyPair(pk, sk);
  }

  static Uint8List publicFromSecret(Uint8List sk) {
    final pk = Uint8List(32);
    TweetNaCl.crypto_scalarmult_base(pk, sk);
    return pk;
  }

  static Uint8List _shared(Uint8List pk, Uint8List sk) {
    final cacheKey = base64.encode(pk) + base64.encode(sk.sublist(0, 4));
    return _sharedKeys.putIfAbsent(cacheKey, () {
      final k = Uint8List(32);
      TweetNaCl.crypto_box_beforenm(k, pk, sk);
      return k;
    });
  }

  static Uint8List box(Uint8List message, Uint8List nonce, Uint8List pk, Uint8List sk) =>
      secretBox(message, nonce, _shared(pk, sk));

  static Uint8List? openBox(Uint8List cipher, Uint8List nonce, Uint8List pk, Uint8List sk) =>
      openSecretBox(cipher, nonce, _shared(pk, sk));

  static Uint8List secretBox(Uint8List message, Uint8List nonce, Uint8List key) {
    final m = Uint8List(32 + message.length)..setAll(32, message);
    final c = Uint8List(m.length);
    TweetNaCl.crypto_secretbox(c, m, m.length, nonce, key);
    return Uint8List.sublistView(c, 16);
  }

  static Uint8List? openSecretBox(Uint8List cipher, Uint8List nonce, Uint8List key) {
    if (cipher.length < 16) return null;
    final c = Uint8List(16 + cipher.length)..setAll(16, cipher);
    final m = Uint8List(c.length);
    try {
      TweetNaCl.crypto_secretbox_open(m, c, c.length, nonce, key);
    } catch (_) {
      return null;
    }
    return Uint8List.sublistView(m, 32);
  }

  /// Encrypts an envelope for [pk]: nonce || box(padded(plaintext)).
  static String sealEnvelope(Map<String, dynamic> payload, Uint8List pk, Uint8List sk) {
    final plain = utf8.encode(jsonEncode(payload));
    final padLen = 1 + random(1)[0];
    final padded = Uint8List(plain.length + padLen)
      ..setAll(0, plain)
      ..fillRange(plain.length, plain.length + padLen, padLen);
    final nonce = random(nonceLength);
    final c = box(padded, nonce, pk, sk);
    return base64.encode(Uint8List(nonceLength + c.length)
      ..setAll(0, nonce)
      ..setAll(nonceLength, c));
  }

  static Map<String, dynamic>? openEnvelope(String data, Uint8List pk, Uint8List sk) {
    try {
      final raw = base64.decode(data);
      if (raw.length < nonceLength + 17) return null;
      final plain = openBox(Uint8List.sublistView(raw, nonceLength), Uint8List.sublistView(raw, 0, nonceLength), pk, sk);
      if (plain == null || plain.isEmpty) return null;
      final padLen = plain.last;
      if (padLen < 1 || padLen > plain.length) return null;
      final decoded = jsonDecode(utf8.decode(Uint8List.sublistView(plain, 0, plain.length - padLen)));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Encrypts a file blob with a fresh random key. Runs off the UI isolate.
  static Future<({Uint8List data, Uint8List key})> encryptBlob(Uint8List data) {
    return Isolate.run(() {
      final key = random(32);
      final nonce = random(nonceLength);
      final c = secretBox(data, nonce, key);
      return (data: Uint8List(nonceLength + c.length)..setAll(0, nonce)..setAll(nonceLength, c), key: key);
    });
  }

  static Future<Uint8List?> decryptBlob(Uint8List data, Uint8List key) {
    return Isolate.run(() {
      if (data.length < nonceLength + 16) return null;
      return openSecretBox(Uint8List.sublistView(data, nonceLength), Uint8List.sublistView(data, 0, nonceLength), key);
    });
  }

  /// Human comparable key fingerprint (first 16 bytes of SHA-256).
  static String fingerprint(Uint8List pk) {
    final d = hash.sha256.convert(pk).bytes.sublist(0, 16);
    final hex = d.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return [for (var i = 0; i < hex.length; i += 4) hex.substring(i, i + 4)].join(' ');
  }

  static Uint8List pbkdf2(String password, Uint8List salt, int iterations) {
    final hmac = hash.Hmac(hash.sha256, utf8.encode(password));
    final block = Uint8List(salt.length + 4)
      ..setAll(0, salt)
      ..setAll(salt.length, [0, 0, 0, 1]);
    var u = Uint8List.fromList(hmac.convert(block).bytes);
    final out = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  static const _backupIterations = 200000;

  /// Password protected identity backup string (Base32-like groups).
  static Future<String> createBackup(Map<String, dynamic> identity, String password) {
    return Isolate.run(() {
      final salt = random(16);
      final key = pbkdf2(password, salt, _backupIterations);
      final nonce = random(nonceLength);
      final c = secretBox(utf8.encode(jsonEncode(identity)), nonce, key);
      final all = Uint8List(1 + 16 + nonceLength + c.length)
        ..[0] = 1
        ..setAll(1, salt)
        ..setAll(17, nonce)
        ..setAll(17 + nonceLength, c);
      return base64Url.encode(all);
    });
  }

  static Future<Map<String, dynamic>?> restoreBackup(String backup, String password) {
    return Isolate.run(() {
      try {
        final all = base64Url.decode(base64Url.normalize(backup.replaceAll(RegExp(r'\s'), '')));
        if (all.isEmpty || all[0] != 1) return null;
        final salt = Uint8List.sublistView(all, 1, 17);
        final nonce = Uint8List.sublistView(all, 17, 17 + nonceLength);
        final key = pbkdf2(password, salt, _backupIterations);
        final plain = openSecretBox(Uint8List.sublistView(all, 17 + nonceLength), nonce, key);
        if (plain == null) return null;
        return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    });
  }
}

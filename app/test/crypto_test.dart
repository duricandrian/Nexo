import 'dart:convert';
import 'dart:typed_data';

import 'package:arcana/core/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('envelope roundtrip between two identities', () {
    final a = Crypto.generateKeyPair();
    final b = Crypto.generateKeyPair();
    final sealed = Crypto.sealEnvelope({'type': 'text', 'text': 'Привет 👋'}, b.publicKey, a.secretKey);
    final opened = Crypto.openEnvelope(sealed, a.publicKey, b.secretKey);
    expect(opened?['text'], 'Привет 👋');
    final eve = Crypto.generateKeyPair();
    expect(Crypto.openEnvelope(sealed, a.publicKey, eve.secretKey), isNull);
  });

  test('public key derivation matches', () {
    final k = Crypto.generateKeyPair();
    expect(Crypto.publicFromSecret(k.secretKey), k.publicKey);
  });

  test('blob encryption roundtrip and tamper detection', () async {
    final data = Uint8List.fromList(utf8.encode('secret file contents'));
    final enc = await Crypto.encryptBlob(data);
    expect(await Crypto.decryptBlob(enc.data, enc.key), data);
    enc.data[enc.data.length - 1] ^= 1;
    expect(await Crypto.decryptBlob(enc.data, enc.key), isNull);
  });

  test('identity backup roundtrip', () async {
    final backup = await Crypto.createBackup({'id': 'ABCD1234', 'sk': 'x'}, 'correct horse');
    expect((await Crypto.restoreBackup(backup, 'correct horse'))?['id'], 'ABCD1234');
    expect(await Crypto.restoreBackup(backup, 'wrong password'), isNull);
  });
}

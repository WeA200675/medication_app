import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medication_app/services/encrypted_backup_codec.dart';

void main() {
  const password = 'correct horse battery staple';
  const payload = <String, dynamic>{
    'version': 2,
    'med_plan': [
      {'drugName': 'Testmedikament', 'dosage': '10 mg'},
    ],
  };

  test('encrypts and decrypts a backup without exposing its contents', () async {
    final first = await EncryptedBackupCodec.encrypt(payload, password: password);
    final second = await EncryptedBackupCodec.encrypt(payload, password: password);
    final envelope = jsonDecode(first) as Map<String, dynamic>;

    expect(first, isNot(contains('Testmedikament')));
    expect(envelope['format'], EncryptedBackupCodec.formatName);
    expect(envelope['salt'], isNot((jsonDecode(second) as Map)['salt']));
    expect(envelope['nonce'], isNot((jsonDecode(second) as Map)['nonce']));
    expect(await EncryptedBackupCodec.decrypt(first, password: password), payload);
  });

  test('rejects a wrong password and modified ciphertext', () async {
    final encoded = await EncryptedBackupCodec.encrypt(payload, password: password);
    await expectLater(
      EncryptedBackupCodec.decrypt(encoded, password: 'wrong password value'),
      throwsFormatException,
    );

    final envelope = jsonDecode(encoded) as Map<String, dynamic>;
    final ciphertext = envelope['ciphertext'] as String;
    final changed = ciphertext.startsWith('A') ? 'B$ciphertext' : 'A$ciphertext';
    envelope['ciphertext'] = changed;
    await expectLater(
      EncryptedBackupCodec.decrypt(jsonEncode(envelope), password: password),
      throwsFormatException,
    );
  });

  test('requires a sufficiently long password', () async {
    await expectLater(
      EncryptedBackupCodec.encrypt(payload, password: 'short'),
      throwsArgumentError,
    );
  });
}

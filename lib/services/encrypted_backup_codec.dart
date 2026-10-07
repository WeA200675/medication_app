import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Password-based encryption for portable medication backups.
///
/// The file contains only the authenticated ciphertext and the parameters
/// needed to derive the key. The password is never stored in the backup.
class EncryptedBackupCodec {
  EncryptedBackupCodec._();

  static const formatName = 'medication_app_encrypted_backup';
  static const _version = 1;
  static const _iterations = 600000;
  static const _kdfName = 'pbkdf2-hmac-sha256';
  static const _cipherName = 'aes-256-gcm';
  static final _random = Random.secure();
  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );
  static final _cipher = AesGcm.with256bits();

  static Future<String> encrypt(
    Map<String, dynamic> payload, {
    required String password,
  }) async {
    _validatePassword(password);
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final secretKey = await _deriveKey(password, salt);
    final aad = utf8.encode('$formatName:$_version');
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: secretKey,
      nonce: nonce,
      aad: aad,
    );

    return jsonEncode({
      'format': formatName,
      'version': _version,
      'kdf': _kdfName,
      'iterations': _iterations,
      'cipher': _cipherName,
      'salt': base64UrlEncode(salt),
      'nonce': base64UrlEncode(nonce),
      'ciphertext': base64UrlEncode(box.cipherText),
      'mac': base64UrlEncode(box.mac.bytes),
    });
  }

  static Future<Map<String, dynamic>> decrypt(
    String encodedBackup, {
    required String password,
  }) async {
    _validatePassword(password);
    final decoded = jsonDecode(encodedBackup);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != formatName ||
        decoded['version'] != _version ||
        decoded['kdf'] != _kdfName ||
        decoded['iterations'] != _iterations ||
        decoded['cipher'] != _cipherName) {
      throw const FormatException('Unbekanntes oder nicht unterstütztes Backup-Format.');
    }

    try {
      final salt = base64Url.decode(_stringField(decoded, 'salt'));
      final nonce = base64Url.decode(_stringField(decoded, 'nonce'));
      final ciphertext = base64Url.decode(_stringField(decoded, 'ciphertext'));
      final macBytes = base64Url.decode(_stringField(decoded, 'mac'));
      if (salt.length != 16 || nonce.length != 12 || macBytes.length != 16) {
        throw const FormatException('Ungültige Verschlüsselungsparameter.');
      }

      final secretKey = await _deriveKey(password, salt);
      final plaintext = await _cipher.decrypt(
        SecretBox(
          ciphertext,
          nonce: nonce,
          mac: Mac(macBytes),
        ),
        secretKey: secretKey,
        aad: utf8.encode('$formatName:$_version'),
      );
      final payload = jsonDecode(utf8.decode(plaintext));
      if (payload is! Map<String, dynamic>) {
        throw const FormatException('Der Inhalt des Backups ist ungültig.');
      }
      return payload;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Backup konnte nicht entschlüsselt werden. Prüfe Passwort und Datei.',
      );
    }
  }

  static Future<SecretKey> _deriveKey(String password, List<int> salt) {
    return _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  static List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256));

  static String _stringField(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.isEmpty) {
      throw const FormatException('Ungültige Verschlüsselungsparameter.');
    }
    return value;
  }

  static void _validatePassword(String password) {
    if (password.length < 12) {
      throw ArgumentError('Das Backup-Passwort muss mindestens 12 Zeichen haben.');
    }
  }
}

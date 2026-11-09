import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Offline, password-encrypted backup format SVIPBK01.
/// Layout: ASCII magic (8), random salt (16), nonce (12), GCM tag (16), ciphertext.
/// KDF PBKDF2 HMAC-SHA256 180000 iterations; cipher AES-256-GCM.
class BackupCodec {
  const BackupCodec({this.iterations = 180000});
  final int iterations;
  static const magic = 'SVIPBK01';
  static const maxArchiveBytes = 256 * 1024 * 1024;
  static const maxDatabaseBytes = 256 * 1024 * 1024;
  static const headerBytes = 8 + 16 + 12 + 16;

  Future<SecretKey> _key(String password, List<int> salt) {
    if (password.length < 12) {
      throw const FormatException(
          'رمز نسخه پشتیبان باید حداقل ۱۲ نویسه داشته باشد.');
    }
    return Pbkdf2(
            macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256)
        .deriveKeyFromPassword(password: password, nonce: salt);
  }

  List<int> _random(int length) {
    final rng = Random.secure();
    return List<int>.generate(length, (_) => rng.nextInt(256));
  }

  Future<Uint8List> encrypt(Uint8List sqlite, String password) async {
    if (sqlite.isEmpty || sqlite.length > maxDatabaseBytes) {
      throw const FormatException(
          'اندازه بانک اطلاعات برای پشتیبان‌گیری معتبر نیست.');
    }
    final salt = _random(16);
    final nonce = _random(12);
    final key = await _key(password, salt);
    final compressed = gzip.encode(sqlite);
    final box = await AesGcm.with256bits().encrypt(
      compressed,
      secretKey: key,
      nonce: nonce,
    );
    return Uint8List.fromList([
      ...magic.codeUnits,
      ...salt,
      ...nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ]);
  }

  Future<Uint8List> decrypt(Uint8List archive, String password) async {
    if (archive.length <= headerBytes ||
        archive.length > maxArchiveBytes ||
        String.fromCharCodes(
                archive.sublist(0, archive.length < 8 ? archive.length : 8)) !=
            magic) {
      throw const FormatException(
          'فرمت نسخه پشتیبان معتبر یا پشتیبانی‌شده نیست.');
    }
    final key = await _key(password, archive.sublist(8, 24));
    final box = SecretBox(
      archive.sublist(headerBytes),
      nonce: archive.sublist(24, 36),
      mac: Mac(archive.sublist(36, 52)),
    );
    try {
      final clearCompressed =
          await AesGcm.with256bits().decrypt(box, secretKey: key);
      // gzip decoder cannot enforce decompression size; reject large output after decode.
      final decoded = gzip.decode(clearCompressed);
      if (decoded.isEmpty || decoded.length > maxDatabaseBytes) {
        throw const FormatException('اندازه نسخه پشتیبان معتبر نیست.');
      }
      return Uint8List.fromList(decoded);
    } on SecretBoxAuthenticationError {
      throw const FormatException(
          'رمز اشتباه است یا فایل پشتیبان دست‌کاری شده است.');
    } on FormatException {
      throw const FormatException('محتوای نسخه پشتیبان آسیب دیده است.');
    }
  }
}

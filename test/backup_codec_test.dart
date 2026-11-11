import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/security/backup_codec.dart';

void main() {
  const codec = BackupCodec(iterations: 300);
  final source =
      Uint8List.fromList(List<int>.generate(4096, (i) => (i * 37) % 256));
  const password = 'correct-horse-battery-staple';

  test('encrypted archive round-trips and has magic', () async {
    final encrypted = await codec.encrypt(source, password);
    expect(encrypted.sublist(0, 8), 'SVIPBK01'.codeUnits);
    expect(encrypted, isNot(equals(source)));
    expect(await codec.decrypt(encrypted, password), source);
  });

  test('different exports use independent random salts and IVs', () async {
    final first = await codec.encrypt(source, password);
    final second = await codec.encrypt(source, password);
    expect(first, isNot(equals(second)));
    expect(await codec.decrypt(first, password), source);
    expect(await codec.decrypt(second, password), source);
  });

  test('wrong password rejected', () async {
    final encrypted = await codec.encrypt(source, password);
    await expectLater(codec.decrypt(encrypted, 'wrong-password-long-enough'),
        throwsA(isA<FormatException>()));
  });

  test('tampering rejected', () async {
    final encrypted = await codec.encrypt(source, password);
    encrypted[encrypted.length - 4] ^= 0x80;
    await expectLater(
        codec.decrypt(encrypted, password), throwsA(isA<FormatException>()));
  });

  test('plaintext and truncated archives rejected', () async {
    await expectLater(codec.decrypt(Uint8List.fromList(source), password),
        throwsA(isA<FormatException>()));
    await expectLater(
        codec.decrypt(Uint8List.fromList('SVIPBK01'.codeUnits), password),
        throwsA(isA<FormatException>()));
  });

  test('bounded streaming restore rejects compressed expansion', () async {
    const smallDecoder = BackupCodec(
      iterations: 300, maxDecompressedBytes: 1024);
    final archive = await codec.encrypt(source, password);
    await expectLater(smallDecoder.decrypt(archive, password),
        throwsA(isA<FormatException>()));
  });

  test('weak export password rejected', () async {
    await expectLater(
        codec.encrypt(source, 'short'), throwsA(isA<FormatException>()));
  });
}

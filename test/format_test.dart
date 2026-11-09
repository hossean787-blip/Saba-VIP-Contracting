import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/core/format.dart';

void main() {
  test('Persian and Arabic digits convert to integer rial', () {
    expect(tomanToRial('۱۲٬۳۴۵'), 123450);
    expect(tomanToRial('١٢٣'), 1230);
  });
  test('Invalid and fractional money is rejected', () {
    expect(tomanToRial('-5'), isNull);
    expect(tomanToRial('2.5'), isNull);
    expect(tomanToRial(''), isNull);
    expect(tomanToRial('۰', allowZero: false), isNull);
  });
  test('Rial to toman view without floating error', () {
    expect(tomanLabel(1234567890), '123٬456٬789 تومان');
  });
  test('Legacy residual rial is never displayed as zero toman', () {
    expect(tomanLabel(1), '1 ریال');
    expect(tomanLabel(1000001), '1٬000٬001 ریال');
  });
  test('Persian calendar day is readable', () {
    expect(jalaliLabel('2026-11-08'), startsWith('1405/'));
  });
}

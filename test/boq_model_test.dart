import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/finance/boq_model.dart';

void main() {
  test('quantity parses Persian decimals exactly, no floating point', () {
    expect(parseQuantityMilli('۱۲٫۳۴۵'), 12345);
    expect(parseQuantityMilli('1.2'), 1200);
    expect(parseQuantityMilli('1,234.005'), 1234005);
    expect(parseQuantityMilli('0.001'), 1);
    expect(parseQuantityMilli('0.0001'), isNull);
    expect(parseQuantityMilli('-0.250'), isNull);
    expect(parseQuantityMilli('-0.250', allowNegative: true), -250);
    expect(parseQuantityMilli('0'), isNull);
    expect(parseQuantityMilli('1e6'), isNull);
    expect(parseQuantityMilli('۱۰۰۰۰۰۰۰۰۰۰۰۰'), isNull);
  });

  test('coefficient fixed point enforces agreed range and precision', () {
    expect(parseCoefficientBp('۱.۱۵۰۰'), 11500);
    expect(parseCoefficientBp('1'), 10000);
    expect(parseCoefficientBp('0.0001'), 1);
    expect(parseCoefficientBp('0'), isNull);
    expect(parseCoefficientBp('10.0001'), isNull);
    expect(parseCoefficientBp('1.00001'), isNull);
  });

  test('line total rounds once to integer rial using BigInt', () {
    expect(estimateRial(
      quantityMilli: 1500,
      unitPriceRial: 100000,
      coefficientBp: 11500,
    ), 172500);
    expect(estimateRial(
      quantityMilli: 5,
      unitPriceRial: 100,
      coefficientBp: 10000,
    ), 1);
    expect(estimateRial(
      quantityMilli: -500,
      unitPriceRial: 100000,
      coefficientBp: 10000,
    ), -50000);
    expect(() => estimateRial(
      quantityMilli: 1000000000000,
      unitPriceRial: 9223372036854775807,
      coefficientBp: 100000,
    ), throwsArgumentError);
  });

  test('BOQ snapshot separates plan, measured, unbilled values', () {
    const item = BoqItem(
      id: 1, code: '0201', title: 'کارهای اجرایی',
      unit: 'مترمربع', source: 'فهرست‌بهای نمونه',
      plannedQuantityMilli: 10000,
      unitPriceRial: 200000,
      coefficientBp: 10000,
      measuredQuantityMilli: 5000,
      billedQuantityMilli: 3000,
      pendingQuantityMilli: 2000,
    );
    const snapshot = BoqSnapshot(
      items: [item],
      measurements: [
        BoqMeasurement(
            id: 1, itemId: 1, itemCode: '0201',
            quantityMilli: 3000, date: '2026-11-01',
            documentRef: 'REF', memo: '', statementId: 3),
        BoqMeasurement(
            id: 2, itemId: 1, itemCode: '0201',
            quantityMilli: 2000, date: '2026-11-01',
            documentRef: 'REF', memo: '', statementId: null),
      ],
    );
    expect(snapshot.plannedRial, 2000000);
    expect(snapshot.measuredRial, 1000000);
    expect(snapshot.pendingRial, 400000);
    expect(snapshot.unbilledCount, 1);
    expect(formatScaled(-1234), '-1.234');
    expect(formatScaled(11500, scale: 10000, decimals: 4), '1.15');
  });

  test('sum of money guards SQLite signed 64-bit capacity', () {
    expect(checkedTotal([100, -10, 20]), 110);
    expect(() => checkedTotal([9223372036854775807, 1]),
        throwsArgumentError);
    expect(() => checkedTotal([-9223372036854775807, -1]),
        throwsArgumentError);
  });
}

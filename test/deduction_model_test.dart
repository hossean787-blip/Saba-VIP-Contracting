import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/finance/deduction_model.dart';

void main() {
  test('six explicit deduction categories have no assumed legal rates', () {
    expect(deductionKinds.map((e) => e.code).toSet(), {
      'retention','insurance','advance','withholding','penalty','other'
    });
    expect(deductionKinds.every((e) => e.label.isNotEmpty), isTrue);
  });

  test('deductions add in integer rial and preserve residual amount', () {
    const lines = [
      DeductionLine(kind: 'retention', amountRial: 103,
          basisRef: 'پیمان ۱۴۰۵ بند ۱'),
      DeductionLine(kind: 'insurance', amountRial: 507,
          basisRef: 'نامه بیمه ۴۴'),
      DeductionLine(kind: 'other', amountRial: 50,
          basisRef: 'نامه اصلاحی ۵'),
    ];
    expect(checkedDeductionsTotal(lines), 660);
    expect(checkedDeductionsTotal([]), 0);
  });

  test('reject category duplicates, missing references and invalid amount', () {
    const valid = DeductionLine(
      kind: 'retention', amountRial: 100, basisRef: 'شماره ۴۴۴');
    expect(() => checkedDeductionsTotal([valid, valid]),
        throwsArgumentError);
    expect(() => checkedDeductionsTotal([
      const DeductionLine(kind: 'unknown', amountRial: 100,
          basisRef: 'مستند ۴۴'),
    ]), throwsArgumentError);
    expect(() => checkedDeductionsTotal([
      const DeductionLine(kind: 'penalty', amountRial: 0,
          basisRef: 'نامه ۴۴'),
    ]), throwsArgumentError);
    expect(() => checkedDeductionsTotal([
      const DeductionLine(kind: 'advance', amountRial: 100,
          basisRef: ''),
    ]), throwsArgumentError);
  });

  test('64-bit overflow is rejected before SQLite transaction', () {
    expect(() => checkedDeductionsTotal([
      const DeductionLine(kind: 'insurance',
          amountRial: 9223372036854775807, basisRef: 'B-101'),
      const DeductionLine(kind: 'retention',
          amountRial: 1, basisRef: 'A-303'),
    ]), throwsArgumentError);
  });

  test('a paid statement cannot be reduced below cash allocated', () {
    expect(() => validateDeductionSettlement(
      grossRial: 1000000, vatRial: 0,
      allocatedRial: 500000, deductionsRial: 500000,
    ), returnsNormally);
    expect(() => validateDeductionSettlement(
      grossRial: 1000000, vatRial: 0,
      allocatedRial: 500000, deductionsRial: 500001,
    ), throwsStateError);
    expect(() => validateDeductionSettlement(
      grossRial: 1000000, vatRial: 0,
      allocatedRial: 0, deductionsRial: 1000001,
    ), throwsStateError);
    expect(() => validateDeductionSettlement(
      grossRial: -1, vatRial: 0,
      allocatedRial: 0, deductionsRial: 0,
    ), throwsArgumentError);
  });

  test('legacy deductions remain visible as unclassified without data loss', () {
    const data = DeductionSnapshot(
      number: 'S-01', status: 'APPROVED',
      grossRial: 1000000, vatRial: 200000,
      totalDeductionsRial: 400000, allocatedReceiptsRial: 500000,
      lines: [
        DeductionLine(kind: 'insurance',
          amountRial: 150000, basisRef: 'نامه ۴۴۴'),
      ],
      revisions: [],
    );
    expect(data.classifiedRial, 150000);
    expect(data.unclassifiedRial, 250000);
    expect(data.netPayableRial, 800000);
    expect(data.remainingReceivableRial, 300000);
  });
}

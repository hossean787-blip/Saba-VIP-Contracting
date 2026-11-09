import 'dart:convert';
import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/reports/report_exports.dart';
import 'package:saba_vip_contracting/reports/report_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const report = ContractReport(
    companyName: 'شرکت نمونه',
    contractNo: '001',
    contractTitle: 'نقشه‌برداری',
    employer: 'کارفرما',
    contractor: 'پیمانکار',
    contractAmountRial: 10000000,
    costRial: 2000000,
    paymentRial: 1000000,
    receiptRial: 1500000,
    approvedGrossRial: 3000000,
    approvedNetRial: 2800000,
    provisionalMarginRial: 1000000,
    cashFlowRial: 500000,
    records: [
      ReportRecord(
          kind: 'expenses',
          dateIso: '2026-11-08',
          title: 'تجهیزات',
          amountRial: 2000001,
          status: 'پرداخت جزئی',
          note: 'پرداخت‌شده: 1000000 ریال | مانده: 1000001 ریال')
    ],
  );

  test('XLSX is created as a nonempty ZIP-based Excel workbook', () {
    final bytes = ReportExports.xlsx(report, kind: 'expenses');
    expect(bytes.length, greaterThan(1000));
    expect(bytes.sublist(0, 2), [0x50, 0x4b]);
  });

  test('XLSX preserves exact rial and settlement evidence', () {
    final workbook = xl.Excel.decodeBytes(ReportExports.xlsx(report));
    final row = workbook['ریز عملیات'].rows[1];
    expect(row[4]!.value.toString(), 'پرداخت جزئی');
    expect(row[5]!.value.toString(), contains('مانده: 1000001 ریال'));
    // Audit-safe exact text remains available even for very large rial values,
    // while the adjacent numeric column supports Excel SUM/Pivot.
    expect(row[6]!.value, isA<xl.TextCellValue>());
    expect((row[6]!.value as xl.TextCellValue).value, '2000001');
    expect(row[7]!.value, isA<xl.IntCellValue>());
    expect((row[7]!.value as xl.IntCellValue).value, 2000001);
    final summary = workbook['خلاصه'].rows[6];
    expect(summary[2]!.value, isA<xl.TextCellValue>());
    expect((summary[2]!.value as xl.TextCellValue).value, '10000000');
    expect(summary[3]!.value, isA<xl.IntCellValue>());
    expect((summary[3]!.value as xl.IntCellValue).value, 10000000);
  });

  test('PDF has a valid file signature without internet access', () async {
    final bytes = await ReportExports.pdf(report, kind: 'expenses');
    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
  });
}

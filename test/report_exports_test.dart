import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/reports/report_exports.dart';
import 'package:saba_vip_contracting/reports/report_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const report = ContractReport(
    companyName: 'شرکت نمونه', contractNo: '001', contractTitle: 'نقشه‌برداری',
    employer: 'کارفرما', contractor: 'پیمانکار', contractAmountRial: 10000000,
    costRial: 2000000, paymentRial: 1000000, receiptRial: 1500000,
    approvedGrossRial: 3000000, approvedNetRial: 2800000,
    provisionalMarginRial: 1000000, cashFlowRial: 500000,
    records: [ReportRecord(kind: 'expenses', dateIso: '2026-11-08',
      title: 'تجهیزات', amountRial: 2000000)],
  );

  test('XLSX is created as a nonempty ZIP-based Excel workbook', () {
    final bytes = ReportExports.xlsx(report, kind: 'expenses');
    expect(bytes.length, greaterThan(1000));
    expect(bytes.sublist(0, 2), [0x50, 0x4b]);
  });

  test('PDF has a valid file signature without internet access', () async {
    final bytes = await ReportExports.pdf(report, kind: 'expenses');
    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
  });
}

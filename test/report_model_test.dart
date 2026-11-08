import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/reports/report_model.dart';

const sample = ContractReport(
  companyName: 'شرکت آزمایشی', contractNo: '001', contractTitle: 'نقشه‌برداری',
  employer: 'کارفرما', contractor: 'پیمانکار', contractAmountRial: 100000000,
  costRial: 3000000, paymentRial: 1000000, receiptRial: 1500000,
  approvedGrossRial: 9000000, approvedNetRial: 8500000,
  provisionalMarginRial: 6000000, cashFlowRial: 500000,
  records: [
    ReportRecord(kind: 'expenses', dateIso: '2026-10-03', title: 'تجهیزات', amountRial: 2000000),
    ReportRecord(kind: 'expenses', dateIso: '2026-10-05', title: 'تجهیزات', amountRial: 1000000),
    ReportRecord(kind: 'receipts', dateIso: '2026-10-06', title: 'دریافت', amountRial: 1500000),
    ReportRecord(kind: 'payments', dateIso: '2026-10-06', title: 'پرداخت', amountRial: 1000000),
  ],
);

void main() {
  test('expense groups aggregate within one report', () {
    expect(sample.expenseGroups['تجهیزات'], 3000000);
  });
  test('filter keeps kinds distinct', () {
    expect(sample.filtered('expenses').length, 2);
    expect(sample.filtered('receipts').single.amountRial, 1500000);
    expect(sample.filtered('all').length, 4);
  });
  test('monthly cash does not conflate receipts and payments', () {
    expect(sample.monthlyCash['2026-10']!['receipts'], 1500000);
    expect(sample.monthlyCash['2026-10']!['payments'], 1000000);
  });
}

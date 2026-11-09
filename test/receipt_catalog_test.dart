import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/finance/receipt_catalog.dart';

void main() {
  test('receipt category codes are unique and nonempty', () {
    expect(receiptCategories.length, greaterThanOrEqualTo(9));
    expect(receiptCategories.map((c) => c.code).toSet().length,
        receiptCategories.length);
    expect(receiptCategoryByCode('invalid'), isNull);
  });
  test('payer and method are required for every receipt', () {
    expect(
        const ReceiptDetail(
                categoryCode: 'contract_advance',
                detailTitle: '',
                payerName: '',
                paymentMethod: 'CASH')
            .validate(),
        isNotNull);
    expect(
        const ReceiptDetail(
                categoryCode: 'contract_advance',
                detailTitle: '',
                payerName: 'شهرداری',
                paymentMethod: 'UNKNOWN')
            .validate(),
        isNotNull);
  });
  test('statement collection requires detail number', () {
    expect(
        const ReceiptDetail(
                categoryCode: 'statement_collection',
                detailTitle: '',
                payerName: 'شهرداری',
                paymentMethod: 'TRANSFER')
            .validate(),
        isNotNull);
    expect(
        const ReceiptDetail(
                categoryCode: 'statement_collection',
                detailTitle: 'صورت‌وضعیت ۱',
                payerName: 'شهرداری',
                paymentMethod: 'TRANSFER')
            .validate(),
        isNull);
  });
  test('refund is a receipt but not automatically income', () {
    final row = receiptCategoryByCode('reimbursement');
    expect(row?.name, 'بازپرداخت یا استرداد وجه');
    expect(
        const ReceiptDetail(
                categoryCode: 'reimbursement',
                detailTitle: 'استرداد اضافه پرداخت',
                payerName: 'فروشنده',
                paymentMethod: 'CASH')
            .validate(),
        isNull);
  });
}

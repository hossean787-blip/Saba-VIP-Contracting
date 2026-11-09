import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/finance/expense_payment.dart';

void main() {
  test('no checkbox means no payment', () {
    expect(initialExpensePaymentRial(
      expenseRial: 1000000, mode: ExpensePaymentMode.unpaid), 0);
    expect(remainingExpenseRial(1000000, 0), 1000000);
  });
  test('full settlement', () {
    expect(initialExpensePaymentRial(
      expenseRial: 1000000, mode: ExpensePaymentMode.full), 1000000);
    expect(remainingExpenseRial(1000000, 1000000), 0);
  });
  test('partial settlement', () {
    expect(initialExpensePaymentRial(expenseRial: 1000000,
      mode: ExpensePaymentMode.partial, partialRial: 400000), 400000);
    expect(remainingExpenseRial(1000000, 400000), 600000);
  });
  test('invalid partial payments rejected', () {
    for (final value in <int?>[null, -1, 0, 1000000, 1000001]) {
      expect(() => initialExpensePaymentRial(expenseRial: 1000000,
        mode: ExpensePaymentMode.partial, partialRial: value), throwsArgumentError);
    }
    expect(() => remainingExpenseRial(1000000, 1000001), throwsArgumentError);
  });
}

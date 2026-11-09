enum ExpensePaymentMode { unpaid, full, partial }

int initialExpensePaymentRial({
  required int expenseRial,
  required ExpensePaymentMode mode,
  int? partialRial,
}) {
  if (expenseRial <= 0) throw ArgumentError('مبلغ هزینه نامعتبر است');
  switch (mode) {
    case ExpensePaymentMode.unpaid:
      return 0;
    case ExpensePaymentMode.full:
      return expenseRial;
    case ExpensePaymentMode.partial:
      if (partialRial == null ||
          partialRial <= 0 ||
          partialRial >= expenseRial) {
        throw ArgumentError('پرداخت جزئی باید مثبت و کمتر از هزینه باشد');
      }
      return partialRial;
  }
}

int remainingExpenseRial(int expenseRial, int paidRial) {
  if (expenseRial <= 0 || paidRial < 0 || paidRial > expenseRial) {
    throw ArgumentError('مبلغ مانده نامعتبر است');
  }
  return expenseRial - paidRial;
}

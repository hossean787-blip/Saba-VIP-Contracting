enum FinanceKind { expenses, payments, receipts, statements }

extension FinanceKindInfo on FinanceKind {
  String get table => switch (this) {
        FinanceKind.expenses => 'expenses',
        FinanceKind.payments => 'payments',
        FinanceKind.receipts => 'receipts',
        FinanceKind.statements => 'statements',
      };
  String get dateField => switch (this) {
        FinanceKind.expenses => 'expense_date',
        FinanceKind.payments => 'payment_date',
        FinanceKind.receipts => 'receipt_date',
        FinanceKind.statements => 'statement_date',
      };
  String get amountField =>
      this == FinanceKind.statements ? 'gross_rial' : 'amount_rial';
  String get label => switch (this) {
        FinanceKind.expenses => 'هزینه‌ها',
        FinanceKind.payments => 'پرداخت‌ها',
        FinanceKind.receipts => 'دریافت‌ها',
        FinanceKind.statements => 'صورت‌وضعیت‌ها',
      };
  String get singleLabel => switch (this) {
        FinanceKind.expenses => 'هزینه',
        FinanceKind.payments => 'پرداخت',
        FinanceKind.receipts => 'دریافت',
        FinanceKind.statements => 'صورت‌وضعیت',
      };
}

enum FinanceArea { outflows, inflows }

extension FinanceAreaInfo on FinanceArea {
  List<FinanceKind> get kinds => this == FinanceArea.outflows
      ? const [FinanceKind.expenses, FinanceKind.payments]
      : const [FinanceKind.receipts, FinanceKind.statements];
  String get title => this == FinanceArea.outflows
      ? 'هزینه‌ها و پرداخت‌ها'
      : 'درآمدها و دریافت‌ها';
  String get note => this == FinanceArea.outflows
      ? 'ابتدا هزینه شناسایی می‌شود؛ پرداخت کامل یا جزئی به همان هزینه متصل است و مانده بدهی نمایش داده می‌شود.'
      : 'دریافت نقدی با درآمد تحقق‌یافته برابر نیست؛ مبلغ صورت‌وضعیت‌های پیش‌نویس نیز قطعی نیست.';
}

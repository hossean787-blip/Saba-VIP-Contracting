/// Immutable, UI-independent financial report snapshot.
/// No accounting ledger: approved gross work is only a provisional revenue proxy.
class ReportRecord {
  const ReportRecord({required this.kind, required this.dateIso, required this.title,
    required this.amountRial, this.status = '', this.note = ''});
  final String kind;
  final String dateIso;
  final String title;
  final int amountRial;
  final String status;
  final String note;

  String get kindLabel => switch (kind) {
    'activities' => 'عملیات',
    'expenses' => 'هزینه',
    'payments' => 'پرداخت',
    'receipts' => 'دریافت',
    'statements' => 'صورت‌وضعیت',
    _ => kind,
  };
}

class ContractReport {
  const ContractReport({required this.companyName, required this.contractNo,
    required this.contractTitle, required this.employer, required this.contractor,
    required this.contractAmountRial, required this.costRial, required this.paymentRial,
    required this.receiptRial, required this.approvedGrossRial,
    required this.approvedNetRial, required this.provisionalMarginRial,
    required this.cashFlowRial, required this.records});

  final String companyName;
  final String contractNo;
  final String contractTitle;
  final String employer;
  final String contractor;
  final int contractAmountRial;
  final int costRial;
  final int paymentRial;
  final int receiptRial;
  final int approvedGrossRial;
  final int approvedNetRial;
  final int provisionalMarginRial;
  final int cashFlowRial;
  final List<ReportRecord> records;

  List<ReportRecord> filtered(String kind) => kind == 'all'
      ? List.unmodifiable(records)
      : List.unmodifiable(records.where((r) => r.kind == kind));

  Map<String, int> get expenseGroups {
    final result = <String, int>{};
    for (final row in records.where((row) => row.kind == 'expenses')) {
      result.update(row.title, (v) => v + row.amountRial,
        ifAbsent: () => row.amountRial);
    }
    return result;
  }

  Map<String, Map<String, int>> get monthlyCash {
    final result = <String, Map<String, int>>{};
    for (final row in records.where((r) => r.kind == 'payments' || r.kind == 'receipts')) {
      if (row.dateIso.length < 7) continue;
      final key = row.dateIso.substring(0, 7);
      final current = result.putIfAbsent(key, () => {'payments': 0, 'receipts': 0});
      current[row.kind] = current[row.kind]! + row.amountRial;
    }
    return Map.fromEntries(result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }
}

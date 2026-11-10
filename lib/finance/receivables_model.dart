/// Read-only, contract-scoped snapshot for the cash application workflow.
/// Receipts and approved work are separate; linking them does NOT create cash.
class StatementBalance {
  const StatementBalance({
    required this.id,
    required this.number,
    required this.date,
    required this.status,
    required this.netRial,
    required this.allocatedRial,
  });

  final int id;
  final String number;
  final String date;
  final String status;
  final int netRial;
  final int allocatedRial;

  int get remainingRial => netRial - allocatedRial;
  bool get approved => status == 'APPROVED';

  /// This is only an attention indicator, not a contractual due-date claim.
  bool needsReviewOn(DateTime date) {
    if (!approved || remainingRial == 0) return false;
    final parsed = DateTime.tryParse(this.date);
    if (parsed == null) return false;
    final dateOnly = DateTime.utc(date.year, date.month, date.day);
    final statementDay = DateTime.utc(parsed.year, parsed.month, parsed.day);
    return dateOnly.difference(statementDay).inDays >= 30;
  }
}

const eligibleReceiptCategoriesForStatements = {
  'statement_collection',
  'final_settlement',
  'adjustment',
  'retention_release',
  'old_receivable',
};

class ReceiptBalance {
  const ReceiptBalance({
    required this.id,
    required this.date,
    required this.categoryCode,
    required this.payer,
    required this.reference,
    required this.amountRial,
    required this.allocatedRial,
  });

  final int id;
  final String date;
  final String categoryCode;
  final String payer;
  final String reference;
  final int amountRial;
  final int allocatedRial;

  int get unallocatedRial => amountRial - allocatedRial;
  bool get eligible =>
      eligibleReceiptCategoriesForStatements.contains(categoryCode);
}

class ReceiptAllocation {
  const ReceiptAllocation({
    required this.statementId,
    required this.statementNumber,
    required this.receiptId,
    required this.amountRial,
  });

  final int statementId;
  final String statementNumber;
  final int receiptId;
  final int amountRial;
}

class AllocationAudit {
  const AllocationAudit({
    required this.action,
    required this.statementNumber,
    required this.receiptId,
    required this.amountRial,
    required this.happenedAt,
  });
  final String action;
  final String statementNumber;
  final int receiptId;
  final int amountRial;
  final String happenedAt;
}

class ReceivablesSnapshot {
  const ReceivablesSnapshot({
    required this.statements,
    required this.receipts,
    required this.allocations,
    required this.audit,
  });

  final List<StatementBalance> statements;
  final List<ReceiptBalance> receipts;
  final List<ReceiptAllocation> allocations;
  final List<AllocationAudit> audit;

  int get approvedNetRial => statements
      .where((s) => s.approved)
      .fold(0, (sum, row) => sum + row.netRial);
  int get allocatedRial => statements
      .where((s) => s.approved)
      .fold(0, (sum, row) => sum + row.allocatedRial);
  int get outstandingRial => approvedNetRial - allocatedRial;
  int get unallocatedReceiptsRial =>
      receipts.fold(0, (sum, row) => sum + row.unallocatedRial);
  List<ReceiptBalance> get selectableReceipts => receipts
      .where((row) => row.eligible && row.unallocatedRial > 0)
      .toList(growable: false);
  int get attentionCount => statements
      .where((row) => row.needsReviewOn(DateTime.now()))
      .length;
}

/// Pure input validation is repeated inside the SQLite transaction, so the
/// UI cannot accidentally allocate stale, cross-contract or excessive funds.
void validateStatementAllocation({
  required StatementBalance statement,
  required ReceiptBalance receipt,
  required int amountRial,
}) {
  if (!statement.approved) {
    throw StateError('فقط صورت‌وضعیت تأییدشده قابل تسویه است.');
  }
  if (!receipt.eligible) {
    throw StateError('نوع دریافت برای تخصیص به صورت‌وضعیت مناسب نیست.');
  }
  if (amountRial <= 0) throw ArgumentError('مبلغ تخصیص باید مثبت باشد.');
  if (amountRial > statement.remainingRial) {
    throw ArgumentError('مبلغ از مانده صورت‌وضعیت بیشتر است.');
  }
  if (amountRial > receipt.unallocatedRial) {
    throw ArgumentError('مبلغ از مانده تخصیص‌نیافته دریافت بیشتر است.');
  }
}

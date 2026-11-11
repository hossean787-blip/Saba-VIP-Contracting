/// Explicit user-entered statement deductions. No statutory percentage is
/// assumed: insurance/retention/advances depend on the actual contract.
class DeductionKind {
  const DeductionKind(this.code, this.label, this.help);
  final String code;
  final String label;
  final String help;
}

const deductionKinds = <DeductionKind>[
  DeductionKind('retention', 'سپرده حسن انجام کار', 'طبق بندهای پیمان'),
  DeductionKind('insurance', 'کسور بیمه', 'طبق قرارداد و وضعیت مفاصاحساب'),
  DeductionKind('advance', 'استهلاک پیش‌پرداخت', 'کسر علی‌الحساب پیش‌پرداخت'),
  DeductionKind('withholding', 'مالیات تکلیفی', 'فقط در صورت شمول قانونی'),
  DeductionKind('penalty', 'جرایم و خسارات', 'با مستند تأییدشده'),
  DeductionKind('other', 'سایر کسورات', 'با مستند و شرح دقیق'),
];

class DeductionLine {
  const DeductionLine({
    required this.kind,
    required this.amountRial,
    required this.basisRef,
  });
  final String kind;
  final int amountRial;
  final String basisRef;
}

class DeductionRevision {
  const DeductionRevision({
    required this.id,
    required this.previousRial,
    required this.currentRial,
    required this.changedAt,
    required this.reason,
    required this.beforeJson,
    required this.afterJson,
  });
  final int id;
  final int previousRial;
  final int currentRial;
  final String changedAt;
  final String reason;
  final String beforeJson;
  final String afterJson;
}

class DeductionSnapshot {
  const DeductionSnapshot({
    required this.number,
    required this.status,
    required this.grossRial,
    required this.vatRial,
    required this.totalDeductionsRial,
    required this.allocatedReceiptsRial,
    required this.lines,
    required this.revisions,
  });
  final String number;
  final String status;
  final int grossRial;
  final int vatRial;
  final int totalDeductionsRial;
  final int allocatedReceiptsRial;
  final List<DeductionLine> lines;
  final List<DeductionRevision> revisions;

  int get classifiedRial =>
      lines.fold<int>(0, (sum, line) => sum + line.amountRial);
  int get unclassifiedRial => totalDeductionsRial - classifiedRial;
  int get netPayableRial => grossRial + vatRial - totalDeductionsRial;
  int get remainingReceivableRial => netPayableRial - allocatedReceiptsRial;
}

const _sqliteMax = 9223372036854775807;

int checkedDeductionsTotal(List<DeductionLine> lines) {
  final kinds = <String>{};
  var sum = BigInt.zero;
  for (final line in lines) {
    if (!deductionKinds.any((kind) => kind.code == line.kind)) {
      throw ArgumentError('دسته کسورات نامعتبر است.');
    }
    if (!kinds.add(line.kind)) {
      throw ArgumentError('دسته کسورات تکراری است.');
    }
    if (line.amountRial <= 0 || line.amountRial > _sqliteMax) {
      throw ArgumentError('مبلغ کسورات باید مثبت باشد.');
    }
    if (line.basisRef.trim().length < 3 ||
        line.basisRef.trim().length > 160) {
      throw ArgumentError('شماره یا مرجع مستند کسورات الزامی است.');
    }
    sum += BigInt.from(line.amountRial);
  }
  if (sum > BigInt.from(_sqliteMax)) {
    throw ArgumentError('جمع کسورات بیش از ظرفیت مجاز است.');
  }
  return sum.toInt();
}

void validateDeductionSettlement({
  required int grossRial,
  required int vatRial,
  required int allocatedRial,
  required int deductionsRial,
}) {
  if (grossRial < 0 || vatRial < 0 || allocatedRial < 0 ||
      deductionsRial < 0) {
    throw ArgumentError('ارقام صورت‌وضعیت معتبر نیست.');
  }
  final net = BigInt.from(grossRial) + BigInt.from(vatRial) -
      BigInt.from(deductionsRial);
  if (net < BigInt.from(allocatedRial) ||
      net > BigInt.from(_sqliteMax)) {
    throw StateError(
        'مبلغ خالص نمی‌تواند از دریافتی تخصیص‌یافته کمتر باشد.');
  }
}

/// This catalog describes the SOURCE of incoming cash.
/// An incoming payment is NOT automatically recognised as earned revenue.
class ReceiptCategory {
  const ReceiptCategory(this.code, this.name, this.detailLabel, this.hint,
      {this.detailRequired = false});
  final String code;
  final String name;
  final String detailLabel;
  final String hint;
  final bool detailRequired;
}

const receiptCategories = <ReceiptCategory>[
  ReceiptCategory('statement_collection', 'وصول صورت‌وضعیت',
      'شماره صورت‌وضعیت *', 'مثلاً: صورت‌وضعیت شماره ۳',
      detailRequired: true),
  ReceiptCategory('contract_advance', 'پیش‌پرداخت قرارداد',
      'شرح یا مرحله پیش‌پرداخت', 'مثلاً: پیش‌پرداخت شروع پروژه'),
  ReceiptCategory('on_account', 'علی‌الحساب کارفرما', 'موضوع علی‌الحساب',
      'مثلاً: علی‌الحساب عملیات آبان'),
  ReceiptCategory('final_settlement', 'تسویه‌حساب نهایی',
      'شماره یا شرح تسویه *', 'مثلاً: تسویه نهایی قرارداد شهرداری',
      detailRequired: true),
  ReceiptCategory('adjustment', 'وصول تعدیل و مابه‌التفاوت', 'مبنای تعدیل *',
      'مثلاً: تعدیل صورت‌وضعیت شماره ۲',
      detailRequired: true),
  ReceiptCategory('retention_release', 'آزادسازی سپرده و تضمین',
      'نوع سپرده / شماره ضمانت‌نامه *', 'این دریافت الزاماً درآمد جدید نیست',
      detailRequired: true),
  ReceiptCategory('old_receivable', 'وصول مطالبات قبلی',
      'شماره سند / دوره طلب *', 'مثلاً: طلب مربوط به صورت‌وضعیت ۱۴۰۴',
      detailRequired: true),
  ReceiptCategory('service_fee', 'درآمد خدمات مرتبط با پروژه',
      'نوع خدمت ارائه‌شده *', 'مثلاً: خدمات نقشه‌برداری تکمیلی',
      detailRequired: true),
  ReceiptCategory('reimbursement', 'بازپرداخت یا استرداد وجه', 'علت استرداد *',
      'مثلاً: استرداد اضافه‌پرداخت',
      detailRequired: true),
  ReceiptCategory('other', 'سایر دریافت‌ها', 'شرح دقیق دریافت *',
      'دلیل و موضوع دریافت را مشخص کنید',
      detailRequired: true),
];

ReceiptCategory? receiptCategoryByCode(String code) {
  for (final item in receiptCategories) {
    if (item.code == code) return item;
  }
  return null;
}

/// Detailed payer information and payment reference are tied to a receipt,
/// not to its associated statement's recognition status.
class ReceiptDetail {
  const ReceiptDetail({
    required this.categoryCode,
    required this.detailTitle,
    required this.payerName,
    required this.paymentMethod,
    this.referenceNo = '',
  });
  final String categoryCode;
  final String detailTitle;
  final String payerName;
  final String paymentMethod;
  final String referenceNo;

  static const methods = <String, String>{
    'TRANSFER': 'حواله / انتقال بانکی',
    'CASH': 'نقدی',
    'CHECK': 'چک',
    'POS': 'کارت‌خوان',
    'OTHER': 'سایر',
  };

  String? validate() {
    final category = receiptCategoryByCode(categoryCode);
    if (category == null) return 'نوع دریافت معتبر انتخاب نشده است.';
    if (payerName.trim().isEmpty)
      return 'نام شخص یا سازمان پرداخت‌کننده الزامی است.';
    if (category.detailRequired && detailTitle.trim().isEmpty) {
      return 'شماره سند یا تفصیلی این دریافت الزامی است.';
    }
    if (!methods.containsKey(paymentMethod)) return 'روش دریافت معتبر نیست.';
    if (payerName.trim().length > 250 ||
        detailTitle.trim().length > 250 ||
        referenceNo.trim().length > 100) {
      return 'طول اطلاعات دریافت از حد مجاز بیشتر است.';
    }
    return null;
  }

  String get categoryTitle =>
      receiptCategoryByCode(categoryCode)?.name ?? 'دریافت نامشخص';
  String get methodTitle => methods[paymentMethod] ?? 'نامشخص';
}

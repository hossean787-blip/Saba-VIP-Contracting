/// Fixed construction expense categories. Expense and payment remain separate.
class ExpenseCategory {
  const ExpenseCategory(this.code, this.name, this.detailLabel, this.hint,
      {this.detailRequired = false,
      this.counterpartyLabel = 'طرف حساب / فروشنده / دریافت‌کننده وجه'});
  final String code, name, detailLabel, hint, counterpartyLabel;
  final bool detailRequired;
}

const expenseCategories = <ExpenseCategory>[
  ExpenseCategory('salary', 'حقوق کارکنان', 'نام و نام خانوادگی شخص *',
      'مثلاً: علی محمدی - نقشه‌بردار',
      detailRequired: true,
      counterpartyLabel: 'طرف حساب (در صورت تفاوت با شخص)'),
  ExpenseCategory('day_labor', 'دستمزد کارگر و نیروی روزمزد',
      'نام شخص / نیروی کار *', 'نام کارگر یا مسئول اکیپ',
      detailRequired: true),
  ExpenseCategory('equipment_rental', 'اجاره تجهیزات و ماشین‌آلات',
      'نام و مشخصات تجهیز', 'مثلاً: دوربین توتال استیشن یا بیل مکانیکی',
      counterpartyLabel: 'نام مالک / اجاره‌دهنده'),
  ExpenseCategory('survey', 'هزینه عملیات نقشه‌برداری', 'محل عملیات / نام اکیپ',
      'مثلاً: برداشت قطعه شماره ۴',
      counterpartyLabel: 'شخص / تیم مجری'),
  ExpenseCategory('transport', 'حمل‌ونقل و جابجایی', 'مسیر یا نوع بار',
      'مثلاً: حمل دوربین از انبار به کارگاه',
      counterpartyLabel: 'راننده / شرکت حمل'),
  ExpenseCategory('food', 'غذا و پذیرایی', 'برای چه کسانی / چه مناسبتی',
      'مثلاً: ناهار اکیپ ۵ نفره',
      counterpartyLabel: 'رستوران / فروشنده'),
  ExpenseCategory('materials', 'مصالح و مواد مصرفی', 'نام مصالح یا کالا *',
      'مثلاً: سیمان، بتن، میلگرد',
      detailRequired: true),
  ExpenseCategory('equipment_purchase', 'خرید ابزار و تجهیزات',
      'نام و مدل تجهیز خریداری‌شده *', 'مثلاً: گیرنده GNSS مدل ...',
      detailRequired: true),
  ExpenseCategory(
      'fuel', 'سوخت و روغن', 'نام خودرو / دستگاه', 'مثلاً: وانت کارگاه',
      counterpartyLabel: 'جایگاه / فروشنده'),
  ExpenseCategory('maintenance', 'تعمیرات و نگهداری',
      'تجهیز یا دستگاه تعمیرشده', 'مثلاً: تعمیر سه‌پایه دوربین',
      counterpartyLabel: 'تعمیرکار / شرکت خدماتی'),
  ExpenseCategory('subcontract', 'پیمانکار جزء', 'نام پیمانکار / موضوع کار *',
      'مثلاً: گروه خاک‌برداری',
      detailRequired: true, counterpartyLabel: 'طرف حساب پیمانکار جزء'),
  ExpenseCategory('insurance', 'بیمه و تأمین اجتماعی',
      'بیمه‌شده / دوره / پرونده *', 'مثلاً: حق بیمه کارکنان مهرماه',
      detailRequired: true),
  ExpenseCategory('tax', 'مالیات و عوارض', 'نوع مالیات / شماره پرونده *',
      'مثلاً: عوارض شهرداری قطعه ۳',
      detailRequired: true),
  ExpenseCategory('accommodation', 'اسکان و اقامت', 'محل اسکان / افراد',
      'مثلاً: سوئیت اکیپ نقشه‌برداری',
      counterpartyLabel: 'مالک / هتل'),
  ExpenseCategory('utilities', 'آب، برق، گاز، اینترنت و تلفن',
      'نام محل / نوع قبض *', 'مثلاً: قبض برق دفتر پروژه',
      detailRequired: true),
  ExpenseCategory('permits', 'مجوزها و استعلامات',
      'نوع مجوز / مرجع صادرکننده *', 'مثلاً: مجوز حفاری شهرداری',
      detailRequired: true),
  ExpenseCategory('other', 'سایر هزینه‌ها', 'شرح دقیق هزینه *',
      'عنوان مشخص و قابل پیگیری بنویسید',
      detailRequired: true),
];
ExpenseCategory? expenseCategoryByCode(String code) {
  for (final item in expenseCategories) {
    if (item.code == code) return item;
  }
  return null;
}

class ExpenseDetail {
  const ExpenseDetail(
      {required this.categoryCode,
      required this.detailTitle,
      required this.counterpartyName});
  final String categoryCode, detailTitle, counterpartyName;
  String? validate() {
    final cat = expenseCategoryByCode(categoryCode);
    if (cat == null) return 'دسته هزینه معتبر انتخاب نشده است.';
    if (cat.detailRequired && detailTitle.trim().isEmpty) {
      return 'تکمیل تفصیلی این هزینه الزامی است.';
    }
    if (detailTitle.trim().isEmpty && counterpartyName.trim().isEmpty) {
      return 'نام شخص، تجهیز یا طرف حساب هزینه باید مشخص باشد.';
    }
    if (detailTitle.length > 250 || counterpartyName.length > 250) {
      return 'جزئیات و طرف حساب نباید از ۲۵۰ نویسه بیشتر باشند.';
    }
    return null;
  }

  String get categoryTitle =>
      expenseCategoryByCode(categoryCode)?.name ?? 'نامشخص';
}

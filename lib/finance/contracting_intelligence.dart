/// Offline engineering calculations. These are decision-support estimates,
/// not certified accounting, tax advice or an approved payment certificate.
class EarnedValueAssessment {
  EarnedValueAssessment({
    required this.costBudgetRial,
    required this.actualCostRial,
    required this.actualProgressPercent,
    required this.plannedProgressPercent,
  }) {
    if (costBudgetRial <= 0 || costBudgetRial > maxRial ||
        actualCostRial < 0 || actualCostRial > maxRial ||
        actualProgressPercent < 0 || actualProgressPercent > 100 ||
        plannedProgressPercent < 0 || plannedProgressPercent > 100) {
      throw ArgumentError('بودجه، هزینه یا درصد پیشرفت نامعتبر است');
    }
  }

  static const int maxRial = 9223372036854775807;
  final int costBudgetRial;
  final int actualCostRial;
  final int actualProgressPercent;
  final int plannedProgressPercent;

  static int _percentage(int total, int percent) =>
      (total ~/ 100) * percent + ((total % 100) * percent ~/ 100);

  int get earnedValueRial =>
      _percentage(costBudgetRial, actualProgressPercent);
  int get plannedValueRial =>
      _percentage(costBudgetRial, plannedProgressPercent);
  int get costVarianceRial => earnedValueRial - actualCostRial;
  int get scheduleVarianceRial => earnedValueRial - plannedValueRial;

  /// Null means there is not a meaningful denominator, not a perfect score.
  double? get costPerformanceIndex =>
      actualCostRial == 0 ? null : earnedValueRial / actualCostRial;
  double? get schedulePerformanceIndex =>
      plannedValueRial == 0 ? null : earnedValueRial / plannedValueRial;

  /// EAC = BAC / CPI, assuming the observed cost efficiency persists.
  /// Null when CPI is zero/undefined or the projection is out of rial range.
  int? get forecastCostAtCompletionRial {
    final cpi = costPerformanceIndex;
    if (cpi == null || cpi <= 0) return null;
    final estimate = costBudgetRial / cpi;
    if (!estimate.isFinite || estimate > maxRial || estimate < 0) return null;
    return estimate.round();
  }

  int? get forecastVarianceRial {
    final estimate = forecastCostAtCompletionRial;
    return estimate == null ? null : costBudgetRial - estimate;
  }
}

/// A cumulative interim statement becomes a period-only preview by subtracting
/// the previous cumulative GROSS. Period VAT/deductions are explicit inputs.
class InterimStatementAssessment {
  InterimStatementAssessment({
    required this.cumulativeGrossRial,
    required this.previousGrossRial,
    required this.periodVatRial,
    required this.periodDeductionsRial,
  }) {
    if (cumulativeGrossRial < 0 ||
        cumulativeGrossRial > EarnedValueAssessment.maxRial ||
        previousGrossRial < 0 ||
        previousGrossRial > cumulativeGrossRial ||
        periodVatRial < 0 ||
        periodDeductionsRial < 0 ||
        periodVatRial > EarnedValueAssessment.maxRial -
            (cumulativeGrossRial - previousGrossRial) ||
        periodDeductionsRial >
            cumulativeGrossRial - previousGrossRial + periodVatRial) {
      throw ArgumentError('ارقام صورت‌وضعیت تجمعی یا کسورات نامعتبر است');
    }
  }

  final int cumulativeGrossRial;
  final int previousGrossRial;
  final int periodVatRial;
  final int periodDeductionsRial;

  int get periodGrossRial => cumulativeGrossRial - previousGrossRial;
  int get periodNetRial =>
      periodGrossRial + periodVatRial - periodDeductionsRial;
}

class ContractingReference {
  const ContractingReference({
    required this.topic,
    required this.summary,
    required this.action,
    required this.source,
    required this.url,
  });
  final String topic;
  final String summary;
  final String action;
  final String source;
  final String url;
}

/// Curated summaries with original wording. No copyrighted price-list rows are
/// packaged. Rates, coefficients and legal applicability must be verified for
/// the specific contract, year and latest legislation.
const contractingReferences = <ContractingReference>[
  ContractingReference(
    topic: 'صورت‌وضعیت موقت و تجمعی',
    summary: 'مقدار کارکرد از آغاز پیمان اندازه‌گیری می‌شود. برای محاسبه این دوره، '
        'باید مبلغ تجمعی پیشین تفکیک و از محاسبه مضاعف جلوگیری شود.',
    action: 'صورت‌مجلس‌ها، مقادیر تأییدشده، اقلام پای‌کار و تأیید مشاور را کنترل کنید.',
    source: 'شرایط عمومی پیمان، نشریه ۴۳۱۱، ماده ۳۷',
    url: 'https://oqod.ir/payment-law/',
  ),
  ContractingReference(
    topic: 'صورت‌وضعیت قطعی و تحویل',
    summary: 'صورت‌وضعیت قطعی با صورت‌وضعیت موقت و وضعیت تحویل کارگاه یکسان نیست.',
    action: 'متره قطعی، صورت‌جلسات تحویل، دستورکارها و تغییر مقادیر را بایگانی کنید.',
    source: 'شرایط عمومی پیمان، نشریه ۴۳۱۱، ماده ۴۰',
    url: 'https://www.saeedasgarii.ir/downloads/',
  ),
  ContractingReference(
    topic: 'مالیات بر ارزش افزوده پیمان',
    summary: 'تعلق مالیات و امکان تأخیر در پرداخت آن در قرارداد غیرنقدی تابع '
        'مقررات صدور صورتحساب، ثبت و پرداخت کارفرماست؛ درصد پیشرفت به‌تنهایی '
        'مبنای قطعی مالیات نیست.',
    action: 'شماره و تاریخ صورتحساب، وضعیت تأیید و وصول از کارفرما را جدا نگه دارید.',
    source: 'ماده ۴ قانون ارزش افزوده ۱۴۰۰ و بخشنامه ۱۴۰۵/۰۲/۰۵',
    url: 'https://moshirin.com/laws/maliat-arzesh-afzoodeh',
  ),
  ContractingReference(
    topic: 'بیمه پیمان و مفاصاحساب',
    summary: 'ماده ۳۸ قانون تأمین اجتماعی درباره بیمه کارکنان پیمانکار و '
        'مفاصاحساب مقررات ویژه دارد؛ مبلغ نگهداری‌شده با حق بیمه قطعی یکی نیست.',
    action: 'نوع پیمان، وضعیت لیست بیمه، آخرین قسط و مفاصاحساب را کنترل کنید.',
    source: 'قانون تأمین اجتماعی، ماده ۳۸',
    url: 'https://www.vakilatazare.ir/laws/tamin-ejtemaee/38',
  ),
  ContractingReference(
    topic: 'تضمین حسن انجام کار و پیش‌پرداخت',
    summary: 'تضمین‌ها، وجوه نگهداری‌شده و استهلاک پیش‌پرداخت تعهداتی مستقل‌اند '
        'و نباید بدون مستند قرارداد در یک نرخ عمومی ادغام شوند.',
    action: 'مفاد موافقت‌نامه، شرایط خصوصی و تاریخ آزادسازی تضمین را ثبت کنید.',
    source: 'شرایط عمومی پیمان، نشریه ۴۳۱۱',
    url: 'https://oqod.ir/payment-law/',
  ),
  ContractingReference(
    topic: 'فهرست‌بها و ضرایب',
    summary: 'فهرست‌بها به رشته، سال مبنای ارجاع کار و پیوست‌ها وابسته است. '
        'استفاده از ردیف یا ضریب سال دیگر می‌تواند برآورد را مخدوش کند.',
    action: 'رشته، سال فهرست، فصل و ضرایب قراردادی را پیش از متره تطبیق دهید.',
    source: 'فهرست‌بهای ابنیه ۱۴۰۴، نمونه ابلاغیه سازمان برنامه و بودجه',
    url: 'https://nassira.ir/wp-content/uploads/2025/10/Abnieh1404.pdf',
  ),
  ContractingReference(
    topic: 'ارزش کسب‌شده و شاخص CPI',
    summary: 'شاخص CPI برابر ارزش کسب‌شده بر هزینه واقعی است. ارزش کسب‌شده '
        'از بودجه مصوب هزینه و پیشرفت واقعی به دست می‌آید، نه از دریافتی کارفرما.',
    action: 'بودجه هزینه مصوب را مستقل از مبلغ فروش قرارداد تعیین کنید.',
    source: 'Project Management Institute — Earned Value',
    url: 'https://www.pmi.org/learning/library/make-earned-value-work-project-6001',
  ),
  ContractingReference(
    topic: 'کنترل برنامه زمان‌بندی SPI',
    summary: 'شاخص SPI نسبت ارزش کسب‌شده به ارزش برنامه‌ای است و به '
        'برنامه مبنا و پیشرفت قابل‌اندازه‌گیری نیاز دارد.',
    action: 'پیشرفت برنامه‌ای و واقعی را برای یک تاریخ گزارش مشخص وارد کنید.',
    source: 'PMI — Earned Value Management',
    url: 'https://www.pmi.org/learning/library/earned-value-analysis-cost-management-construction-8203',
  ),
  ContractingReference(
    topic: 'درآمد قرارداد و وجه نقد',
    summary: 'درآمد عملیاتی، صورت‌وضعیت تأییدشده، دریافت نقدی و سود پروژه '
        'چهار مفهوم متفاوت‌اند و نباید در یک گزارش به جای یکدیگر قرار گیرند.',
    action: 'بدهکاران، مطالبات، پیش‌دریافت‌ها و هزینه‌های تحقق‌یافته را تفکیک کنید.',
    source: 'استاندارد حسابداری شماره ۴۳',
    url: 'https://hesabgaranpishtaz.ir/wp-content/uploads/2023/12/43.pdf',
  ),
  ContractingReference(
    topic: 'مدیریت تغییرات پیمان',
    summary: 'دستورکار جدید، تغییر مقادیر، قیمت جدید، تأخیرات و ادعاهای پیمانکار '
        'باید جدا از مبلغ اولیه و با مستندات قابل پیگیری باشند.',
    action: 'شماره ابلاغ، تاریخ، آثار مبلغی/زمانی و مرجع تصویب هر تغییر را ثبت کنید.',
    source: 'شرایط عمومی پیمان، نشریه ۴۳۱۱',
    url: 'https://oqod.ir/payment-law/',
  ),
];

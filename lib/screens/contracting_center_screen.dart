import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../finance/contracting_intelligence.dart';
import '../reports/report_model.dart';
import '../widgets/ui.dart';

/// Contract-specific engineering workspace. It never creates ledger entries.
class ContractingCenterScreen extends StatefulWidget {
  const ContractingCenterScreen({super.key, required this.report});
  final ContractReport report;

  @override
  State<ContractingCenterScreen> createState() =>
      _ContractingCenterScreenState();
}

class _ContractingCenterScreenState extends State<ContractingCenterScreen> {
  final _budget = TextEditingController();
  final _actualProgress = TextEditingController();
  final _plannedProgress = TextEditingController();
  final _cumulative = TextEditingController();
  final _previous = TextEditingController(text: '0');
  final _vat = TextEditingController(text: '0');
  final _deductions = TextEditingController(text: '0');

  @override
  void dispose() {
    for (final controller in [
      _budget, _actualProgress, _plannedProgress,
      _cumulative, _previous, _vat, _deductions
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _numberField(TextEditingController controller, String label,
      {String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );

  int? _percent(String value) {
    final n = int.tryParse(normalizeDigits(value).trim());
    return n != null && n >= 0 && n <= 100 ? n : null;
  }

  Widget _result(String title, String value,
      {bool alert = false, String? subtitle}) =>
      VipCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(value,
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: alert ? const Color(0xFFFFB1A4) : champagne)),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: muted)),
          ],
        ]),
      );

  Widget _pair(Widget first, Widget second) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: first),
          const SizedBox(width: 10),
          Expanded(child: second),
        ]),
      );

  Widget _evmTab() {
    final budget = tomanToRial(_budget.text, allowZero: false);
    final actualProgress = _percent(_actualProgress.text);
    final plannedProgress = _percent(_plannedProgress.text);
    EarnedValueAssessment? value;
    if (budget != null && actualProgress != null && plannedProgress != null) {
      try {
        value = EarnedValueAssessment(
          costBudgetRial: budget,
          actualCostRial: widget.report.costRial,
          actualProgressPercent: actualProgress,
          plannedProgressPercent: plannedProgress,
        );
      } on ArgumentError {
        // Invalid inputs are visible, not written to financial records.
      }
    }
    final snapshot = value;

    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('تحلیل ارزش کسب‌شده',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      const Text(
        'مبنای این تحلیل بودجه مصوب هزینه است، نه مبلغ قرارداد یا مجموع دریافتی‌ها.',
        style: TextStyle(color: muted, fontSize: 13),
      ),
      const SizedBox(height: 15),
      _result('هزینه شناسایی‌شده واقعی همین قرارداد',
          tomanLabel(widget.report.costRial),
          subtitle: 'AC؛ خوانده‌شده از دیتابیس آفلاین'),
      const SizedBox(height: 10),
      _result('مبلغ فروش قرارداد (صرفاً جهت مقایسه)',
          tomanLabel(widget.report.contractAmountRial)),
      const SizedBox(height: 18),
      _numberField(_budget, 'بودجه مصوب هزینه کل پروژه (تومان)',
          hint: 'بودجه هزینه، نه مبلغ فروش'),
      _numberField(_actualProgress, 'پیشرفت واقعی تا تاریخ گزارش (۰ تا ۱۰۰٪)'),
      _numberField(_plannedProgress, 'پیشرفت برنامه‌ای تا همان تاریخ (۰ تا ۱۰۰٪)'),
      if (snapshot == null)
        const VipCard(
          child: Text('برای تحلیل، بودجه هزینه مثبت و هر دو درصد معتبر را وارد کنید.',
              style: TextStyle(color: muted)),
        )
      else ...[
        const SectionHeading('شاخص‌های کنترل پروژه'),
        const SizedBox(height: 11),
        _pair(
          _result('EV · ارزش کسب‌شده', tomanLabel(snapshot.earnedValueRial)),
          _result('PV · ارزش برنامه‌ای', tomanLabel(snapshot.plannedValueRial)),
        ),
        _pair(
          _result('CPI · کارایی هزینه',
              snapshot.costPerformanceIndex?.toStringAsFixed(2) ?? 'نامشخص',
              alert: snapshot.costPerformanceIndex != null &&
                  snapshot.costPerformanceIndex! < 1),
          _result('SPI · کارایی برنامه',
              snapshot.schedulePerformanceIndex?.toStringAsFixed(2) ??
                  'نامشخص',
              alert: snapshot.schedulePerformanceIndex != null &&
                  snapshot.schedulePerformanceIndex! < 1),
        ),
        _pair(
          _result('انحراف هزینه CV', tomanLabel(snapshot.costVarianceRial),
              alert: snapshot.costVarianceRial < 0),
          _result('انحراف برنامه SV', tomanLabel(snapshot.scheduleVarianceRial),
              alert: snapshot.scheduleVarianceRial < 0),
        ),
        _result('EAC · پیش‌بینی هزینه نهایی',
            snapshot.forecastCostAtCompletionRial == null
                ? 'قابل محاسبه نیست'
                : tomanLabel(snapshot.forecastCostAtCompletionRial!),
            alert: snapshot.forecastVarianceRial != null &&
                snapshot.forecastVarianceRial! < 0,
            subtitle: 'فرض: کارایی هزینه مشاهده‌شده در ادامه ثابت بماند'),
      ],
      const SizedBox(height: 15),
      const Text(
        'این محاسبات برآورد مدیریتی است؛ برای تصمیم قراردادی باید '
        'درصد پیشرفت، بودجه مبنا و مستندات کنترل پروژه تأیید شوند. '
        'اطلاعات این فرم در پایگاه داده ذخیره نمی‌شود.',
        style: TextStyle(fontSize: 12, color: muted),
      ),
      const SizedBox(height: 30),
    ]);
  }

  Widget _statementTab() {
    final cumulative = tomanToRial(_cumulative.text, allowZero: true);
    final previous = tomanToRial(_previous.text, allowZero: true);
    final vat = tomanToRial(_vat.text, allowZero: true);
    final deductions = tomanToRial(_deductions.text, allowZero: true);
    InterimStatementAssessment? assessment;
    if (cumulative != null && previous != null &&
        vat != null && deductions != null) {
      try {
        assessment = InterimStatementAssessment(
            cumulativeGrossRial: cumulative,
            previousGrossRial: previous,
            periodVatRial: vat,
            periodDeductionsRial: deductions);
      } on ArgumentError {
        // Explain the invalid period without mutating a real statement.
      }
    }
    final preview = assessment;

    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('محاسبه‌گر صورت‌وضعیت تجمعی',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 9),
      const Text(
        'ابتدا کارکرد ناخالص تجمعی جدید را ثبت کنید. کارکرد دوره جاری برابر '
        'تفاوت آن با ناخالص تجمعی قبلی است.',
        style: TextStyle(color: muted, fontSize: 13),
      ),
      const SizedBox(height: 17),
      _numberField(_cumulative, 'ناخالص تجمعی جدید (تومان)'),
      _numberField(_previous, 'ناخالص تجمعی قبلی (تومان)'),
      _numberField(_vat, 'ارزش افزوده همین دوره (تومان)'),
      _numberField(_deductions, 'مجموع کسورات همین دوره (تومان)'),
      if (preview == null)
        const VipCard(
          child: Text(
            'مبالغ باید نامنفی باشند، تجمعی جدید کمتر از قبلی نباشد و '
            'کسورات از ناخالص دوره به‌علاوه ارزش افزوده بیشتر نشود.',
            style: TextStyle(color: muted),
          ),
        )
      else ...[
        const SectionHeading('پیش‌نمایش دوره جاری'),
        const SizedBox(height: 10),
        _pair(
          _result('کارکرد ناخالص دوره', tomanLabel(preview.periodGrossRial)),
          _result('ارزش افزوده دوره', tomanLabel(preview.periodVatRial)),
        ),
        _pair(
          _result('کسورات دوره', tomanLabel(preview.periodDeductionsRial)),
          _result('خالص برآوردی دوره', tomanLabel(preview.periodNetRial)),
        ),
      ],
      const SizedBox(height: 14),
      const VipCard(
        child: Text(
          'نرخ مالیات، بیمه، سپرده حسن انجام کار، استهلاک پیش‌پرداخت و '
          'دیگر کسورات عمداً به‌صورت ثابت محاسبه نمی‌شوند. '
          'ابتدا بر اساس قرارداد و قوانین تاریخ مربوط، هر رقم را تعیین کنید. '
          'این پیش‌نمایش صورت‌وضعیت رسمی صادر نمی‌کند و هیچ سندی ثبت نمی‌کند.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ),
      const SizedBox(height: 30),
    ]);
  }

  Widget _referenceTab() => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('مرجع آفلاین پیمانکاری',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text(
            'خلاصه‌های کاربردی با منبع قابل بررسی. برای استناد قانونی، '
            'نسخه معتبر در تاریخ قرارداد و آخرین اصلاحات را کنترل کنید.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 15),
          for (final topic in contractingReferences)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VipCard(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text(topic.topic,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  leading: const Icon(Icons.auto_stories_outlined,
                      color: champagne),
                  childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 13),
                  children: [
                    Text(topic.summary),
                    const SizedBox(height: 12),
                    Text('اقدام اجرایی: ' + topic.action,
                        style: const TextStyle(color: mint)),
                    const SizedBox(height: 13),
                    Text(topic.source,
                        style: const TextStyle(color: champagne, fontSize: 12)),
                    const SizedBox(height: 6),
                    SelectableText(topic.url,
                        style: const TextStyle(fontSize: 11, color: muted)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: topic.url));
                          if (mounted) showFeedback(context, 'نشانی منبع کپی شد');
                        },
                        icon: const Icon(Icons.copy_outlined, size: 17),
                        label: const Text('کپی نشانی منبع'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      );

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('مرکز تخصصی پیمان'),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'کنترل پروژه', icon: Icon(Icons.query_stats_outlined)),
                Tab(text: 'صورت‌وضعیت', icon: Icon(Icons.calculate_outlined)),
                Tab(text: 'دانشنامه', icon: Icon(Icons.menu_book_outlined)),
              ],
            ),
          ),
          body: TabBarView(children: [
            _evmTab(),
            _statementTab(),
            _referenceTab(),
          ]),
        ),
      );
}

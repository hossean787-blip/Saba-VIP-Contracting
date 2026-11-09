import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/offline_store.dart';
import '../reports/report_exports.dart';
import '../reports/report_model.dart';
import '../widgets/financial_chart.dart';
import '../widgets/ui.dart';

const reportKinds = <String, String>{
  'all': 'همه اطلاعات',
  'expenses': 'هزینه‌ها',
  'payments': 'پرداخت‌ها',
  'receipts': 'دریافت‌ها',
  'statements': 'صورت‌وضعیت‌ها',
  'activities': 'عملیات',
};

class ProjectReportScreen extends StatefulWidget {
  const ProjectReportScreen(
      {super.key,
      required this.store,
      required this.companyId,
      required this.contractId});
  final OfflineStore store;
  final int companyId;
  final int contractId;
  @override
  State<ProjectReportScreen> createState() => _ProjectReportScreenState();
}

class _ProjectReportScreenState extends State<ProjectReportScreen> {
  late Future<ContractReport> report;
  String kind = 'all';
  bool exporting = false;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    report = widget.store.report(widget.companyId, widget.contractId);
  }

  void _refresh() {
    setState(_reload);
  }

  Future<void> _export(ContractReport snapshot, String extension) async {
    if (exporting) return;
    setState(() => exporting = true);
    try {
      final Uint8List bytes = extension == 'pdf'
          ? await ReportExports.pdf(snapshot, kind: kind)
          : ReportExports.xlsx(snapshot, kind: kind);
      final filename = ReportExports.filename(snapshot, kind, extension);
      final result = await SharePlus.instance.share(ShareParams(
        title: 'خروجی ${reportKinds[kind]}',
        files: [
          XFile.fromData(bytes,
              mimeType: extension == 'pdf'
                  ? 'application/pdf'
                  : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        ],
        fileNameOverrides: [filename],
      ));
      if (!mounted) return;
      if (result.status == ShareResultStatus.success) {
        showFeedback(context, 'فایل برای برنامه انتخاب‌شده ارسال شد.');
      } else if (result.status == ShareResultStatus.dismissed) {
        showFeedback(context, 'اشتراک‌گذاری لغو شد.');
      } else {
        showFeedback(
            context, 'فایل آماده شد؛ وضعیت ذخیره در مقصد قابل تأیید نیست.');
      }
    } catch (e) {
      if (mounted) showFeedback(context, 'خروجی ایجاد نشد: $e', error: true);
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('گزارش و نمودار پروژه'), actions: [
          IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'به‌روزرسانی')
        ]),
        body: FutureBuilder<ContractReport>(
            future: report,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                            'امکان دریافت گزارش نیست: ${snapshot.error}')));
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final data = snapshot.data!;
              final filtered = data.filtered(kind);
              return ListView(padding: const EdgeInsets.all(18), children: [
                const Text('پرونده مالی و اجرایی',
                    style: TextStyle(color: champagne)),
                const SizedBox(height: 5),
                Text(data.contractTitle,
                    style: const TextStyle(
                        color: ivory,
                        fontWeight: FontWeight.bold,
                        fontSize: 23)),
                Text('قرارداد ${data.contractNo}',
                    style: const TextStyle(color: muted)),
                const SizedBox(height: 20),
                const SectionHeading('مقایسه شاخص‌های مالی'),
                const SizedBox(height: 10),
                VipCard(child: FinancialBarChart(report: data)),
                const SizedBox(height: 18),
                const SectionHeading('نمودار دریافت و پرداخت ماهانه'),
                const SizedBox(height: 10),
                VipCard(child: MonthlyCashChart(report: data)),
                const SizedBox(height: 18),
                const SectionHeading('هزینه‌ها به تفکیک نوع'),
                const SizedBox(height: 10),
                VipCard(child: ExpenseCategoryChart(report: data)),
                const SizedBox(height: 18),
                VipCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('مازاد اولیه کار تأییدشده پس از هزینه‌ها',
                          style: TextStyle(color: muted, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(tomanLabel(data.provisionalMarginRial),
                          style: TextStyle(
                              color: data.provisionalMarginRial >= 0
                                  ? mint
                                  : const Color(0xFFFFA9A1),
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('این شاخص سود قطعی حسابداری یا مالیاتی نیست.',
                          style: TextStyle(fontSize: 12, color: muted)),
                      const SizedBox(height: 16),
                      const Text('جریان نقدی (دریافت منهای پرداخت)',
                          style: TextStyle(color: muted, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(tomanLabel(data.cashFlowRial),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ])),
                const SizedBox(height: 22),
                const SectionHeading('ریز اطلاعات و خروجی'),
                const SizedBox(height: 10),
                VipCard(
                    child: Column(children: [
                  DropdownButtonFormField<String>(
                    value: kind,
                    decoration:
                        const InputDecoration(labelText: 'انتخاب گزارش'),
                    items: reportKinds.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => kind = v ?? 'all'),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                        child: FilledButton.icon(
                            onPressed:
                                exporting ? null : () => _export(data, 'pdf'),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('خروجی PDF'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed:
                                exporting ? null : () => _export(data, 'xlsx'),
                            icon: const Icon(Icons.table_chart_outlined),
                            label: const Text('خروجی Excel'))),
                  ]),
                  if (exporting)
                    const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator()),
                ])),
                const SizedBox(height: 12),
                Text('${filtered.length} ردیف',
                    style: const TextStyle(color: muted)),
                for (final item in filtered.take(50))
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: VipCard(
                          padding: const EdgeInsets.all(13),
                          child: Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('${item.kindLabel} · ${item.title}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(jalaliLabel(item.dateIso),
                                      style: const TextStyle(
                                          fontSize: 11, color: muted)),
                                ])),
                            const SizedBox(width: 8),
                            Text(tomanLabel(item.amountRial),
                                style: const TextStyle(
                                    color: champagne, fontSize: 12)),
                          ]))),
                if (filtered.length > 50)
                  const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                          'برای دیدن تمام ردیف‌ها از فایل PDF یا Excel استفاده کنید.',
                          style: TextStyle(color: muted))),
                const SizedBox(height: 35),
              ]);
            }),
      );
}

/// Bottom-tab reports follow the active contract chosen on Home.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen(
      {super.key,
      required this.store,
      required this.company,
      required this.contractId});
  final OfflineStore store;
  final Map<String, Object?> company;
  final int contractId;

  @override
  Widget build(BuildContext context) => FutureBuilder<ContractReport>(
        future: store.report(company['id'] as int, contractId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
                child: Text('امکان بارگذاری گزارش قرارداد: ${snap.error}'));
          }
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final report = snap.data!;
          return ListView(padding: const EdgeInsets.all(18), children: [
            const Text('گزارش‌های مدیریتی',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text('گزارش‌ها فقط مربوط به قرارداد فعال هستند.',
                style: TextStyle(color: muted)),
            const SizedBox(height: 16),
            VipCard(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('قرارداد انتخاب‌شده',
                    style: TextStyle(fontSize: 12, color: champagne)),
                const SizedBox(height: 5),
                Text(report.contractTitle,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text('شماره ${report.contractNo}',
                    style: const TextStyle(color: muted)),
              ],
            )),
            const SizedBox(height: 20),
            const SectionHeading('شاخص‌های مالی قرارداد'),
            const SizedBox(height: 11),
            VipCard(child: FinancialBarChart(report: report)),
            const SizedBox(height: 14),
            VipCard(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('جریان نقدی (دریافت منهای پرداخت)',
                    style: TextStyle(color: muted)),
                const SizedBox(height: 7),
                Text(tomanLabel(report.cashFlowRial),
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.bold)),
              ],
            )),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProjectReportScreen(
                          store: store,
                          companyId: company['id'] as int,
                          contractId: contractId))),
              icon: const Icon(Icons.insights_outlined),
              label: const Text('نمودارها و خروجی PDF / Excel'),
            ),
            const SizedBox(height: 30),
          ]);
        },
      );
}

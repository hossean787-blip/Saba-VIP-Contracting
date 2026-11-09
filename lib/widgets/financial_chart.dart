import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../reports/report_model.dart';

/// Local, accessible chart – no web views, chart services, or network calls.
class FinancialBarChart extends StatelessWidget {
  const FinancialBarChart({super.key, required this.report});
  final ContractReport report;

  @override
  Widget build(BuildContext context) {
    final series = [
      ('هزینه‌ها', report.costRial, const Color(0xFFE79B93)),
      ('پرداخت‌ها', report.paymentRial, const Color(0xFFE2B67A)),
      ('دریافت‌ها', report.receiptRial, mint),
      ('کار تأییدشده', report.approvedGrossRial, const Color(0xFF99BAE1)),
    ];
    final maxValue = series.fold<int>(1, (m, item) => math.max(m, item.$2));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final point in series)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(point.$1,
                  style: const TextStyle(fontSize: 13, color: ivory)),
              Text(tomanLabel(point.$2),
                  style: const TextStyle(fontSize: 12, color: muted)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 11,
                  child: Stack(children: [
                    const ColoredBox(
                        color: panelLight, child: SizedBox.expand()),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: point.$2 / maxValue),
                      duration: const Duration(milliseconds: 750),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => FractionallySizedBox(
                          alignment: Alignment.centerRight,
                          widthFactor: value,
                          child: SizedBox.expand(
                              child: DecoratedBox(
                                  decoration: BoxDecoration(
                                      color: point.$3,
                                      borderRadius:
                                          BorderRadius.circular(8))))),
                    ),
                  ]),
                )),
          ]),
        ),
    ]);
  }
}

class ExpenseCategoryChart extends StatelessWidget {
  const ExpenseCategoryChart({super.key, required this.report});
  final ContractReport report;
  @override
  Widget build(BuildContext context) {
    final values = report.expenseGroups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (values.isEmpty)
      return const Text('هنوز هزینه‌ای برای تحلیل ثبت نشده است.',
          style: TextStyle(color: muted));
    final maxValue = values.first.value;
    return Column(children: [
      for (final row in values.take(8))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(row.key, overflow: TextOverflow.ellipsis)),
              Text(tomanLabel(row.value),
                  style: const TextStyle(color: muted, fontSize: 12))
            ]),
            const SizedBox(height: 6),
            ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: row.value / maxValue,
                  minHeight: 9,
                  backgroundColor: panelLight,
                  color: champagne,
                )),
          ]),
        )
    ]);
  }
}

class MonthlyCashChart extends StatelessWidget {
  const MonthlyCashChart({super.key, required this.report});
  final ContractReport report;
  @override
  Widget build(BuildContext context) {
    final points = report.monthlyCash.entries.toList();
    if (points.isEmpty)
      return const Text('هنوز دریافت یا پرداختی برای رسم نمودار ثبت نشده است.',
          style: TextStyle(color: muted));
    final lastMonths =
        points.length <= 6 ? points : points.sublist(points.length - 6);
    final maxValue = lastMonths.fold<int>(
        1,
        (max, e) => math.max(
            max, math.max(e.value['receipts']!, e.value['payments']!)));
    return Column(children: [
      Row(children: [
        Container(
            width: 9,
            height: 9,
            decoration:
                const BoxDecoration(color: mint, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        const Text('دریافت', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 16),
        Container(
            width: 9,
            height: 9,
            decoration:
                const BoxDecoration(color: champagne, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        const Text('پرداخت', style: TextStyle(fontSize: 12)),
      ]),
      const SizedBox(height: 16),
      SizedBox(
        height: 140,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final point in lastMonths)
            Expanded(
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(children: [
                Expanded(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      Expanded(
                          child: Tooltip(
                              message:
                                  'دریافت: ${tomanLabel(point.value['receipts']!)}',
                              child: FractionallySizedBox(
                                  heightFactor:
                                      point.value['receipts']! / maxValue,
                                  alignment: Alignment.bottomCenter,
                                  child: SizedBox.expand(
                                      child: DecoratedBox(
                                          decoration: BoxDecoration(
                                              color: mint,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      4))))))),
                      const SizedBox(width: 3),
                      Expanded(
                          child: Tooltip(
                              message:
                                  'پرداخت: ${tomanLabel(point.value['payments']!)}',
                              child: FractionallySizedBox(
                                  heightFactor:
                                      point.value['payments']! / maxValue,
                                  alignment: Alignment.bottomCenter,
                                  child: SizedBox.expand(
                                      child: DecoratedBox(
                                          decoration: BoxDecoration(
                                              color: champagne,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      4))))))),
                    ])),
                const SizedBox(height: 6),
                Text(jalaliLabel('${point.key}-01').substring(2, 7),
                    style: const TextStyle(fontSize: 10, color: muted)),
              ]),
            ))
        ]),
      ),
    ]);
  }
}

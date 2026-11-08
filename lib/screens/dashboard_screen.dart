import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/offline_store.dart';
import '../widgets/ui.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.store, required this.company, required this.onOpenContracts, required this.onNewContract});
  final OfflineStore store;
  final Map<String, Object?> company;
  final VoidCallback onOpenContracts;
  final VoidCallback onNewContract;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async { (context as Element).markNeedsBuild(); },
    child: FutureBuilder<Map<String, int>>(
      future: store.dashboard(company['id'] as int),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('خطا در دریافت اطلاعات: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final m = snapshot.data!;
        return ListView(padding: const EdgeInsets.all(20), children: [
          Text('مدیریت ${company['name']}', style: const TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 5),
          const Text('نمای کلی شرکت', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: ivory)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(23),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF34475A), panel], begin: Alignment.topRight, end: Alignment.bottomLeft),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: champagne.withValues(alpha: .4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.stars_rounded, color: champagne), SizedBox(width: 8), Text('ارزش قراردادهای فعال', style: TextStyle(color: champagne))]),
              const SizedBox(height: 12),
              Text(tomanLabel(m['contracts_value']!), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('${m['active']} قرارداد فعال از ${m['total']} قرارداد', style: const TextStyle(color: muted)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Metric('دریافت نقدی', m['receipts']!, Icons.south_west_rounded, mint)),
            const SizedBox(width: 12),
            Expanded(child: _Metric('پرداخت نقدی', m['payments']!, Icons.north_east_rounded, const Color(0xFFFFA9A1))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Metric('هزینه ثبت‌شده', m['costs']!, Icons.receipt_long_outlined, champagne)),
            const SizedBox(width: 12),
            Expanded(child: _Metric('کار تأییدشده', m['approved']!, Icons.verified_outlined, const Color(0xFF9AC5FF))),
          ]),
          const SizedBox(height: 23),
          const SectionHeading('دسترسی سریع'), const SizedBox(height: 12),
          VipCard(child: Column(children: [
            ListTile(leading: const Icon(Icons.post_add_outlined, color: champagne), title: const Text('ثبت قرارداد جدید'),
              subtitle: const Text('ثبت کارفرما، مبلغ و تاریخ‌ها'), trailing: const Icon(Icons.chevron_left), onTap: onNewContract),
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.folder_open_outlined, color: champagne), title: const Text('مشاهده قراردادها'),
              subtitle: const Text('ورود به پرونده مالی و اجرایی پروژه‌ها'), trailing: const Icon(Icons.chevron_left), onTap: onOpenContracts),
          ])),
          const SizedBox(height: 14),
          const Text('هزینه و پرداخت، و همچنین صورت‌وضعیت و دریافت، مستقل محاسبه می‌شوند.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 20),
        ]);
      },
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, this.tint);
  final String label;
  final int value;
  final IconData icon;
  final Color tint;
  @override
  Widget build(BuildContext context) => VipCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: tint), const SizedBox(height: 14),
    Text(label, style: const TextStyle(fontSize: 12, color: muted)), const SizedBox(height: 7),
    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight,
      child: Text(tomanLabel(value), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
  ]));
}

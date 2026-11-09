import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/offline_store.dart';
import '../widgets/ui.dart';
import 'contract_detail.dart';
import 'entry_sheet.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen(
      {super.key,
      required this.store,
      required this.company,
      required this.contractId});
  final OfflineStore store;
  final Map<String, Object?> company;
  final int contractId;
  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  String filter = 'ALL';
  late Future<List<Map<String, Object?>>> future;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => future = widget.store.allActivities(
      widget.company['id'] as int,
      contractId: widget.contractId));

  Future<void> _edit(Map<String, Object?> row) async {
    final result = await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => EntrySheet(
            store: widget.store,
            contractId: row['contract_id'] as int,
            kind: 'activities',
            previous: row));
    if (result == true) _refresh();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, Object?>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
                child: Text('خطا در خواندن فعالیت‌ها: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final all = snapshot.data!;
          final rows = all
              .where((a) => filter == 'ALL' || a['status'] == filter)
              .toList();
          final done = all.where((a) => a['status'] == 'DONE').length;
          return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('عملیات قرارداد فعال',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 25)),
                  const SizedBox(height: 7),
                  Text('${all.length} فعالیت ثبت‌شده • $done تکمیل‌شده',
                      style: const TextStyle(color: muted)),
                  const SizedBox(height: 15),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final item in const [
                      ('ALL', 'همه'),
                      ('PLANNED', 'برنامه‌ریزی'),
                      ('IN_PROGRESS', 'در جریان'),
                      ('DONE', 'تکمیل‌شده'),
                    ])
                      ChoiceChip(
                          label: Text(item.$2),
                          selected: filter == item.$1,
                          onSelected: (_) => setState(() => filter = item.$1)),
                  ]),
                  const SizedBox(height: 15),
                  if (rows.isEmpty)
                    const VipCard(
                        child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                          'فعالیتی در این وضعیت وجود ندارد. از داخل پرونده قرارداد فعالیت جدید ثبت کنید.',
                          style: TextStyle(color: muted)),
                    )),
                  for (final activity in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: VipCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('${activity['contract_title']}',
                                style: const TextStyle(
                                    fontSize: 12, color: champagne)),
                            const SizedBox(height: 7),
                            Row(children: [
                              Expanded(
                                  child: Text('${activity['title']}',
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700))),
                              Text('${activity['progress_percent']}٪',
                                  style: const TextStyle(color: champagne)),
                            ]),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                                value:
                                    ((activity['progress_percent'] as int?) ??
                                            0) /
                                        100,
                                backgroundColor: panelLight,
                                color: mint,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(6)),
                            const SizedBox(height: 10),
                            Text(
                                'موعد: ${jalaliLabel(activity['planned_date'] as String?)}',
                                style: const TextStyle(
                                    color: muted, fontSize: 12)),
                            Row(children: [
                              TextButton.icon(
                                  onPressed: () => _edit(activity),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('اصلاح پیشرفت')),
                              const Spacer(),
                              TextButton(
                                  onPressed: () async {
                                    await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                ContractDetailScreen(
                                                  store: widget.store,
                                                  company: widget.company,
                                                  contractId:
                                                      activity['contract_id']
                                                          as int,
                                                )));
                                    _refresh();
                                  },
                                  child: const Text('پرونده قرارداد')),
                            ]),
                          ])),
                    ),
                  const SizedBox(height: 30),
                ],
              ));
        },
      );
}

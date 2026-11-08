import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/offline_store.dart';
import '../widgets/ui.dart';
import 'contract_detail.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key, required this.store, required this.company, required this.onNewContract});
  final OfflineStore store;
  final Map<String, Object?> company;
  final VoidCallback onNewContract;
  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final search = TextEditingController();
  late Future<List<Map<String, Object?>>> loading;
  @override
  void initState() { super.initState(); _load(); }
  void _load() { loading = widget.store.contracts(widget.company['id'] as int, query: search.text); }
  @override
  void dispose() { search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('مرکز قراردادها', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ivory)),
      const SizedBox(height: 12),
      TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'عنوان، شماره یا کارفرما...'),
        onChanged: (_) => setState(_load)),
    ])),
    Expanded(child: FutureBuilder<List<Map<String, Object?>>>(future: loading, builder: (context, snap) {
      if (snap.hasError) return Center(child: Text('خطا در خواندن قراردادها: ${snap.error}'));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      if (snap.data!.isEmpty) return ListView(padding: const EdgeInsets.all(20), children: [
        EmptyView(title: 'قراردادی پیدا نشد', subtitle: search.text.isNotEmpty ? 'عبارت جستجو را تغییر دهید.' : 'اولین قرارداد شرکت را ثبت کنید.', icon: Icons.folder_open_outlined),
        const SizedBox(height: 16),
        if (search.text.isEmpty) FilledButton.icon(onPressed: widget.onNewContract, icon: const Icon(Icons.add), label: const Text('افزودن قرارداد')),
      ]);
      return RefreshIndicator(
        onRefresh: () async { setState(_load); await loading; },
        child: ListView.separated(
          padding: const EdgeInsets.all(20), itemCount: snap.data!.length,
          separatorBuilder: (context, i) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final c = snap.data![i];
            return InkWell(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ContractDetailScreen(store: widget.store, company: widget.company, contractId: c['id'] as int)));
                if (mounted) setState(_load);
              },
              borderRadius: BorderRadius.circular(22),
              child: VipCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(c['title'].toString(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: champagne.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                    child: Text(c['status'] == 'ACTIVE' ? 'فعال' : 'پیش‌نویس / سایر', style: const TextStyle(fontSize: 11, color: champagne))),
                ]),
                const SizedBox(height: 8),
                Text('شماره ${c['contract_no']}  •  ${c['employer_name']}', style: const TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(tomanLabel(c['amount_rial'] as int), style: const TextStyle(color: champagne, fontWeight: FontWeight.bold)),
                  const Icon(Icons.chevron_left, color: muted),
                ]),
              ])),
            );
          },
        ),
      );
    })),
  ]);
}

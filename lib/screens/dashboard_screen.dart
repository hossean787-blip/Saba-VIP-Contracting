import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/offline_store.dart';
import '../widgets/ui.dart';
import '../data/receivables_store.dart';
import '../finance/receivables_model.dart';
import 'receivables_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen(
      {super.key,
      required this.store,
      required this.company,
      required this.contracts,
      required this.selectedContractId,
      required this.onSelectContract,
      required this.onOpenContracts,
      required this.onNewContract,
      required this.onOpenOperations});
  final OfflineStore store;
  final Map<String, Object?> company;
  final List<Map<String, Object?>> contracts;
  final int? selectedContractId;
  final ValueChanged<int?> onSelectContract;
  final VoidCallback onOpenContracts;
  final VoidCallback onNewContract;
  final VoidCallback onOpenOperations;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, int>> stats;
  Future<ReceivablesSnapshot>? receivables;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final id = widget.selectedContractId;
    stats = id == null
        ? Future.value(<String, int>{})
        : widget.store.dashboardForContract(widget.company['id'] as int, id);
    receivables = id == null
        ? null
        : widget.store.receivables(widget.company['id'] as int, id);
  }

  Widget _metric(String label, int value, IconData icon, Color tint) => VipCard(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 7),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(tomanLabel(value),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold))),
        ],
      ));

  @override
  Widget build(BuildContext context) {
    final id = widget.selectedContractId;
    final selected = widget.contracts.where((row) => row['id'] == id);
    final active = selected.isEmpty ? null : selected.first;

    return RefreshIndicator(
      onRefresh: () async {
        if (id == null) return;
        setState(_reload);
        await stats;
        try {
          await receivables;
        } catch (_) {
          // Non-critical receivables read should not block home refresh.
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          Text('مدیریت ${widget.company['name']}',
              style: const TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 5),
          const Text('داشبورد قرارداد',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: ivory)),
          const SizedBox(height: 14),
          // Small home selector controlling every contract-specific section.
          VipCard(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            child: Row(children: [
              const Icon(Icons.tune_rounded, color: champagne, size: 19),
              const SizedBox(width: 8),
              const Text('قرارداد فعال',
                  style: TextStyle(
                      fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Expanded(
                  child: widget.contracts.isEmpty
                      ? const Text('هنوز قراردادی نیست',
                          style: TextStyle(color: champagne, fontSize: 12))
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                          key: ValueKey('active-select-$id'),
                          value: id,
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(16),
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: champagne),
                          items: widget.contracts
                              .map(
                                (contract) => DropdownMenuItem<int>(
                                  value: contract['id'] as int,
                                  child: Text(contract['title'].toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13)),
                                ),
                              )
                              .toList(),
                          onChanged: widget.onSelectContract,
                        ))),
            ]),
          ),
          if (active == null) ...[
            const SizedBox(height: 22),
            const EmptyView(
                title: 'هنوز قراردادی ثبت نشده',
                subtitle: 'در بخش قراردادها با دکمه + اولین قرارداد را بسازید.',
                icon: Icons.folder_open_outlined),
            const SizedBox(height: 14),
            FilledButton.icon(
                onPressed: widget.onNewContract,
                icon: const Icon(Icons.add),
                label: const Text('ثبت اولین قرارداد')),
          ] else ...[
            const SizedBox(height: 13),
            Text('شماره ${active['contract_no']} • ${active['employer_name']}',
                style: const TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 15),
            FutureBuilder<Map<String, int>>(
              future: stats,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child:
                          Text('آمار قرارداد بارگذاری نشد: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final m = snapshot.data!;
                return Column(children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF34475A), panel],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft),
                      borderRadius: BorderRadius.circular(24),
                      border:
                          Border.all(color: champagne.withValues(alpha: .4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.stars_rounded, color: champagne),
                          SizedBox(width: 8),
                          Text('ارزش قرارداد فعال',
                              style: TextStyle(color: champagne)),
                        ]),
                        const SizedBox(height: 12),
                        Text(tomanLabel(active['amount_rial'] as int),
                            style: const TextStyle(
                                fontSize: 25, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(active['title'].toString(),
                            style: const TextStyle(color: muted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _metric('دریافت نقدی', m['receipts'] ?? 0,
                            Icons.south_west_rounded, mint)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _metric('پرداخت نقدی', m['payments'] ?? 0,
                            Icons.north_east_rounded, const Color(0xFFFFA9A1))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _metric('هزینه ثبت‌شده', m['costs'] ?? 0,
                            Icons.receipt_long_outlined, champagne)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _metric('کار تأییدشده', m['approved'] ?? 0,
                            Icons.verified_outlined, const Color(0xFF9AC5FF))),
                  ]),
                ]);
              },
            ),
            const SizedBox(height: 22),
            if (receivables != null)
              FutureBuilder<ReceivablesSnapshot>(
                future: receivables,
                builder: (context, state) {
                  if (state.hasError) {
                    return const Text(
                        'وضعیت مطالبات موقتاً در دسترس نیست.',
                        style: TextStyle(color: muted, fontSize: 12));
                  }
                  if (!state.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final data = state.data!;
                  return VipCard(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.assessment_outlined, color: champagne),
                        SizedBox(width: 9),
                        Expanded(child: Text('ناظر وصول قرارداد',
                          style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800))),
                      ]),
                      const SizedBox(height: 12),
                      Text('مانده مطالبات تأییدشده: ' +
                          tomanLabel(data.outstandingRial),
                          style: const TextStyle(
                            color: champagne, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('دریافت‌های تخصیص‌نیافته: ' +
                          tomanLabel(data.unallocatedReceiptsRial),
                          style: const TextStyle(color: muted, fontSize: 12)),
                      if (data.attentionCount > 0) ...[
                        const SizedBox(height: 8),
                        Text(data.attentionCount.toString() +
                            ' صورت‌وضعیت نیازمند پیگیری ۳۰روزه',
                            style: const TextStyle(
                              color: Color(0xFFFFB1A4), fontSize: 12)),
                      ],
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.push(context,
                            MaterialPageRoute(builder: (_) =>
                              ReceivablesScreen(
                                store: widget.store,
                                companyId: widget.company['id'] as int,
                                contractId: id!,
                              )));
                          if (mounted) setState(_reload);
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('مشاهده و تطبیق دریافت‌ها'),
                      ),
                    ],
                  ));
                },
              ),
            const SizedBox(height: 23),
            const SectionHeading('دسترسی سریع'),
            const SizedBox(height: 12),
            VipCard(
                child: Column(children: [
              ListTile(
                leading:
                    const Icon(Icons.fact_check_outlined, color: champagne),
                title: const Text('عملیات قرارداد فعال'),
                subtitle: const Text('ثبت و اصلاح پیشرفت همین قرارداد'),
                trailing: const Icon(Icons.chevron_left),
                onTap: widget.onOpenOperations,
              ),
              const Divider(height: 1),
              ListTile(
                leading:
                    const Icon(Icons.folder_open_outlined, color: champagne),
                title: const Text('مدیریت قراردادها'),
                subtitle: const Text('مشاهده فهرست و افزودن قرارداد'),
                trailing: const Icon(Icons.chevron_left),
                onTap: widget.onOpenContracts,
              ),
            ])),
          ],
          const SizedBox(height: 18),
          const Text(
              'هزینه و پرداخت، و صورت‌وضعیت و دریافت، جداگانه محاسبه می‌شوند.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

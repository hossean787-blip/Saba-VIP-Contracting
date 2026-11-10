import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/offline_store.dart';
import '../data/receivables_store.dart';
import '../finance/receivables_model.dart';
import '../finance/receipt_catalog.dart';
import '../widgets/ui.dart';

class ReceivablesScreen extends StatefulWidget {
  const ReceivablesScreen({
    super.key,
    required this.store,
    required this.companyId,
    required this.contractId,
  });
  final OfflineStore store;
  final int companyId;
  final int contractId;
  @override
  State<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends State<ReceivablesScreen> {
  late Future<ReceivablesSnapshot> result;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      result = widget.store.receivables(widget.companyId, widget.contractId);

  Future<void> _refresh() async {
    setState(_load);
    await result;
  }

  Widget _metric(String label, int value, Color color) => VipCard(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(tomanLabel(value),
                style: TextStyle(
                    fontSize: 18, color: color, fontWeight: FontWeight.w800)),
          )
        ]),
      );

  Widget _metricPair(Widget a, Widget b) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          Expanded(child: b),
        ]),
      );

  Future<void> _allocate(
      StatementBalance statement, List<ReceiptBalance> eligible) async {
    if (saving || eligible.isEmpty || statement.remainingRial <= 0) return;
    ReceiptBalance receipt = eligible.first;
    final controller = TextEditingController();
    bool rial = false;
    bool submitting = false;

    void fillMaximum() {
      final maximum = math.min(
          statement.remainingRial, receipt.unallocatedRial);
      rial = maximum % 10 != 0;
      controller.text = (rial ? maximum : maximum ~/ 10).toString();
    }

    fillMaximum();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, updateSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              18, 22, 18, MediaQuery.viewInsetsOf(sheetContext).bottom + 24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('تخصیص وجه · صورت‌وضعیت ' + statement.number,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text('مانده مطالبه: ' +
                  tomanLabel(statement.remainingRial),
                  style: const TextStyle(color: mint)),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: receipt.id,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'دریافت نقدی موجود'),
                items: [
                  for (final item in eligible)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(
                          'دریافت ' + item.id.toString() +
                          ' · ' + tomanLabel(item.unallocatedRial),
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: submitting
                    ? null
                    : (id) => updateSheet(() {
                        receipt = eligible.firstWhere((row) => row.id == id);
                        fillMaximum();
                      }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: rial ? 'مبلغ تخصیص (ریال)' : 'مبلغ تخصیص (تومان)',
                  helperText: 'حداکثر ' + tomanLabel(math.min(
                      receipt.unallocatedRial, statement.remainingRial)),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: rial,
                title: const Text('ثبت مبلغ به ریال'),
                onChanged: submitting
                    ? null
                    : (v) => updateSheet(() {
                        final normalized = normalizeDigits(controller.text)
                            .replaceAll(RegExp(r'[,٬،\s]'), '');
                        final before = int.tryParse(normalized);
                        if (before != null) {
                          final next = v ? before * 10 : before ~/ 10;
                          controller.text = next.toString();
                        }
                        rial = v;
                      }),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          final raw = normalizeDigits(controller.text)
                              .replaceAll(RegExp(r'[,٬،\s]'), '');
                          final money = rial
                              ? int.tryParse(raw)
                              : tomanToRial(controller.text, allowZero: false);
                          if (money == null || money <= 0 ||
                              money > 9223372036854775807) {
                            showFeedback(sheetContext,
                                'مبلغ معتبر وارد کنید.', error: true);
                            return;
                          }
                          updateSheet(() => submitting = true);
                          try {
                            await widget.store.allocateStatementReceipt(
                                companyId: widget.companyId,
                                contractId: widget.contractId,
                                statementId: statement.id,
                                receiptId: receipt.id,
                                amountRial: money);
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext, true);
                            }
                          } catch (error) {
                            if (sheetContext.mounted) {
                              showFeedback(sheetContext,
                                  'تخصیص انجام نشد: ' + error.toString(),
                                  error: true);
                              updateSheet(() => submitting = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.link),
                  label: const Text('تأیید تخصیص'),
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                  'این عملیات فقط ارتباط دو سند را ثبت می‌کند '
                  'و دریافت جدیدی ایجاد نخواهد کرد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
    // Defer disposal until the modal has fully popped.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (confirmed == true && mounted) {
      await _refresh();
      if (mounted) showFeedback(context, 'تخصیص و سابقه آن ثبت شد.');
    }
  }

  Future<void> _unlink(ReceiptAllocation allocation) async {
    if (saving) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اصلاح تخصیص وجه'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('اتصال دریافت شماره ' + allocation.receiptId.toString() +
              ' به مبلغ ' + tomanLabel(allocation.amountRial) +
              ' حذف می‌شود؛ اصل دریافت باقی می‌ماند.'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLength: 300,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'دلیل اصلاح (حداقل ۵ نویسه)'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(
                  dialogContext, controller.text.trim()),
              child: const Text('ثبت اصلاح')),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (reason == null || !mounted) return;
    setState(() => saving = true);
    try {
      await widget.store.unlinkStatementReceipt(
        companyId: widget.companyId,
        contractId: widget.contractId,
        statementId: allocation.statementId,
        receiptId: allocation.receiptId,
        reason: reason,
      );
      if (mounted) {
        await _refresh();
        if (mounted) showFeedback(context, 'اصلاح و دلیل آن ثبت شد.');
      }
    } catch (e) {
      if (mounted) showFeedback(
          context, 'اصلاح انجام نشد: ' + e.toString(), error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _status(String status) => switch (status) {
        'APPROVED' => 'تأییدشده',
        'SUBMITTED' => 'ارسال‌شده',
        'DRAFT' => 'پیش‌نویس',
        'REJECTED' => 'ردشده',
        _ => 'نامشخص',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('مرکز مطالبات پیمان'),
            actions: [
              IconButton(
                  onPressed: saving ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'به‌روزرسانی'),
            ]),
        body: FutureBuilder<ReceivablesSnapshot>(
          future: result,
          builder: (context, state) {
            if (state.hasError) {
              return Center(child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('بارگذاری انجام نشد: ' +
                      state.error.toString())));
            }
            if (!state.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = state.data!;
            final eligible = data.selectableReceipts;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
                children: [
                  const Text('وضعیت وصول قرارداد',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text(
                      'صورت‌وضعیت تأییدشده، وجه دریافت‌شده و '
                      'مطالبه باقیمانده جداگانه کنترل می‌شوند.',
                      style: TextStyle(fontSize: 12, color: muted)),
                  const SizedBox(height: 15),
                  _metricPair(
                    _metric('خالص کار تأییدشده',
                        data.approvedNetRial, champagne),
                    _metric('وصول تخصیص‌یافته',
                        data.allocatedRial, mint),
                  ),
                  _metricPair(
                    _metric('مانده مطالبات',
                        data.outstandingRial,
                        const Color(0xFFFFB1A4)),
                    _metric('دریافت‌های تخصیص‌نیافته',
                        data.unallocatedReceiptsRial, champagne),
                  ),
                  const Text(
                    'مانده تخصیص‌نیافته می‌تواند شامل پیش‌دریافت '
                    'یا استرداد باشد و لزوماً مطالبه این صورت‌وضعیت‌ها نیست.',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                  const SizedBox(height: 24),
                  const SectionHeading('صورت‌وضعیت‌ها و مانده'),
                  const SizedBox(height: 11),
                  if (data.statements.isEmpty)
                    const EmptyView(
                      title: 'صورت‌وضعیتی ثبت نشده',
                      subtitle: 'ابتدا در درآمدها صورت‌وضعیت ایجاد کنید.',
                    ),
                  for (final statement in data.statements)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: VipCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(child: Text(
                                  'صورت‌وضعیت ' + statement.number,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16))),
                              Text(_status(statement.status),
                                  style: TextStyle(
                                      color: statement.approved ? mint : muted,
                                      fontSize: 11)),
                            ]),
                            const SizedBox(height: 5),
                            Text('تاریخ سند: ' + jalaliLabel(statement.date),
                                style: const TextStyle(
                                    fontSize: 11, color: muted)),
                            const SizedBox(height: 10),
                            Text('خالص دوره: ' +
                                tomanLabel(statement.netRial)),
                            Text('وصول تخصیص‌یافته: ' +
                                tomanLabel(statement.allocatedRial),
                                style: const TextStyle(color: mint)),
                            Text('مانده: ' +
                                tomanLabel(statement.remainingRial),
                                style: const TextStyle(
                                    color: champagne,
                                    fontWeight: FontWeight.w700)),
                            if (statement.needsReviewOn(DateTime.now()))
                              const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'نیاز به پیگیری: ۳۰ روز از تاریخ سند '
                                    'گذشته است؛ این علامت سررسید قانونی نیست.',
                                    style: TextStyle(
                                        color: Color(0xFFFFB1A4),
                                        fontSize: 11))),
                            if (statement.approved &&
                                statement.remainingRial > 0) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                  onPressed: saving || eligible.isEmpty
                                      ? null
                                      : () => _allocate(statement, eligible),
                                  icon: const Icon(Icons.add_link),
                                  label: const Text('تخصیص دریافت')),
                            ],
                            for (final item in data.allocations.where(
                                (a) => a.statementId == statement.id))
                              Row(children: [
                                Expanded(child: Text(
                                    'دریافت ' + item.receiptId.toString() +
                                    ': ' + tomanLabel(item.amountRial),
                                    style: const TextStyle(
                                        color: muted, fontSize: 11))),
                                TextButton(
                                    onPressed: saving
                                        ? null
                                        : () => _unlink(item),
                                    child: const Text('اصلاح ارتباط')),
                              ]),
                          ],
                        ),
                      ),
                    ),
                  if (eligible.isEmpty && data.outstandingRial > 0)
                    const Text('برای اتصال، ابتدا دریافت واقعی مرتبط '
                        'با صورت‌وضعیت را در درآمدها ثبت کنید.',
                        style: TextStyle(color: muted)),
                  const SizedBox(height: 22),
                  const SectionHeading('دریافت‌ها'),
                  const SizedBox(height: 9),
                  for (final receipt in data.receipts)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: VipCard(
                            padding: const EdgeInsets.all(13),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('دریافت ' + receipt.id.toString() +
                                      ' · ' +
                                      (receiptCategoryByCode(receipt.categoryCode)
                                          ?.name ?? 'دریافت قدیمی'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 5),
                                  Text(jalaliLabel(receipt.date) +
                                      (receipt.payer.isEmpty
                                          ? '' : ' · ' + receipt.payer),
                                      style: const TextStyle(
                                          fontSize: 11, color: muted)),
                                  Text('مبلغ دریافت: ' +
                                      tomanLabel(receipt.amountRial)),
                                  Text('بدون تخصیص: ' +
                                      tomanLabel(receipt.unallocatedRial),
                                      style: const TextStyle(color: champagne)),
                                ]))),
                  const SizedBox(height: 20),
                  const SectionHeading('ردپای تخصیص و اصلاح'),
                  const SizedBox(height: 8),
                  if (data.audit.isEmpty)
                    const Text('تغییری ثبت نشده است.',
                        style: TextStyle(color: muted)),
                  for (final entry in data.audit)
                    ListTile(
                      dense: true,
                      leading: Icon(
                          entry.action == 'UNLINK'
                              ? Icons.history_toggle_off
                              : Icons.fact_check_outlined,
                          color: entry.action == 'UNLINK'
                              ? const Color(0xFFFFB1A4) : mint),
                      title: Text(
                        (entry.action == 'LEGACY'
                            ? 'سابقه قدیمی'
                            : entry.action == 'UNLINK'
                                ? 'اصلاح تخصیص'
                                : 'تخصیص جدید') +
                        ' · صورت‌وضعیت ' + entry.statementNumber,
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: Text('دریافت ' +
                          entry.receiptId.toString() +
                          ' · ' + entry.happenedAt,
                          style: const TextStyle(
                              fontSize: 10, color: muted)),
                      trailing: Text(tomanLabel(entry.amountRial),
                          style: const TextStyle(
                              fontSize: 11, color: champagne)),
                    ),
                ],
              ),
            );
          },
        ),
      );
}

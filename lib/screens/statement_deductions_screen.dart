import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/offline_store.dart';
import '../data/statement_deduction_store.dart';
import '../finance/deduction_model.dart';
import '../widgets/ui.dart';

/// Detailed user-entered deductions for a single period statement.
/// Uses literal rial fields to avoid losing residual 1-9 rial on editing.
class StatementDeductionsScreen extends StatefulWidget {
  const StatementDeductionsScreen({
    super.key,
    required this.store,
    required this.companyId,
    required this.contractId,
    required this.statementId,
  });
  final OfflineStore store;
  final int companyId;
  final int contractId;
  final int statementId;

  @override
  State<StatementDeductionsScreen> createState() =>
      _StatementDeductionsScreenState();
}

class _StatementDeductionsScreenState
    extends State<StatementDeductionsScreen> {
  final amounts = <String, TextEditingController>{};
  final references = <String, TextEditingController>{};
  final reason = TextEditingController();
  DeductionSnapshot? snapshot;
  Object? problem;
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    for (final kind in deductionKinds) {
      amounts[kind.code] = TextEditingController();
      references[kind.code] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    for (final controller in amounts.values) {
      controller.dispose();
    }
    for (final controller in references.values) {
      controller.dispose();
    }
    reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      problem = null;
    });
    try {
      final next = await widget.store.statementDeductionSnapshot(
          companyId: widget.companyId,
          contractId: widget.contractId,
          statementId: widget.statementId);
      if (!mounted) return;
      final lines = {
        for (final entry in next.lines) entry.kind: entry,
      };
      for (final kind in deductionKinds) {
        final line = lines[kind.code];
        final legacy = kind.code == 'other' && next.unclassifiedRial > 0
            ? next.unclassifiedRial
            : 0;
        final value = (line?.amountRial ?? 0) + legacy;
        amounts[kind.code]!.text = value == 0 ? '' : value.toString();
        references[kind.code]!.text = line?.basisRef ?? '';
      }
      setState(() {
        snapshot = next;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        problem = error;
        loading = false;
      });
    }
  }

  String _describeRows(String jsonText) {
    try {
      final records = jsonDecode(jsonText);
      if (records is! List || records.isEmpty) {
        return 'در این مرحله تفکیک ثبت‌شده‌ای وجود نداشت.';
      }
      final descriptions = <String>[];
      for (final row in records) {
        if (row is! Map) continue;
        final code = (row['kind'] ?? '').toString();
        final label = deductionKinds
            .where((item) => item.code == code)
            .map((item) => item.label)
            .firstOrNull ?? code;
        final money = row['amount_rial'];
        final value = money is int
            ? tomanLabel(money)
            : 'مبلغ نامعتبر';
        descriptions.add(label + ' — ' + value + '\nمستند: ' +
            (row['basis_ref'] ?? 'نامشخص').toString());
      }
      return descriptions.join('\n\n');
    } catch (_) {
      return 'نمایش ریز تغییرات این سابقه ممکن نیست.';
    }
  }

  Future<void> _showRevision(DeductionRevision revision) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('جزئیات سابقه کسورات'),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('علت: ' + revision.reason),
                const SizedBox(height: 8),
                Text(revision.changedAt,
                    style: const TextStyle(color: muted, fontSize: 11)),
                const SizedBox(height: 13),
                const Text('قبل از اصلاح',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: champagne)),
                const SizedBox(height: 5),
                Text(_describeRows(revision.beforeJson)),
                const Divider(height: 24),
                const Text('بعد از اصلاح',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: mint)),
                const SizedBox(height: 5),
                Text(_describeRows(revision.afterJson)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  int? _rial(String text) {
    if (text.trim().isEmpty) return 0;
    final normalized = normalizeDigits(text)
        .replaceAll(RegExp(r'[٬،,\s]'), '');
    if (!RegExp(r'^\d+$').hasMatch(normalized)) return null;
    return int.tryParse(normalized);
  }

  int? get proposedTotal {
    var total = BigInt.zero;
    for (final controller in amounts.values) {
      final value = _rial(controller.text);
      if (value == null || value < 0) return null;
      total += BigInt.from(value);
    }
    if (total > BigInt.from(9223372036854775807)) return null;
    return total.toInt();
  }

  Future<void> _save() async {
    if (saving || snapshot == null) return;
    final list = <DeductionLine>[];
    for (final kind in deductionKinds) {
      final amount = _rial(amounts[kind.code]!.text);
      if (amount == null || amount < 0) {
        showFeedback(context,
            'مبلغ ' + kind.label + ' صحیح نیست.', error: true);
        return;
      }
      if (amount == 0) continue;
      final reference = references[kind.code]!.text.trim();
      if (reference.length < 3 || reference.length > 160) {
        showFeedback(context,
            'مستند ' + kind.label + ' باید ۳ تا ۱۶۰ نویسه داشته باشد.',
            error: true);
        return;
      }
      list.add(DeductionLine(
          kind: kind.code,
          amountRial: amount,
          basisRef: reference));
    }
    final reasonText = reason.text.trim();
    if (reasonText.length < 5 || reasonText.length > 300) {
      showFeedback(context, 'دلیل تفکیک یا اصلاح را وارد کنید.',
          error: true);
      return;
    }
    setState(() => saving = true);
    try {
      await widget.store.replaceStatementDeductions(
          companyId: widget.companyId,
          contractId: widget.contractId,
          statementId: widget.statementId,
          lines: list,
          reason: reasonText);
      if (!mounted) return;
      reason.clear();
      await _load();
      if (mounted) {
        showFeedback(context, 'ریز کسورات، جمع و سابقه اصلاح ثبت شد.');
      }
    } catch (error) {
      if (mounted) {
        showFeedback(context, 'ذخیره انجام نشد: ' + error.toString(),
            error: true);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _metric(String caption, int value, Color tint) => VipCard(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(caption, style: const TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(tomanLabel(value),
                style: TextStyle(
                    color: tint, fontSize: 17, fontWeight: FontWeight.w800)),
          )
        ]),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('ریز کسورات صورت‌وضعیت'),
          actions: [
            IconButton(
                tooltip: 'بارگذاری مجدد',
                onPressed: saving ? null : _load,
                icon: const Icon(Icons.refresh)),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : problem != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('بارگذاری کسورات ممکن نشد: ' +
                          problem.toString()),
                    ),
                  )
                : _loaded(context, snapshot!),
      );

  Widget _loaded(BuildContext context, DeductionSnapshot current) {
    final newTotal = proposedTotal;
    final net = newTotal == null
        ? null
        : BigInt.from(current.grossRial) +
            BigInt.from(current.vatRial) - BigInt.from(newTotal);
    final netWithinRange = net != null &&
        net >= BigInt.zero &&
        net <= BigInt.from(9223372036854775807);
    final candidateNet = netWithinRange ? net.toInt() : null;
    final canSettle = candidateNet != null &&
        candidateNet >= current.allocatedReceiptsRial;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        Text('صورت‌وضعیت ' + current.number,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('وضعیت: ' + current.status,
            style: const TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: _metric(
              'کسورات ثبت‌شده', current.totalDeductionsRial, champagne)),
          const SizedBox(width: 10),
          Expanded(child: _metric(
              'دریافت تخصیص‌یافته', current.allocatedReceiptsRial, mint)),
        ]),
        const SizedBox(height: 10),
        _metric('خالص فعلی صورت‌وضعیت',
            current.netPayableRial, ivory),
        if (current.unclassifiedRial != 0) ...[
          const SizedBox(height: 12),
          VipCard(
            child: Text(
              'مبلغ دسته‌بندی‌نشده قبلی: ' +
                  tomanLabel(current.unclassifiedRial) +
                  '. این مبلغ فقط برای تکمیل فرم در «سایر کسورات» '
                  'نمایش داده شده و تا ثبت مجدد، تغییر نمی‌کند.',
              style: const TextStyle(
                  color: Color(0xFFFFC0A4), fontSize: 12, height: 1.6),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const SectionHeading('تفکیک مبلغ به ردیف‌های مستند'),
        const SizedBox(height: 9),
        const Text(
          'مبالغ به ریال وارد شوند تا هیچ مانده ریالی از بین نرود. '
          'نرخ‌ها و درصدهای کسورات به‌صورت خودکار یا قانونی فرض نمی‌شوند.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        for (final kind in deductionKinds)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VipCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kind.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(kind.help,
                      style: const TextStyle(fontSize: 11, color: muted)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amounts[kind.code],
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        labelText: 'مبلغ کسور (ریال)',
                        hintText: '0'),
                  ),
                  if ((_rial(amounts[kind.code]!.text) ?? 0) > 0) ...[
                    const SizedBox(height: 9),
                    TextField(
                      controller: references[kind.code],
                      maxLength: 160,
                      decoration: const InputDecoration(
                        labelText: 'مستند / شماره نامه / بند پیمان *',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        VipCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('کنترل محاسبه قبل از ثبت',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(newTotal == null
                  ? 'جمع نامعتبر'
                  : 'جمع کسورات جدید: ' + tomanLabel(newTotal),
                  style: const TextStyle(color: champagne)),
              const SizedBox(height: 6),
              Text(candidateNet == null
                  ? 'خالص محاسبه‌شده نامعتبر است.'
                  : 'خالص پس از اصلاح: ' + tomanLabel(candidateNet),
                  style: TextStyle(
                      color: canSettle ? mint : const Color(0xFFFFC0A4))),
              if (!canSettle)
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Text(
                    'خالص جدید نمی‌تواند از وجهی که قبلاً به این '
                    'صورت‌وضعیت تخصیص یافته کمتر باشد.',
                    style: TextStyle(
                        color: Color(0xFFFFC0A4), fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: reason,
          maxLength: 300,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'دلیل تفکیک یا اصلاح کسورات *',
            hintText: 'مثلاً تطبیق کسورات با نامه رسیدگی کارفرما',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: saving || !canSettle ? null : _save,
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(saving
              ? 'در حال ثبت...' : 'ثبت ریز کسورات و سابقه تغییرات'),
        ),
        const SizedBox(height: 19),
        const SectionHeading('سوابق تغییرات'),
        const SizedBox(height: 8),
        if (current.revisions.isEmpty)
          const Text('هنوز ریز کسورات ثبت و تأیید نشده است.',
              style: TextStyle(color: muted)),
        for (final item in current.revisions)
          ListTile(
            dense: true,
            leading: const Icon(Icons.history_rounded, color: champagne),
            title: Text(
              'از ' + tomanLabel(item.previousRial) +
                  ' به ' + tomanLabel(item.currentRial),
              style: const TextStyle(fontSize: 12),
            ),
            subtitle: Text(item.changedAt + ' · ' + item.reason +
                '\nلمس کنید تا ریز تغییرات و مستندات را ببینید',
                maxLines: 4,
                style: const TextStyle(color: muted, fontSize: 11)),
            onTap: () => _showRevision(item),
          ),
        const SizedBox(height: 15),
        const Text(
          'تغییرات فقط به مبلغ کسورات همین صورت‌وضعیت اثر دارد. '
          'هیچ وجه، پرداخت یا سند هزینه جدید ایجاد نمی‌شود. '
          'ردیف‌های کسور به معنی تایید قانونی نرخ‌ها نیستند.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.6),
        ),
      ],
    );
  }
}

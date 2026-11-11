import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/offline_store.dart';
import '../widgets/ui.dart';
import 'contract_form.dart';
import 'entry_sheet.dart';
import 'expense_payment_sheet.dart';
import '../finance/expense_payment.dart';
import '../finance/finance_kind.dart';
import '../widgets/expense_payment_status.dart';
import 'report_screen.dart';
import 'statement_deductions_screen.dart';
import 'boq_screen.dart';

class ContractDetailScreen extends StatefulWidget {
  const ContractDetailScreen(
      {super.key,
      required this.store,
      required this.company,
      required this.contractId});
  final OfflineStore store;
  final Map<String, Object?> company;
  final int contractId;
  @override
  State<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen> {
  late Future<Map<String, Object?>?> future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    future = widget.store.contract(widget.contractId);
  }

  void _refresh() {
    setState(_load);
  }

  Future<void> _add(String kind) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => EntrySheet(
          store: widget.store, contractId: widget.contractId, kind: kind),
    );
    if (result == true) _refresh();
  }

  Future<void> _editActivity(Map<String, Object?> activity) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EntrySheet(
          store: widget.store,
          contractId: widget.contractId,
          kind: 'activities',
          previous: activity),
    );
    if (changed == true) _refresh();
  }

  Future<void> _editDocument(
      String kind, Map<String, Object?> record) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EntrySheet(
        store: widget.store,
        contractId: widget.contractId,
        kind: kind,
        previous: record,
      ),
    );
    if (changed == true && mounted) _refresh();
  }

  Future<void> _deleteDocument(
      String kind, Map<String, Object?> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف سند'),
        content: Text(kind == 'expenses'
            ? 'با حذف این هزینه، پرداخت‌های اختصاصی آن نیز حذف می‌شوند. اگر پرداخت مشترک باشد، عملیات متوقف می‌شود. حذف قابل بازگشت نیست.'
            : 'این سند حذف می‌شود. در صورت وجود وابستگی مالی، حذف مسدود خواهد شد. ادامه می‌دهید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف سند')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (kind == 'activities') {
        await widget.store.deleteActivity(
            widget.contractId, record['id'] as int);
      } else {
        final financialKind = FinanceKind.values.firstWhere(
            (value) => value.table == kind && value != FinanceKind.payments);
        await widget.store.deleteFinancialRecord(
            widget.contractId, record['id'] as int, financialKind);
      }
      if (mounted) {
        _refresh();
        showFeedback(context, 'سند حذف شد.');
      }
    } catch (error) {
      if (mounted) {
        showFeedback(context, 'حذف انجام نشد: $error', error: true);
      }
    }
  }

  Future<void> _openDeductions(Map<String, Object?> row) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => StatementDeductionsScreen(
        store: widget.store,
        companyId: widget.company['id'] as int,
        contractId: widget.contractId,
        statementId: row['id'] as int,
      ),
    ));
    if (mounted) _refresh();
  }

  Future<void> _payExpense(Map<String, Object?> expense) async {
    final remaining = remainingExpenseRial(expense['amount_rial'] as int,
        (expense['allocated_paid_rial'] as int?) ?? 0);
    if (remaining <= 0) return;
    final result = await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => ExpensePaymentSheet(
            store: widget.store,
            contractId: widget.contractId,
            expenseId: expense['id'] as int,
            remainingRial: remaining));
    if (result == true && mounted) _refresh();
  }

  Widget _stat(String title, int amount, {Color color = ivory}) => VipCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 8),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(tomanLabel(amount),
                style: TextStyle(
                    color: color, fontSize: 17, fontWeight: FontWeight.w700))),
      ]));

  Widget _information(String title, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Text(title, style: const TextStyle(color: muted)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(value,
                textAlign: TextAlign.left,
                style: const TextStyle(fontWeight: FontWeight.w600)))
      ]));

  Widget _listOf(String kind, String heading) =>
      FutureBuilder<List<Map<String, Object?>>>(
        future: widget.store.records(widget.contractId, kind),
        builder: (context, snap) {
          if (snap.hasError) return Text('خطا در $heading: ${snap.error}');
          final rows = snap.data ?? [];
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeading(heading,
                    trailing: kind == 'payments'
                        ? const Text('ثبت از روی هزینه',
                            style: TextStyle(fontSize: 11, color: muted))
                        : TextButton.icon(
                            onPressed: () => _add(kind),
                            icon: const Icon(Icons.add, size: 17),
                            label: const Text('ثبت'))),
                if (rows.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('هنوز موردی ثبت نشده است.',
                          style: TextStyle(color: muted))),
                ...rows.take(5).map((r) {
                  final isActivity = kind == 'activities';
                  final isStatement = kind == 'statements';
                  final date =
                      (r['${kind == 'activities' ? 'planned' : kind == 'expenses' ? 'expense' : kind == 'payments' ? 'payment' : kind == 'receipts' ? 'receipt' : 'statement'}_date'])
                          ?.toString();
                  final display = isActivity
                      ? r['title']
                      : isStatement
                          ? 'صورت‌وضعیت ${r['statement_no']}'
                          : kind == 'expenses'
                              ? r['category']
                              : (kind == 'payments' ? 'پرداخت' : 'دریافت');
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                          onTap: isActivity ? () => _editActivity(r) : null,
                          child: VipCard(
                              padding: const EdgeInsets.all(13),
                              child: Row(children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text('$display',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      if (kind == 'expenses' &&
                                          ((r['detail_title'] ?? '')
                                                  .toString()
                                                  .trim()
                                                  .isNotEmpty ||
                                              (r['counterparty_name'] ?? '')
                                                  .toString()
                                                  .trim()
                                                  .isNotEmpty)) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                            [
                                              if ((r['detail_title'] ?? '')
                                                  .toString()
                                                  .trim()
                                                  .isNotEmpty)
                                                (r['detail_title'] ?? '')
                                                    .toString(),
                                              if ((r['counterparty_name'] ?? '')
                                                  .toString()
                                                  .trim()
                                                  .isNotEmpty)
                                                'طرف حساب: ${r['counterparty_name']}',
                                            ].join(' • '),
                                            style: const TextStyle(
                                                fontSize: 11, color: muted)),
                                      ],
                                      if (kind == 'expenses') ...[
                                        const SizedBox(height: 8),
                                        ExpensePaymentStatus(
                                            expenseRial:
                                                r['amount_rial'] as int,
                                            paidRial: (r['allocated_paid_rial']
                                                    as int?) ??
                                                0,
                                            onPay: () => _payExpense(r)),
                                      ],
                                      if (kind == 'receipts') ...[
                                        if ((r['counterparty_name'] ?? '')
                                                .toString()
                                                .trim()
                                                .isNotEmpty ||
                                            (r['detail_title'] ?? '')
                                                .toString()
                                                .trim()
                                                .isNotEmpty)
                                          Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
                                              child: Text(
                                                  [
                                                    if ((r['counterparty_name'] ??
                                                            '')
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty)
                                                      'از: ${r['counterparty_name']}',
                                                    if ((r['detail_title'] ??
                                                            '')
                                                        .toString()
                                                        .trim()
                                                        .isNotEmpty)
                                                      'تفصیلی: ${r['detail_title']}',
                                                  ].join(' • '),
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: muted))),
                                      ],
                                      if (kind == 'statements') ...[
                                        const SizedBox(height: 4),
                                        Text(
                                            'خالص پس از ارزش افزوده و کسورات: ${tomanLabel((r['gross_rial'] as int) + ((r['vat_rial'] as int?) ?? 0) - ((r['deductions_rial'] as int?) ?? 0))}',
                                            style: const TextStyle(
                                                fontSize: 11, color: muted)),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(jalaliLabel(date),
                                          style: const TextStyle(
                                              fontSize: 11, color: muted)),
                                    ])),
                                Text(
                                    isActivity
                                        ? '${r['progress_percent']}٪'
                                        : tomanLabel((r[isStatement
                                                ? 'gross_rial'
                                                : 'amount_rial'] as int?) ??
                                            0),
                                    style: const TextStyle(
                                        color: champagne,
                                        fontWeight: FontWeight.w700)),
                                PopupMenuButton<String>(
                                  tooltip: 'مدیریت سند',
                                  icon: const Icon(Icons.more_vert,
                                      color: champagne),
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _editDocument(kind, r);
                                    } else if (action == 'delete') {
                                      _deleteDocument(kind, r);
                                    } else if (action == 'deductions') {
                                      _openDeductions(r);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                        value: 'edit', child: Text('ویرایش سند')),
                                    const PopupMenuItem(
                                        value: 'delete', child: Text('حذف سند')),
                                    if (isStatement)
                                      const PopupMenuItem(
                                        value: 'deductions',
                                        child: Text('ریز کسورات و مستندات')),
                                  ],
                                ),
                              ]))));
                }),
                const SizedBox(height: 6),
              ]);
        },
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('پرونده قرارداد'), actions: [
          IconButton(
              icon: const Icon(Icons.insert_chart_outlined),
              tooltip: 'نمودار و گزارش',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProjectReportScreen(
                          store: widget.store,
                          companyId: widget.company['id'] as int,
                          contractId: widget.contractId)))),
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'بارگذاری مجدد',
              onPressed: _refresh),
        ]),
        body: FutureBuilder<Map<String, Object?>?>(
            future: future,
            builder: (context, snap) {
              if (snap.hasError)
                return Center(
                    child: Text('خطا در خواندن پرونده: ${snap.error}'));
              if (snap.connectionState != ConnectionState.done)
                return const Center(child: CircularProgressIndicator());
              final c = snap.data;
              if (c == null)
                return const Center(child: Text('قرارداد پیدا نشد'));
              return ListView(padding: const EdgeInsets.all(20), children: [
                Text('${c['contract_no']}',
                    style: const TextStyle(
                        color: champagne, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text('${c['title']}',
                    style: const TextStyle(
                        fontSize: 25, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                VipCard(
                    child: Column(children: [
                  _information('کارفرما', '${c['employer_name']}'),
                  _information('پیمانکار', '${c['contractor_name']}'),
                  _information('شروع', jalaliLabel(c['start_date'] as String?)),
                  _information('پایان', jalaliLabel(c['end_date'] as String?)),
                  _information(
                      'مبلغ قرارداد', tomanLabel(c['amount_rial'] as int)),
                  if ((c['location'] ?? '').toString().isNotEmpty)
                    _information('محل پروژه', '${c['location']}'),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => ContractFormScreen(
                                          store: widget.store,
                                          company: widget.company,
                                          previous: c,
                                          onSaved: () {
                                            Navigator.pop(context);
                                          },
                                        )));
                            _refresh();
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('ویرایش اطلاعات'))),
                ])),
                const SizedBox(height: 23),
                const SectionHeading('خلاصه مالی قرارداد'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProjectReportScreen(
                                store: widget.store,
                                companyId: widget.company['id'] as int,
                                contractId: widget.contractId))),
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('نمودارها و خروجی PDF / Excel')),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => BoqScreen(
                        store: widget.store,
                        companyId: widget.company['id'] as int,
                        contractId: widget.contractId)));
                    if (mounted) _refresh();
                  },
                  icon: const Icon(Icons.straighten_outlined),
                  label: const Text('متره، ردیف‌های برآورد و صورت‌وضعیت'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _stat('هزینه‌ها', c['cost_rial'] as int,
                          color: const Color(0xFFFFB1A4))),
                  const SizedBox(width: 10),
                  Expanded(child: _stat('پرداخت‌ها', c['paid_rial'] as int)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _stat('دریافت‌ها', c['received_rial'] as int,
                          color: mint)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _stat('صورت‌وضعیت تأییدشده',
                          c['approved_work_rial'] as int)),
                ]),
                const SizedBox(height: 10),
                _stat('مازاد اولیه کار تأییدشده پس از هزینه‌ها (غیرقطعی)',
                    c['provisional_margin_rial'] as int,
                    color: (c['provisional_margin_rial'] as int) >= 0
                        ? mint
                        : const Color(0xFFFFA9A1)),
                const SizedBox(height: 10),
                _stat('جریان نقدی: دریافت منهای پرداخت',
                    c['cash_flow_rial'] as int),
                const SizedBox(height: 10),
                const Text(
                    'توجه: مازاد اولیه، سود حسابداری قطعی نیست؛ صورت‌وضعیت تأییدشده ملاک این شاخص است.',
                    style: TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 25),
                _listOf('activities', 'عملیات و پیشرفت'),
                _listOf('expenses', 'هزینه‌ها'),
                _listOf('receipts', 'دریافت‌ها'),
                _listOf('statements', 'صورت‌وضعیت‌ها'),
                const SizedBox(height: 70),
              ]);
            }),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (context) => SafeArea(
                      child: ListView(
                    shrinkWrap: true,
                    children: [
                      const ListTile(
                          title: Text('ثبت جدید'),
                          subtitle: Text('نوع اطلاعات را انتخاب کنید')),
                      for (final item in const [
                        ('activities', 'عملیات', Icons.task_alt),
                        ('expenses', 'هزینه', Icons.receipt_long_outlined),
                        ('receipts', 'دریافت', Icons.south_west),
                        (
                          'statements',
                          'صورت‌وضعیت',
                          Icons.description_outlined
                        ),
                      ])
                        ListTile(
                            leading: Icon(item.$3, color: champagne),
                            title: Text(item.$2),
                            onTap: () {
                              Navigator.pop(context);
                              _add(item.$1);
                            }),
                    ],
                  ))),
          label: const Text('ثبت اطلاعات'),
          icon: const Icon(Icons.add),
        ),
      );
}

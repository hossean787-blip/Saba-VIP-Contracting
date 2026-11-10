import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/format.dart';
import '../data/offline_store.dart';
import '../finance/finance_kind.dart';
import '../finance/expense_payment.dart';
import '../finance/receipt_catalog.dart';
import '../widgets/ui.dart';
import '../widgets/expense_payment_status.dart';
import 'expense_payment_sheet.dart';
import 'contract_detail.dart';
import 'entry_sheet.dart';
import 'receivables_screen.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen(
      {super.key,
      required this.store,
      required this.company,
      required this.area,
      required this.onOpenContracts,
      required this.contractId});
  final OfflineStore store;
  final Map<String, Object?> company;
  final FinanceArea area;
  final int contractId;
  final VoidCallback onOpenContracts;
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  late FinanceKind selected;
  late Future<List<Map<String, Object?>>> future;
  int get companyId => widget.company['id'] as int;
  @override
  void initState() {
    super.initState();
    selected = widget.area.kinds.first;
    _load();
  }

  void _load() => future = widget.store
      .financialRecords(companyId, selected, contractId: widget.contractId);
  void _refresh() => setState(_load);

  /// No second contract picker: writes belong only to the active contract.
  Future<void> _add() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => EntrySheet(
        store: widget.store,
        contractId: widget.contractId,
        kind: selected.table,
      ),
    );
    if (saved == true && mounted) _refresh();
  }

  Future<void> _editRecord(Map<String, Object?> record) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => EntrySheet(
        store: widget.store,
        contractId: widget.contractId,
        kind: selected.table,
        previous: record,
      ),
    );
    if (saved == true && mounted) _refresh();
  }

  Future<void> _deleteRecord(Map<String, Object?> record) async {
    final isExpense = selected == FinanceKind.expenses;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف سند'),
        content: Text(isExpense
            ? 'هزینه و پرداخت‌هایی که فقط به این هزینه اختصاص دارند حذف می‌شوند. این عملیات قابل بازگشت نیست. از اطلاعات نسخه پشتیبان دارید؟'
            : 'این سند از قرارداد حذف می‌شود. اگر به تسویه دیگری وابسته باشد، حذف مجاز نیست. ادامه می‌دهید؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تأیید حذف')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await widget.store.deleteFinancialRecord(
          widget.contractId, record['id'] as int, selected);
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

  Color get tint =>
      widget.area == FinanceArea.outflows ? const Color(0xFFFFC0A4) : mint;
  String _entryTitle(Map<String, Object?> r) => switch (selected) {
        FinanceKind.expenses => r['category'].toString(),
        FinanceKind.payments =>
          (r['allocated_expenses'] ?? '').toString().isEmpty
              ? 'پرداخت مستقل قبلی'
              : 'پرداخت هزینه: ${r['allocated_expenses']}',
        FinanceKind.receipts =>
          receiptCategoryByCode((r['category_code'] ?? '').toString())?.name ??
              'دریافت قدیمی',
        FinanceKind.statements => 'صورت‌وضعیت ' + r['statement_no'].toString(),
      };
  String _status(Object? status) => switch (status) {
        'APPROVED' => 'تأییدشده',
        'DRAFT' => 'پیش‌نویس',
        'SUBMITTED' => 'ارسال‌شده',
        'REJECTED' => 'ردشده',
        _ => '',
      };
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, Object?>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('خطا در خواندن اطلاعات مالی'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final rows = snapshot.data!;
          // An unapproved statement is NOT recognised as approved work.
          // Summing a receipt and a statement would double-count cash.
          final total = selected == FinanceKind.statements
              ? rows.where((row) => row['status'] == 'APPROVED').fold<int>(
                  0,
                  (sum, row) =>
                      sum +
                      (row['gross_rial'] as int) +
                      ((row['vat_rial'] as int?) ?? 0) -
                      ((row['deductions_rial'] as int?) ?? 0))
              : rows.fold<int>(
                  0, (sum, row) => sum + (row[selected.amountField] as int));
          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
              children: [
                Text(widget.area.title,
                    style: const TextStyle(
                        color: ivory,
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('فقط اطلاعات قرارداد فعال',
                    style: TextStyle(color: muted)),
                const SizedBox(height: 15),
                VipCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Icon(
                            widget.area == FinanceArea.outflows
                                ? Icons.trending_down_rounded
                                : Icons.trending_up_rounded,
                            color: tint),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                selected == FinanceKind.statements
                                    ? 'خالص صورت‌وضعیت‌های تأییدشده'
                                    : selected == FinanceKind.receipts
                                        ? 'مجموع دریافت وجه (نقد و بانک)'
                                        : 'مجموع ' + selected.label,
                                style: const TextStyle(color: muted))),
                      ]),
                      const SizedBox(height: 14),
                      FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(tomanLabel(total),
                              style: TextStyle(
                                  color: tint,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800))),
                      const SizedBox(height: 7),
                      Text(rows.length.toString() + ' مورد ثبت‌شده',
                          style: const TextStyle(fontSize: 12, color: muted)),
                    ])),
                const SizedBox(height: 15),
                Wrap(spacing: 8, children: [
                  for (final kind in widget.area.kinds)
                    ChoiceChip(
                        label: Text(kind.label),
                        selected: selected == kind,
                        onSelected: (_) => setState(() {
                              selected = kind;
                              _load();
                            })),
                ]),
                const SizedBox(height: 10),
                Text(widget.area.note,
                    style: const TextStyle(
                        fontSize: 12, color: muted, height: 1.5)),
                const SizedBox(height: 17),
                if (widget.area == FinanceArea.inflows) ...[
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReceivablesScreen(
                            store: widget.store,
                            companyId: companyId,
                            contractId: widget.contractId,
                          ),
                        ),
                      );
                      if (mounted) _refresh();
                    },
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: const Text('مرکز مطالبات و تطبیق دریافت‌ها'),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text('ثبت ' + selected.singleLabel + ' جدید')),
                const SizedBox(height: 22),
                SectionHeading('فهرست ' + selected.label),
                const SizedBox(height: 13),
                if (rows.isEmpty)
                  const EmptyView(
                      title: 'اطلاعاتی ثبت نشده',
                      subtitle: 'برای قرارداد فعال هنوز موردی ثبت نشده است.',
                      icon: Icons.account_balance_wallet_outlined),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ContractDetailScreen(
                                    store: widget.store,
                                    company: widget.company,
                                    contractId: row['contract_id'] as int)));
                        if (mounted) _refresh();
                      },
                      child: VipCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Icon(
                                selected == FinanceKind.expenses
                                    ? Icons.receipt_long_outlined
                                    : selected == FinanceKind.payments
                                        ? Icons.north_east_rounded
                                        : selected == FinanceKind.receipts
                                            ? Icons.south_west_rounded
                                            : Icons.description_outlined,
                                color: tint,
                                size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(_entryTitle(row),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  if (selected == FinanceKind.expenses &&
                                      ((row['detail_title'] ?? '')
                                              .toString()
                                              .trim()
                                              .isNotEmpty ||
                                          (row['counterparty_name'] ?? '')
                                              .toString()
                                              .trim()
                                              .isNotEmpty)) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                        [
                                          if ((row['detail_title'] ?? '')
                                              .toString()
                                              .trim()
                                              .isNotEmpty)
                                            row['detail_title'].toString(),
                                          if ((row['counterparty_name'] ?? '')
                                              .toString()
                                              .trim()
                                              .isNotEmpty)
                                            'طرف حساب: ${row['counterparty_name']}',
                                        ].join(' • '),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: ivory, fontSize: 11)),
                                  ],
                                  if (selected == FinanceKind.expenses) ...[
                                    const SizedBox(height: 9),
                                    ExpensePaymentStatus(
                                        expenseRial: row['amount_rial'] as int,
                                        paidRial: (row['allocated_paid_rial']
                                                as int?) ??
                                            0,
                                        onPay: () => _payExpense(row)),
                                  ],
                                  if (selected == FinanceKind.receipts) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                        [
                                          if ((row['counterparty_name'] ?? '')
                                              .toString()
                                              .trim()
                                              .isNotEmpty)
                                            'پرداخت‌کننده: ${row['counterparty_name']}',
                                          if ((row['detail_title'] ?? '')
                                              .toString()
                                              .trim()
                                              .isNotEmpty)
                                            'تفصیلی: ${row['detail_title']}',
                                          if ((row['reference_no'] ?? '')
                                              .toString()
                                              .trim()
                                              .isNotEmpty)
                                            'پیگیری: ${row['reference_no']}',
                                          if (row['payment_method'] != null)
                                            ReceiptDetail.methods[
                                                    (row['payment_method'] ??
                                                            '')
                                                        .toString()] ??
                                                'روش نامشخص',
                                        ].join(' • '),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: ivory, fontSize: 11)),
                                  ],
                                  if (selected == FinanceKind.statements) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                        'ارزش افزوده: ${tomanLabel((row['vat_rial'] as int?) ?? 0)} • '
                                        'کسورات: ${tomanLabel((row['deductions_rial'] as int?) ?? 0)}',
                                        style: const TextStyle(
                                            color: muted, fontSize: 11)),
                                    Text(
                                        'خالص: ${tomanLabel((row['gross_rial'] as int) + ((row['vat_rial'] as int?) ?? 0) - ((row['deductions_rial'] as int?) ?? 0))}',
                                        style: const TextStyle(
                                            color: mint, fontSize: 11)),
                                  ],
                                  const SizedBox(height: 5),
                                  Text(
                                      row['contract_title'].toString() +
                                          ' • ' +
                                          jalaliLabel(row[selected.dateField]
                                              ?.toString()),
                                      style: const TextStyle(
                                          fontSize: 11, color: muted),
                                      maxLines: 2),
                                  if (selected == FinanceKind.statements)
                                    Text(_status(row['status']),
                                        style: const TextStyle(
                                            fontSize: 11, color: champagne)),
                                ])),
                            const SizedBox(width: 5),
                            FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                    tomanLabel(
                                        row[selected.amountField] as int),
                                    style: TextStyle(
                                        color: tint,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold))),
                            PopupMenuButton<String>(
                              tooltip: 'مدیریت سند',
                              icon: const Icon(Icons.more_vert, color: champagne),
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _editRecord(row);
                                } else if (action == 'delete') {
                                  _deleteRecord(row);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('ویرایش سند'),
                                  ]),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [
                                    Icon(Icons.delete_outline, size: 18),
                                    SizedBox(width: 8),
                                    Text('حذف سند'),
                                  ]),
                                ),
                              ],
                            ),
                          ])),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

import 'package:flutter/material.dart';
import '../core/format.dart';
import '../finance/expense_catalog.dart';
import '../finance/expense_payment.dart';
import '../finance/receipt_catalog.dart';
import '../core/theme.dart';
import '../data/offline_store.dart';
import '../widgets/date_field.dart';
import '../widgets/ui.dart';
import '../widgets/expense_payment_status.dart';

class EntrySheet extends StatefulWidget {
  const EntrySheet(
      {super.key,
      required this.store,
      required this.contractId,
      required this.kind,
      this.previous});
  final OfflineStore store;
  final int contractId;
  final String kind;
  final Map<String, Object?>? previous;
  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  final formKey = GlobalKey<FormState>();
  final partialKey = GlobalKey<FormFieldState<String>>();
  final title = TextEditingController();
  final amount = TextEditingController();
  final note = TextEditingController();
  final detail = TextEditingController();
  final counterparty = TextEditingController();
  final reference = TextEditingController();
  final partialPaid = TextEditingController();
  final vat = TextEditingController(text: '0');
  final deductions = TextEditingController(text: '0');
  ExpenseCategory? selectedExpense;
  ReceiptCategory? selectedReceipt;
  String paymentMethod = 'TRANSFER';
  bool registerExpensePayment = false;
  bool partialExpensePayment = false;
  int progress = 0;
  String statementStatus = 'DRAFT';
  late String date;
  bool saving = false;
  bool amountInRial = false;
  bool vatInRial = false;
  bool deductionsInRial = false;
  int existingPaidRial = 0;

  int? _parseMoney(String raw, {bool allowZero = false, bool rial = false}) {
    if (!rial) return tomanToRial(raw, allowZero: allowZero);
    final value = normalizeDigits(raw).replaceAll(RegExp(r'[,٬،\s]'), '');
    if (!RegExp(r'^\d+$').hasMatch(value)) return null;
    final integer = int.tryParse(value);
    if (integer == null || integer < 0 ||
        (!allowZero && integer == 0) ||
        integer > 9223372036854775807) return null;
    return integer;
  }

  String _oldMoney(Object? raw, {required bool rial}) {
    final value = (raw as int?) ?? 0;
    return (rial ? value : value ~/ 10).toString();
  }

  @override
  void initState() {
    super.initState();
    date = isoDay(DateTime.now());
    final previous = widget.previous;
    if (previous == null) return;
    note.text = (previous['memo'] ?? previous['description'] ?? previous['note'] ?? '').toString();
    switch (widget.kind) {
      case 'activities':
        title.text = (previous['title'] ?? '').toString();
        progress = (previous['progress_percent'] as int?) ?? 0;
        date = (previous['planned_date'] ?? date).toString();
        break;
      case 'expenses':
        selectedExpense = expenseCategoryByCode((previous['category_code'] ?? '').toString());
        if (selectedExpense == null) {
          for (final item in expenseCategories) {
            if (item.name == previous['category']) { selectedExpense = item; break; }
          }
        }
        detail.text = (previous['detail_title'] ?? '').toString();
        counterparty.text = (previous['counterparty_name'] ?? '').toString();
        existingPaidRial = (previous['allocated_paid_rial'] as int?) ?? 0;
        amountInRial = (previous['amount_rial'] as int) % 10 != 0;
        amount.text = _oldMoney(previous['amount_rial'], rial: amountInRial);
        date = (previous['expense_date'] ?? date).toString();
        break;
      case 'receipts':
        selectedReceipt = receiptCategoryByCode((previous['category_code'] ?? '').toString());
        detail.text = (previous['detail_title'] ?? '').toString();
        counterparty.text = (previous['counterparty_name'] ?? '').toString();
        reference.text = (previous['reference_no'] ?? '').toString();
        paymentMethod = (previous['payment_method'] ?? 'TRANSFER').toString();
        if (!ReceiptDetail.methods.containsKey(paymentMethod)) paymentMethod = 'TRANSFER';
        amountInRial = (previous['amount_rial'] as int) % 10 != 0;
        amount.text = _oldMoney(previous['amount_rial'], rial: amountInRial);
        date = (previous['receipt_date'] ?? date).toString();
        break;
      case 'statements':
        title.text = (previous['statement_no'] ?? '').toString();
        statementStatus = (previous['status'] ?? 'DRAFT').toString();
        amountInRial = (previous['gross_rial'] as int) % 10 != 0;
        vatInRial = ((previous['vat_rial'] as int?) ?? 0) % 10 != 0;
        deductionsInRial = ((previous['deductions_rial'] as int?) ?? 0) % 10 != 0;
        amount.text = _oldMoney(previous['gross_rial'], rial: amountInRial);
        vat.text = _oldMoney(previous['vat_rial'], rial: vatInRial);
        deductions.text = _oldMoney(previous['deductions_rial'], rial: deductionsInRial);
        date = (previous['statement_date'] ?? date).toString();
        break;
    }
  }

  @override
  void dispose() {
    for (final c in [
      title,
      amount,
      note,
      detail,
      counterparty,
      reference,
      partialPaid,
      vat,
      deductions
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String get caption => switch (widget.kind) {
        'activities' =>
          widget.previous == null ? 'ثبت عملیات' : 'ویرایش عملیات',
        'expenses' => 'ثبت هزینه',
        'payments' => 'ثبت پرداخت',
        'receipts' => 'ثبت دریافت وجه',
        'statements' => 'ثبت صورت‌وضعیت',
        _ => 'ثبت',
      };

  Future<void> _save() async {
    if (saving) return;
    if (!formKey.currentState!.validate()) return;
    final rial = widget.kind == 'activities'
        ? 0
        : tomanToRial(amount.text, allowZero: widget.kind == 'statements');
    if (widget.kind != 'activities' && rial == null) return;
    setState(() => saving = true);
    try {
      switch (widget.kind) {
        case 'activities':
          if (widget.previous == null) {
            await widget.store.addActivity(widget.contractId,
                title: title.text,
                percent: progress,
                date: date,
                note: note.text);
          } else {
            await widget.store.updateActivity(
                widget.contractId, widget.previous!['id'] as int,
                title: title.text,
                percent: progress,
                date: date,
                note: note.text);
          }
          break;
        case 'expenses':
          final mode = !registerExpensePayment
              ? ExpensePaymentMode.unpaid
              : partialExpensePayment
                  ? ExpensePaymentMode.partial
                  : ExpensePaymentMode.full;
          final paid = initialExpensePaymentRial(
              expenseRial: rial!,
              mode: mode,
              partialRial: partialExpensePayment
                  ? tomanToRial(partialPaid.text, allowZero: false)
                  : null);
          await widget.store.addExpenseWithPayment(widget.contractId,
              amountRial: rial,
              date: date,
              memo: note.text,
              paidRial: paid,
              expenseDetail: ExpenseDetail(
                categoryCode: selectedExpense!.code,
                detailTitle: detail.text,
                counterpartyName: counterparty.text,
              ));
          break;
        case 'payments':
          await widget.store.addMoney(widget.contractId,
              kind: widget.kind,
              amountRial: rial!,
              date: date,
              memo: note.text);
          break;
        case 'receipts':
          await widget.store.addMoney(widget.contractId,
              kind: widget.kind,
              amountRial: rial!,
              date: date,
              memo: note.text,
              receiptDetail: ReceiptDetail(
                categoryCode: selectedReceipt!.code,
                detailTitle: detail.text,
                payerName: counterparty.text,
                paymentMethod: paymentMethod,
                referenceNo: reference.text,
              ));
          break;
        case 'statements':
          await widget.store.addStatement(widget.contractId,
              number: title.text,
              date: date,
              grossRial: rial!,
              vatRial: tomanToRial(vat.text) ?? 0,
              deductionsRial: tomanToRial(deductions.text) ?? 0,
              status: statementStatus,
              description: note.text);
          break;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showFeedback(context, 'ذخیره انجام نشد: $e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget? _expensePreview() {
    final cost = tomanToRial(amount.text, allowZero: false);
    if (cost == null) return null;
    final mode = !registerExpensePayment
        ? ExpensePaymentMode.unpaid
        : partialExpensePayment
            ? ExpensePaymentMode.partial
            : ExpensePaymentMode.full;
    try {
      final paid = initialExpensePaymentRial(
          expenseRial: cost,
          mode: mode,
          partialRial: tomanToRial(partialPaid.text, allowZero: false));
      return ExpensePaymentStatus(expenseRial: cost, paidRial: paid);
    } on ArgumentError {
      // Invalid partial amounts must not display a misleading balance.
      return const Text('مبلغ جزئی باید مثبت و کمتر از هزینه باشد.',
          style: TextStyle(color: champagne));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Form(
                key: formKey,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(caption,
                          style: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      if (widget.kind == 'activities' ||
                          widget.kind == 'statements') ...[
                        TextFormField(
                            controller: title,
                            decoration: InputDecoration(
                                labelText: widget.kind == 'activities'
                                    ? 'عنوان عملیات *'
                                    : 'شماره صورت‌وضعیت *'),
                            validator: (x) => x == null || x.trim().isEmpty
                                ? 'این فیلد الزامی است'
                                : null),
                        const SizedBox(height: 12),
                      ],
                      if (widget.kind == 'expenses') ...[
                        const Text('۱. نوع هزینه را مشخص کنید',
                            style: TextStyle(
                                color: champagne, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                              selectedExpense?.code ?? 'category-empty'),
                          initialValue: selectedExpense?.code,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'سرفصل هزینه *',
                              prefixIcon: Icon(Icons.account_tree_outlined)),
                          items: [
                            for (final item in expenseCategories)
                              DropdownMenuItem(
                                  value: item.code,
                                  child: Text(item.name,
                                      overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (code) => setState(() {
                            selectedExpense = expenseCategoryByCode(code ?? '');
                            detail.clear();
                            counterparty.clear();
                          }),
                          validator: (value) =>
                              expenseCategoryByCode(value ?? '') == null
                                  ? 'ابتدا سرفصل هزینه را انتخاب کنید'
                                  : null,
                        ),
                        if (selectedExpense != null) ...[
                          const SizedBox(height: 16),
                          const Text('۲. تفصیلی هزینه را مشخص کنید',
                              style: TextStyle(
                                  color: champagne,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: detail,
                            textCapitalization: TextCapitalization.sentences,
                            maxLength: 250,
                            decoration: InputDecoration(
                              labelText: selectedExpense!.detailLabel,
                              hintText: selectedExpense!.hint,
                              prefixIcon:
                                  const Icon(Icons.description_outlined),
                            ),
                            validator: (value) {
                              final selection = selectedExpense!;
                              if (selection.detailRequired &&
                                  (value ?? '').trim().isEmpty) {
                                return 'ثبت این تفصیلی الزامی است';
                              }
                              if ((value ?? '').trim().isEmpty &&
                                  counterparty.text.trim().isEmpty) {
                                return 'تفصیلی یا طرف حساب باید مشخص باشد';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: counterparty,
                            maxLength: 250,
                            decoration: InputDecoration(
                              labelText: selectedExpense!.counterpartyLabel,
                              hintText: 'نام شخص، مالک، تأمین‌کننده یا شرکت',
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const VipCard(
                              child: Text(
                            'ابتدا هزینه شناسایی می‌شود؛ پرداخت اختیاری به همین هزینه متصل خواهد شد.',
                            style: TextStyle(
                                color: muted, fontSize: 12, height: 1.6),
                          )),
                        ],
                        const SizedBox(height: 16),
                      ],
                      if (widget.kind == 'receipts') ...[
                        const Text('۱. بابت چه موضوعی وجه دریافت شده است؟',
                            style: TextStyle(
                                color: champagne, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 11),
                        DropdownButtonFormField<String>(
                          key: ValueKey(selectedReceipt?.code ??
                              'receipt-category-empty'),
                          initialValue: selectedReceipt?.code,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'نوع دریافت *',
                              prefixIcon: Icon(Icons.category_outlined)),
                          items: [
                            for (final item in receiptCategories)
                              DropdownMenuItem(
                                value: item.code,
                                child: Text(item.name,
                                    overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (code) => setState(() {
                            selectedReceipt = receiptCategoryByCode(code ?? '');
                            detail.clear();
                          }),
                          validator: (value) =>
                              receiptCategoryByCode(value ?? '') == null
                                  ? 'نوع دریافت را انتخاب کنید'
                                  : null,
                        ),
                        if (selectedReceipt != null) ...[
                          const SizedBox(height: 15),
                          const Text('۲. تفصیلی و پرداخت‌کننده را مشخص کنید',
                              style: TextStyle(
                                  color: champagne,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: counterparty,
                            maxLength: 250,
                            decoration: const InputDecoration(
                                labelText: 'نام پرداخت‌کننده / کارفرما *',
                                hintText: 'مثلاً شهرداری اراک',
                                prefixIcon: Icon(Icons.person_outline)),
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? 'پرداخت‌کننده الزامی است'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: detail,
                            maxLength: 250,
                            decoration: InputDecoration(
                                labelText: selectedReceipt!.detailLabel,
                                hintText: selectedReceipt!.hint,
                                prefixIcon:
                                    const Icon(Icons.description_outlined)),
                            validator: (value) => selectedReceipt!
                                        .detailRequired &&
                                    (value ?? '').trim().isEmpty
                                ? 'شماره سند یا تفصیلی این دریافت الزامی است'
                                : null,
                          ),
                          const SizedBox(height: 11),
                          DropdownButtonFormField<String>(
                            initialValue: paymentMethod,
                            decoration: const InputDecoration(
                                labelText: 'روش دریافت وجه *',
                                prefixIcon:
                                    Icon(Icons.account_balance_outlined)),
                            items: [
                              for (final method
                                  in ReceiptDetail.methods.entries)
                                DropdownMenuItem(
                                    value: method.key,
                                    child: Text(method.value)),
                            ],
                            onChanged: (value) => setState(() {
                              paymentMethod = value ?? 'TRANSFER';
                            }),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: reference,
                            maxLength: 100,
                            decoration: const InputDecoration(
                                labelText:
                                    'شماره پیگیری / چک / حواله (اختیاری)',
                                prefixIcon: Icon(Icons.numbers_outlined)),
                          ),
                          const SizedBox(height: 7),
                          const VipCard(
                              child: Text(
                            'این بخش فقط دریافت واقعی وجه را ثبت می‌کند. صورت‌وضعیت، پیش‌پرداخت و استرداد وجه الزاماً درآمد قطعی نیستند. ثبت دریافت، صورت‌وضعیت را به‌طور خودکار تسویه نمی‌کند.',
                            style: TextStyle(
                                color: muted, fontSize: 12, height: 1.6),
                          )),
                        ],
                        const SizedBox(height: 16),
                      ],
                      if (widget.kind == 'activities') ...[
                        Text('پیشرفت عملیات: $progress٪'),
                        Slider(
                            value: progress.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 20,
                            label: '$progress%',
                            onChanged: (value) =>
                                setState(() => progress = value.round())),
                      ] else ...[
                        TextFormField(
                            controller: amount,
                            keyboardType: TextInputType.number,
                            onChanged: (_) {
                              setState(() {});
                              if (registerExpensePayment &&
                                  partialExpensePayment) {
                                partialKey.currentState?.validate();
                              }
                            },
                            decoration: InputDecoration(
                                labelText: widget.kind == 'statements'
                                    ? 'مبلغ ناخالص صورت‌وضعیت (تومان) *'
                                    : 'مبلغ (تومان) *'),
                            validator: (text) => tomanToRial(text ?? '',
                                        allowZero:
                                            widget.kind == 'statements') ==
                                    null
                                ? 'مبلغ صحیح وارد کنید'
                                : null),
                        const SizedBox(height: 12),
                      ],
                      if (widget.kind == 'expenses') ...[
                        const Text('۳. وضعیت پرداخت هزینه',
                            style: TextStyle(
                                color: champagne, fontWeight: FontWeight.w700)),
                        CheckboxListTile(
                            value: registerExpensePayment,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('ثبت پرداخت برای این هزینه'),
                            subtitle: const Text(
                                'بدون تیک، هزینه پرداخت‌نشده ثبت می‌شود.'),
                            onChanged: (checked) => setState(() =>
                                registerExpensePayment = checked ?? false)),
                        if (registerExpensePayment) ...[
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            ChoiceChip(
                                label: const Text('پرداخت کامل'),
                                selected: !partialExpensePayment,
                                onSelected: (value) {
                                  if (value)
                                    setState(
                                        () => partialExpensePayment = false);
                                }),
                            ChoiceChip(
                                label: const Text('پرداخت جزئی'),
                                selected: partialExpensePayment,
                                onSelected: (value) {
                                  if (value)
                                    setState(
                                        () => partialExpensePayment = true);
                                }),
                          ]),
                          if (partialExpensePayment) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                                key: partialKey,
                                controller: partialPaid,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                onChanged: (_) => setState(() {}),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'مبلغ پرداخت‌شده (تومان) *',
                                    prefixIcon: Icon(Icons.payments_outlined)),
                                validator: (value) {
                                  final paid = tomanToRial(value ?? '',
                                      allowZero: false);
                                  final cost = tomanToRial(amount.text,
                                      allowZero: false);
                                  if (paid == null)
                                    return 'مبلغ جزئی معتبر نیست';
                                  if (cost != null && paid >= cost) {
                                    return 'مبلغ جزئی باید کمتر از هزینه باشد؛ پرداخت کامل را انتخاب کنید';
                                  }
                                  return null;
                                }),
                          ],
                        ],
                        if (_expensePreview() case final preview?) ...[
                          const SizedBox(height: 12),
                          VipCard(child: preview),
                        ],
                        const SizedBox(height: 12),
                      ],
                      if (widget.kind == 'statements') ...[
                        TextFormField(
                          controller: vat,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'مالیات و ارزش افزوده (تومان)',
                              prefixIcon: Icon(Icons.add_circle_outline)),
                          validator: (text) => tomanToRial(text ?? '') == null
                              ? 'مبلغ ارزش افزوده معتبر نیست'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: deductions,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'جمع کسورات (تومان)',
                              prefixIcon: Icon(Icons.remove_circle_outline)),
                          validator: (text) {
                            final deduction = tomanToRial(text ?? '');
                            final gross = tomanToRial(amount.text);
                            final tax = tomanToRial(vat.text);
                            if (deduction == null)
                              return 'مبلغ کسورات معتبر نیست';
                            if (gross != null &&
                                tax != null &&
                                deduction > gross + tax) {
                              return 'کسورات بیشتر از ناخالص و ارزش افزوده است';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 9),
                        const Text(
                            'خالص قابل دریافت = ناخالص + ارزش افزوده − کسورات؛ فقط صورت‌وضعیت تأییدشده در شاخص کار تأییدشده لحاظ می‌شود.',
                            style: TextStyle(
                                color: muted, fontSize: 12, height: 1.6)),
                        const SizedBox(height: 12),
                      ],
                      if (widget.kind == 'statements') ...[
                        DropdownButtonFormField<String>(
                          initialValue: statementStatus,
                          decoration: const InputDecoration(
                              labelText: 'وضعیت صورت‌وضعیت'),
                          items: const [
                            DropdownMenuItem(
                                value: 'DRAFT', child: Text('پیش‌نویس')),
                            DropdownMenuItem(
                                value: 'SUBMITTED', child: Text('ارسال‌شده')),
                            DropdownMenuItem(
                                value: 'APPROVED', child: Text('تأییدشده')),
                            DropdownMenuItem(
                                value: 'REJECTED', child: Text('ردشده')),
                          ],
                          onChanged: (v) =>
                              setState(() => statementStatus = v ?? 'DRAFT'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      JalaliDateField(
                          label: 'تاریخ',
                          value: date,
                          onChanged: (v) {
                            if (v != null) setState(() => date = v);
                          }),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: note,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'توضیحات (اختیاری)')),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                          onPressed: saving ? null : _save,
                          icon: const Icon(Icons.check),
                          label: Text(saving ? 'در حال ذخیره...' : 'ذخیره')),
                      const SizedBox(height: 10),
                    ]))),
      ));
}

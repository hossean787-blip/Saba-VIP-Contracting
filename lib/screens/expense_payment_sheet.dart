import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/offline_store.dart';
import '../widgets/date_field.dart';
import '../widgets/ui.dart';

class ExpensePaymentSheet extends StatefulWidget {
  const ExpensePaymentSheet(
      {super.key,
      required this.store,
      required this.contractId,
      required this.expenseId,
      required this.remainingRial});
  final OfflineStore store;
  final int contractId, expenseId, remainingRial;
  @override
  State<ExpensePaymentSheet> createState() => _ExpensePaymentSheetState();
}

class _ExpensePaymentSheetState extends State<ExpensePaymentSheet> {
  final formKey = GlobalKey<FormState>();
  final amount = TextEditingController();
  final note = TextEditingController();
  late String date;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    date = isoDay(DateTime.now());
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    final rial = tomanToRial(amount.text, allowZero: false)!;
    setState(() => saving = true);
    try {
      await widget.store.addExpensePayment(widget.contractId, widget.expenseId,
          amountRial: rial, date: date, memo: note.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showFeedback(context, 'پرداخت ثبت نشد: $error', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
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
                      const Text('ثبت پرداخت هزینه',
                          style: TextStyle(
                              fontSize: 21, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      VipCard(
                          child: Text(
                              'مانده قابل پرداخت: ${tomanLabel(widget.remainingRial)}',
                              style: const TextStyle(
                                  color: champagne,
                                  fontWeight: FontWeight.w700))),
                      const SizedBox(height: 15),
                      TextFormField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'مبلغ پرداخت (تومان) *'),
                          validator: (value) {
                            final rial =
                                tomanToRial(value ?? '', allowZero: false);
                            if (rial == null) return 'مبلغ مثبت وارد کنید';
                            if (rial > widget.remainingRial)
                              return 'مبلغ بیشتر از مانده است';
                            return null;
                          }),
                      const SizedBox(height: 12),
                      JalaliDateField(
                          label: 'تاریخ پرداخت',
                          value: date,
                          onChanged: (value) {
                            if (value != null) setState(() => date = value);
                          }),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: note,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'توضیحات پرداخت (اختیاری)')),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                          onPressed: saving ? null : save,
                          icon: const Icon(Icons.check),
                          label:
                              Text(saving ? 'در حال ذخیره...' : 'ثبت پرداخت')),
                    ]))),
      ));
}

import 'package:flutter/material.dart';
import '../core/format.dart';
import '../data/offline_store.dart';
import '../widgets/date_field.dart';
import '../widgets/ui.dart';

class EntrySheet extends StatefulWidget {
  const EntrySheet({super.key, required this.store, required this.contractId, required this.kind});
  final OfflineStore store;
  final int contractId;
  final String kind;
  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final amount = TextEditingController();
  final note = TextEditingController();
  final category = TextEditingController();
  int progress = 0;
  String statementStatus = 'DRAFT';
  late String date;
  bool saving = false;
  @override
  void initState() { super.initState(); date = isoDay(DateTime.now()); }
  @override
  void dispose() { for (final c in [title, amount, note, category]) { c.dispose(); } super.dispose(); }

  String get caption => switch(widget.kind) {
    'activities' => 'ثبت عملیات',
    'expenses' => 'ثبت هزینه',
    'payments' => 'ثبت پرداخت',
    'receipts' => 'ثبت دریافت',
    'statements' => 'ثبت صورت‌وضعیت',
    _ => 'ثبت',
  };

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    final rial = widget.kind == 'activities' ? 0 : tomanToRial(amount.text, allowZero: widget.kind == 'statements');
    if (widget.kind != 'activities' && rial == null) return;
    setState(() => saving = true);
    try {
      switch(widget.kind) {
        case 'activities':
          await widget.store.addActivity(widget.contractId, title: title.text, percent: progress, date: date, note: note.text);
          break;
        case 'expenses':
        case 'payments':
        case 'receipts':
          await widget.store.addMoney(widget.contractId, kind: widget.kind, amountRial: rial!, date: date,
            category: widget.kind == 'expenses' ? category.text : null, memo: note.text);
          break;
        case 'statements':
          await widget.store.addStatement(widget.contractId, number: title.text, date: date,
            grossRial: rial!, status: statementStatus, description: note.text);
          break;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showFeedback(context, 'ذخیره انجام نشد: $e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: Form(key: formKey, child: Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(caption, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
      if (widget.kind == 'activities' || widget.kind == 'statements') ...[
        TextFormField(controller: title, decoration: InputDecoration(labelText: widget.kind == 'activities' ? 'عنوان عملیات *' : 'شماره صورت‌وضعیت *'),
          validator: (x) => x == null || x.trim().isEmpty ? 'این فیلد الزامی است' : null),
        const SizedBox(height: 12),
      ],
      if (widget.kind == 'expenses') ...[
        TextFormField(controller: category, decoration: const InputDecoration(labelText: 'نوع هزینه (مثلاً تجهیزات) *'),
          validator: (x) => x == null || x.trim().isEmpty ? 'نوع هزینه الزامی است' : null),
        const SizedBox(height: 12),
      ],
      if (widget.kind == 'activities') ...[
        Text('پیشرفت عملیات: $progress٪'),
        Slider(value: progress.toDouble(), min: 0, max: 100, divisions: 20, label: '$progress%',
          onChanged: (value) => setState(() => progress = value.round())),
      ] else ...[
        TextFormField(controller: amount, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: widget.kind == 'statements' ? 'مبلغ ناخالص صورت‌وضعیت (تومان) *' : 'مبلغ (تومان) *'),
          validator: (text) => tomanToRial(text ?? '', allowZero: widget.kind == 'statements') == null ? 'مبلغ صحیح وارد کنید' : null),
        const SizedBox(height: 12),
      ],
      if (widget.kind == 'statements') ...[
        DropdownButtonFormField<String>(
          initialValue: statementStatus,
          decoration: const InputDecoration(labelText: 'وضعیت صورت‌وضعیت'),
          items: const [
            DropdownMenuItem(value: 'DRAFT', child: Text('پیش‌نویس')),
            DropdownMenuItem(value: 'SUBMITTED', child: Text('ارسال‌شده')),
            DropdownMenuItem(value: 'APPROVED', child: Text('تأییدشده')),
            DropdownMenuItem(value: 'REJECTED', child: Text('ردشده')),
          ],
          onChanged: (v) => setState(() => statementStatus = v ?? 'DRAFT'),
        ),
        const SizedBox(height: 12),
      ],
      JalaliDateField(label: 'تاریخ', value: date, onChanged: (v) { if (v != null) setState(() => date = v); }),
      const SizedBox(height: 12),
      TextFormField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)')),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: saving ? null : _save, icon: const Icon(Icons.check), label: Text(saving ? 'در حال ذخیره...' : 'ذخیره')), const SizedBox(height: 10),
    ]))),
  ));
}

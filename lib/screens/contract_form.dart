import 'package:flutter/material.dart';
import '../core/format.dart';
import '../data/offline_store.dart';
import '../widgets/date_field.dart';
import '../widgets/ui.dart';

class ContractFormScreen extends StatefulWidget {
  const ContractFormScreen(
      {super.key,
      required this.store,
      required this.company,
      required this.onSaved,
      this.previous});
  final OfflineStore store;
  final Map<String, Object?> company;
  final Map<String, Object?>? previous;
  final VoidCallback onSaved;
  @override
  State<ContractFormScreen> createState() => _ContractFormScreenState();
}

class _ContractFormScreenState extends State<ContractFormScreen> {
  final formKey = GlobalKey<FormState>();
  final number = TextEditingController();
  final title = TextEditingController();
  final employer = TextEditingController();
  final contractor = TextEditingController();
  final amount = TextEditingController(text: '0');
  final location = TextEditingController();
  final description = TextEditingController();
  late String startDate;
  String? endDate;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final row = widget.previous;
    startDate = row?['start_date'] as String? ?? isoDay(DateTime.now());
    endDate = row?['end_date'] as String?;
    number.text = row?['contract_no']?.toString() ?? '';
    title.text = row?['title']?.toString() ?? '';
    employer.text = row?['employer_name']?.toString() ?? '';
    contractor.text = row?['contractor_name']?.toString() ??
        widget.company['name'].toString();
    amount.text =
        row == null ? '' : ((row['amount_rial'] as int) ~/ 10).toString();
    location.text = row?['location']?.toString() ?? '';
    description.text = row?['scope_of_work']?.toString() ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      number,
      title,
      employer,
      contractor,
      amount,
      location,
      description
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    final value = tomanToRial(amount.text);
    if (value == null) return;
    if (endDate != null && endDate!.compareTo(startDate) < 0) {
      showFeedback(context, 'تاریخ پایان نباید پیش از تاریخ شروع باشد.',
          error: true);
      return;
    }
    setState(() => saving = true);
    try {
      await widget.store.saveContract(
          widget.company['id'] as int,
          ContractDraft(
              number: number.text,
              title: title.text,
              employer: employer.text,
              contractor: contractor.text,
              amountRial: value,
              startDate: startDate,
              endDate: endDate,
              location: location.text,
              description: description.text),
          editId: widget.previous?['id'] as int?);
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted)
        showFeedback(context, 'ثبت قرارداد انجام نشد: $e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(
                widget.previous == null ? 'قرارداد جدید' : 'ویرایش قرارداد')),
        body: SafeArea(
            child: Form(
                key: formKey,
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  const SectionHeading('اطلاعات اصلی قرارداد'),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: number,
                      decoration:
                          const InputDecoration(labelText: 'شماره قرارداد *'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'شماره قرارداد الزامی است'
                          : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: title,
                      decoration:
                          const InputDecoration(labelText: 'عنوان قرارداد *'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'عنوان قرارداد الزامی است'
                          : null),
                  const SizedBox(height: 20),
                  const SectionHeading('طرفین قرارداد'),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: employer,
                      decoration: const InputDecoration(labelText: 'کارفرما *'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'نام کارفرما الزامی است'
                          : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: contractor,
                      decoration:
                          const InputDecoration(labelText: 'پیمانکار *'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'نام پیمانکار الزامی است'
                          : null),
                  const SizedBox(height: 20),
                  const SectionHeading('مبلغ و بازه زمانی'),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'مبلغ قرارداد (تومان) *'),
                      validator: (v) => tomanToRial(v ?? '') == null
                          ? 'مبلغ معتبر وارد کنید'
                          : null),
                  const SizedBox(height: 12),
                  JalaliDateField(
                      label: 'تاریخ شروع',
                      value: startDate,
                      onChanged: (v) {
                        if (v != null) setState(() => startDate = v);
                      }),
                  const SizedBox(height: 12),
                  JalaliDateField(
                      label: 'تاریخ پایان (اختیاری)',
                      value: endDate,
                      onChanged: (v) => setState(() => endDate = v),
                      optional: true),
                  if (endDate != null)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                            onPressed: () => setState(() => endDate = null),
                            icon: const Icon(Icons.close),
                            label: const Text('حذف تاریخ پایان'))),
                  const SizedBox(height: 20),
                  const SectionHeading('اطلاعات تکمیلی'),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: location,
                      decoration:
                          const InputDecoration(labelText: 'محل اجرای پروژه')),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: description,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'موضوع و شرح خدمات')),
                  const SizedBox(height: 30),
                  FilledButton.icon(
                      onPressed: saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(saving ? 'در حال ذخیره...' : 'ثبت قرارداد')),
                  const SizedBox(height: 20),
                ]))),
      );
}

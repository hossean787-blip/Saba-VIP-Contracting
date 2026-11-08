import 'package:flutter/material.dart';
import '../data/offline_store.dart';
import '../widgets/ui.dart';
import '../core/theme.dart';

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key, required this.store, required this.onSaved});
  final OfflineStore store;
  final VoidCallback onSaved;
  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  final keyForm = GlobalKey<FormState>();
  final name = TextEditingController();
  final national = TextEditingController();
  final registration = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final row = await widget.store.company();
    if (row == null || !mounted) return;
    name.text = '${row['name']}';
    national.text = '${row['national_id'] ?? ''}';
    registration.text = '${row['registration_no'] ?? ''}';
    phone.text = '${row['phone'] ?? ''}';
    address.text = '${row['address'] ?? ''}';
  }

  @override
  void dispose() {
    for (final c in [name, national, registration, phone, address]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!keyForm.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await widget.store.saveCompany(name: name.text, nationalId: national.text,
        registration: registration.text, phone: phone.text, address: address.text);
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) showFeedback(context, 'ذخیره اطلاعات انجام نشد: $e', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مشخصات رسمی شرکت')),
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Form(
      key: keyForm, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const VipCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.apartment_rounded, color: champagne, size: 36), SizedBox(height: 12),
          Text('به مدیریت پیمانکاری خوش آمدید', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 8), Text('اطلاعات شرکت فقط روی همین گوشی ذخیره می‌شود.', style: TextStyle(color: muted)),
        ])),
        const SizedBox(height: 24),
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'نام شرکت *'),
          validator: (s) => s == null || s.trim().isEmpty ? 'نام شرکت الزامی است' : null),
        const SizedBox(height: 12),
        TextFormField(controller: national, decoration: const InputDecoration(labelText: 'شناسه ملی (اختیاری)'), keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        TextFormField(controller: registration, decoration: const InputDecoration(labelText: 'شماره ثبت (اختیاری)')),
        const SizedBox(height: 12),
        TextFormField(controller: phone, decoration: const InputDecoration(labelText: 'شماره تماس'), keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        TextFormField(controller: address, decoration: const InputDecoration(labelText: 'نشانی'), maxLines: 2),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: saving ? null : _save, icon: const Icon(Icons.check_circle_outline),
          label: Text(saving ? 'در حال ثبت...' : 'ذخیره و ورود به داشبورد')),
      ]),
    ))),
  );
}

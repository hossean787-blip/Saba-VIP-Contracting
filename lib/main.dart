import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'core/theme.dart';
import 'data/offline_store.dart';
import 'screens/company_screen.dart';
import 'screens/contract_form.dart';
import 'screens/contracts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/report_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = await OfflineStore.open();
    runApp(SabaContractingApp(store: store));
  } catch (error) {
    runApp(MaterialApp(home: Scaffold(body: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text('بازکردن پایگاه داده ممکن نشد. برای حفظ اطلاعات، برنامه بانک اطلاعات را بازنشانی نمی‌کند.\n$error', textDirection: TextDirection.rtl),
    ))))));
  }
}

class SabaContractingApp extends StatelessWidget {
  const SabaContractingApp({super.key, required this.store});
  final OfflineStore store;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'پیمانکاری صبا VIP',
    debugShowCheckedModeBanner: false,
    theme: vipTheme(),
    locale: const Locale('fa', 'IR'),
    supportedLocales: const [Locale('fa', 'IR'), Locale('en', 'US')],
    localizationsDelegates: const [
      PersianMaterialLocalizations.delegate,
      PersianCupertinoLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    home: AppShell(store: store),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final OfflineStore store;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int tab = 0;
  int revision = 0;
  Map<String, Object?>? company;
  bool loading = true;
  @override
  void initState() { super.initState(); _reloadCompany(); }
  Future<void> _reloadCompany() async {
    final c = await widget.store.company();
    if (mounted) setState(() { company = c; loading = false; });
  }
  Future<void> _newContract() async {
    final c = company;
    if (c == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ContractFormScreen(
      store: widget.store, company: c, onSaved: () => Navigator.pop(context),
    )));
    if (mounted) setState(() { tab = 1; revision++; });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (company == null) return CompanyScreen(store: widget.store, onSaved: _reloadCompany);
    final c = company!;
    return Scaffold(
      appBar: AppBar(title: const Text('پیمانکاری صبا', style: TextStyle(fontWeight: FontWeight.w800)), actions: [
        IconButton(tooltip: 'اطلاعات شرکت', icon: const Icon(Icons.business_outlined), onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => CompanyScreen(store: widget.store, onSaved: () => Navigator.pop(context))));
          await _reloadCompany();
        }),
      ]),
      body: switch (tab) {
        0 => DashboardScreen(key: ValueKey('dashboard-$revision'),
          store: widget.store, company: c,
          onOpenContracts: () => setState(() => tab = 1), onNewContract: _newContract),
        1 => ContractsScreen(key: ValueKey('contracts-$revision'),
          store: widget.store, company: c, onNewContract: _newContract),
        _ => ReportsScreen(key: ValueKey('reports-$revision'), store: widget.store, company: c),
      },
      floatingActionButton: tab == 2 ? null : FloatingActionButton(
        tooltip: 'قرارداد جدید', onPressed: _newContract, child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'خانه'),
          NavigationDestination(icon: Icon(Icons.folder_copy_outlined), selectedIcon: Icon(Icons.folder_copy), label: 'قراردادها'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'گزارش‌ها'),
        ],
      ),
    );
  }
}

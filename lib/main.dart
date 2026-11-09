import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'data/offline_store.dart';
import 'data/active_contract.dart';
import 'screens/company_screen.dart';
import 'screens/contract_form.dart';
import 'screens/contracts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/report_screen.dart';
import 'screens/operations_screen.dart';
import 'screens/backup_screen.dart';
import 'screens/finance_screen.dart';
import 'finance/finance_kind.dart';
import 'widgets/ui.dart';

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
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  int tab = 0;
  int revision = 0;
  int? selectedContractId;
  List<Map<String, Object?>> contracts = const [];
  Map<String, Object?>? company;
  bool loading = true;
  bool changingContract = false;

  String _selectionKey(int companyId) =>
      'saba_vip.active_contract.$companyId';

  @override
  void initState() {
    super.initState();
    _reloadContext();
  }

  Future<void> _reloadContext({bool afterRestore = false}) async {
    try {
      final latest = await widget.store.company();
      List<Map<String, Object?>> fresh = [];
      int? active;
      if (latest != null) {
        final id = latest['id'] as int;
        fresh = await widget.store.contracts(id);
        final key = _selectionKey(id);
        if (afterRestore) await _preferences.remove(key);
        int? saved;
        try {
          saved = await _preferences.getInt(key);
        } catch (_) {
          // Invalid preference never blocks access to the real database.
        }
        active = ActiveContract.resolve(fresh, saved);
        if (active != null && active != saved) {
          try {
            await _preferences.setInt(key, active);
          } catch (_) {
            // Current selection works even if preferences are unavailable.
          }
        }
      }
      if (!mounted) return;
      setState(() {
        company = latest;
        contracts = fresh;
        selectedContractId = active;
        loading = false;
        revision++;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      showFeedback(context, 'بارگذاری قراردادها انجام نشد: $error', error: true);
    }
  }

  Future<void> _selectContract(int? id) async {
    if (id == null || changingContract || company == null) return;
    if (ActiveContract.find(contracts, id) == null ||
        id == selectedContractId) return;
    setState(() => changingContract = true);
    try {
      await _preferences.setInt(
        _selectionKey(company!['id'] as int), id);
      if (!mounted) return;
      setState(() {
        selectedContractId = id;
        revision++;
      });
    } catch (_) {
      if (mounted) {
        showFeedback(context, 'ذخیره انتخاب قرارداد انجام نشد.', error: true);
      }
    } finally {
      if (mounted) setState(() => changingContract = false);
    }
  }

  Future<void> _newContract() async {
    final c = company;
    if (c == null) return;
    final existingIds = contracts.map((row) => row['id']).toSet();
    await Navigator.push(context, MaterialPageRoute(builder: (_) =>
        ContractFormScreen(
          store: widget.store, company: c,
          onSaved: () => Navigator.pop(context),
        )));
    if (!mounted) return;
    await _reloadContext();
    if (!mounted) return;
    final created = contracts.where(
      (row) => !existingIds.contains(row['id']));
    if (created.isNotEmpty) {
      await _selectContract(created.first['id'] as int);
      if (mounted) setState(() => tab = 0);
    }
  }

  void _changeTab(int value) {
    if (tab == value) return;
    setState(() => tab = value);
    _reloadContext();
  }

  Future<void> _openOperations() async {
    final c = company;
    final id = selectedContractId;
    if (c == null || id == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('عملیات قرارداد فعال')),
      body: OperationsScreen(
        store: widget.store, company: c, contractId: id),
    )));
    if (mounted) setState(() => revision++);
  }

  Widget _noContract(String area) => Center(child: Padding(
    padding: const EdgeInsets.all(20),
    child: EmptyView(
      title: 'قراردادی انتخاب نشده',
      subtitle: 'برای بخش $area از خانه قرارداد فعال را مشخص کنید یا با + در بخش قراردادها، قرارداد جدید بسازید.',
      icon: Icons.folder_open_outlined,
    ),
  ));

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (company == null) {
      return CompanyScreen(store: widget.store, onSaved: _reloadContext);
    }
    final c = company!;
    final id = selectedContractId;
    final active = ActiveContract.find(contracts, id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('پیمانکاری صبا',
          style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: 'پشتیبان‌گیری و بازیابی',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () async {
              final restored = await Navigator.push<bool>(
                context, MaterialPageRoute(builder: (_) =>
                  BackupScreen(store: widget.store)));
              if (restored == true) {
                await _reloadContext(afterRestore: true);
                if (mounted) setState(() => tab = 0);
              }
            }),
          IconButton(tooltip: 'اطلاعات شرکت',
            icon: const Icon(Icons.business_outlined),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) =>
                CompanyScreen(store: widget.store,
                  onSaved: () => Navigator.pop(context))));
              await _reloadContext();
            }),
        ],
      ),
      body: switch (tab) {
        0 => DashboardScreen(
          key: ValueKey('dashboard-$revision-$id'),
          store: widget.store, company: c,
          contracts: contracts, selectedContractId: id,
          onSelectContract: _selectContract,
          onOpenContracts: () => _changeTab(1),
          onNewContract: _newContract,
          onOpenOperations: _openOperations,
        ),
        1 => ContractsScreen(
          key: ValueKey('contracts-$revision'),
          store: widget.store, company: c,
          onNewContract: _newContract,
        ),
        2 => active == null ? _noContract('هزینه‌ها') : FinanceScreen(
          key: ValueKey('expenses-$revision-$id'),
          store: widget.store, company: c,
          contractId: id!, area: FinanceArea.outflows,
          onOpenContracts: () => _changeTab(1),
        ),
        3 => active == null ? _noContract('درآمدها') : FinanceScreen(
          key: ValueKey('incomes-$revision-$id'),
          store: widget.store, company: c,
          contractId: id!, area: FinanceArea.inflows,
          onOpenContracts: () => _changeTab(1),
        ),
        _ => active == null ? _noContract('گزارش‌ها') : ReportsScreen(
          key: ValueKey('reports-$revision-$id'),
          store: widget.store, company: c, contractId: id!,
        ),
      },
      // endFloat follows RTL, placing + at physical bottom-left ABOVE navigation.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: tab == 1
        ? FloatingActionButton(
            tooltip: 'افزودن قرارداد',
            onPressed: _newContract,
            child: const Icon(Icons.add))
        : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: _changeTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard), label: 'خانه'),
          NavigationDestination(
            icon: Icon(Icons.folder_copy_outlined),
            selectedIcon: Icon(Icons.folder_copy), label: 'قراردادها'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long), label: 'هزینه‌ها'),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up_rounded), label: 'درآمدها'),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics), label: 'گزارش‌ها'),
        ],
      ),
    );
  }
}

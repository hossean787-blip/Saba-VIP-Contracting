import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../reports/report_model.dart';
import '../finance/finance_kind.dart';
import '../finance/expense_catalog.dart';
import '../finance/receipt_catalog.dart';
import 'receipt_migration.dart';
import 'expense_migration.dart';

class ContractDraft {
  const ContractDraft({
    required this.number, required this.title, required this.employer,
    required this.contractor, required this.startDate, this.endDate,
    required this.amountRial, this.location = '', this.description = '',
  });
  final String number;
  final String title;
  final String employer;
  final String contractor;
  final String startDate;
  final String? endDate;
  final int amountRial;
  final String location;
  final String description;
}

class OfflineStore {
  OfflineStore._(this.db, this.databasePath);
  Database db;
  final String databasePath;
  bool _maintenance = false;
  static const databaseVersion = 3;

  static Future<OfflineStore> open() async {
    final folder = await getDatabasesPath();
    await Directory(folder).create(recursive: true);
    final dbPath = p.join(folder, 'saba_contracting_v1.sqlite');
    if (!await databaseExists(dbPath)) {
      final data = await rootBundle.load('assets/db/seed.sqlite');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      // Never overwrite an existing user database on application upgrade.
      await File(dbPath).writeAsBytes(bytes, flush: true);
    }
    final database = await _openValidated(dbPath);
    return OfflineStore._(database, dbPath);
  }

  /// Only called from the maintenance screen; no UI writes run concurrently.
  /// Closing the connection checkpoints WAL so the single database file is consistent.
  Future<Uint8List> snapshotDatabase() async {
    if (_maintenance) throw StateError('عملیات نگهداری دیگری در حال اجرا است.');
    _maintenance = true;
    try {
      await db.close();
      try {
        final bytes = await File(databasePath).readAsBytes();
        return Uint8List.fromList(bytes);
      } finally {
        db = await _openValidated(databasePath);
      }
    } finally {
      _maintenance = false;
    }
  }

  static Future<Database> _openValidated(String path) async {
    final database = await openDatabase(
      path,
      version: databaseVersion,
      onUpgrade: (db, oldVersion, newVersion) async {
        await upgradeExpenseDatabase(db, oldVersion, newVersion);
        await upgradeReceiptDatabase(db, oldVersion, newVersion);
      },
      onConfigure: (d) async => d.execute('PRAGMA foreign_keys=ON'),
    );
    try {
      await _checkDatabase(database);
    } catch (_) {
      await database.close();
      rethrow;
    }
    return database;
  }

  static Future<void> _checkDatabase(Database candidate) async {
    final version = await candidate.rawQuery('PRAGMA user_version');
    final actual = version.first['user_version'] as int?;
    if (actual == null || actual < 1 || actual > databaseVersion) {
      throw StateError('نسخه پایگاه داده ناسازگار است.');
    }
    final check = await candidate.rawQuery('PRAGMA quick_check');
    if (check.first.values.first != 'ok') throw StateError('پایگاه داده آسیب دیده است.');
    final foreign = await candidate.rawQuery('PRAGMA foreign_key_check');
    if (foreign.isNotEmpty) throw StateError('روابط اطلاعاتی پایگاه داده ناسالم است.');
    final names = await candidate.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final tables = names.map((r) => r['name']).toSet();
    if (!tables.containsAll({'companies','contracts','parties','activities','expenses','payments','receipts','statements'})) {
      throw StateError('ساختار نسخه پشتیبان ناقص است.');
    }
    if (actual >= 2) {
      final columns = await candidate.rawQuery('PRAGMA table_info(expenses)');
      final expenseColumns = columns.map((r) => r['name']).toSet();
      if (!expenseColumns.containsAll({'category_code','detail_title','counterparty_name'})) {
        throw StateError('ساختار هزینه‌های تفصیلی ناقص است.');
      }
    }
  }

    if (actual >= 3) {
      final columns = await candidate.rawQuery('PRAGMA table_info(receipts)');
      final fields = columns.map((row) => row['name']).toSet();
      if (!fields.containsAll({
        'category_code','detail_title','counterparty_name','reference_no',
        'payment_method',
      })) {
        throw StateError('ساختار تفصیلی دریافت‌های نسخه جدید ناقص است.');
      }
    }

  /// Verify a decrypted candidate before making any changes. Preserve rollback
  /// copy if swap fails. No RESET/CREATE is used on original user data.
  Future<void> restoreDatabase(Uint8List sqlite) async {
    if (_maintenance) throw StateError('عملیات نگهداری دیگری در حال اجرا است.');
    _maintenance = true;
    final pending = File('$databasePath.pending-restore');
    final rollback = File('$databasePath.pre-restore');
    var originalMoved = false;
    var candidateInstalled = false;
    try {
      if (await pending.exists()) await pending.delete();
      await pending.writeAsBytes(sqlite, flush: true);
      final candidate = await openDatabase(pending.path, readOnly: true, singleInstance: false);
      try {
        await _checkDatabase(candidate);
      } finally {
        await candidate.close();
      }
      if (await rollback.exists()) {
        // Never silently destroy an earlier rollback copy.
        throw StateError('نسخه بازگشت قبلی موجود است؛ قبل از بازیابی دوباره باید مدیریت شود.');
      }
      await db.close();
      try {
        await File(databasePath).rename(rollback.path);
        originalMoved = true;
        await pending.rename(databasePath);
        candidateInstalled = true;
        db = await _openValidated(databasePath);
      } catch (_) {
        if (candidateInstalled && await File(databasePath).exists()) {
          await File(databasePath).delete();
        }
        if (originalMoved) await rollback.rename(databasePath);
        db = await _openValidated(databasePath);
        rethrow;
      }
      // Original is retained as .pre-restore to allow emergency recovery.
    } finally {
      if (await pending.exists()) await pending.delete();
      _maintenance = false;
    }
  }

  Future<Map<String, Object?>?> company() async {
    final rows = await db.query('companies', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> saveCompany({required String name, String nationalId = '', String registration = '', String phone = '', String address = ''}) async {
    if (name.trim().isEmpty) throw ArgumentError('نام شرکت الزامی است');
    final current = await company();
    final values = <String, Object?>{
      'name': name.trim(), 'national_id': nationalId.trim(),
      'registration_no': registration.trim(), 'phone': phone.trim(), 'address': address.trim(),
    };
    if (current == null) return db.insert('companies', values);
    final id = current['id'] as int;
    await db.update('companies', values, where: 'id=?', whereArgs: [id]);
    return id;
  }

  Future<int> _findOrCreateParty(Transaction txn, int companyId, String name) async {
    final fullName = name.trim();
    if (fullName.isEmpty) throw ArgumentError('نام طرف قرارداد الزامی است');
    final same = await txn.query('parties', columns: ['id'], where: 'company_id=? AND full_name=?', whereArgs: [companyId, fullName], limit: 1);
    if (same.isNotEmpty) return same.first['id'] as int;
    return txn.insert('parties', {'company_id': companyId, 'full_name': fullName, 'type': 'COMPANY'});
  }

  Future<int> saveContract(int companyId, ContractDraft value, {int? editId}) async {
    if (value.number.trim().isEmpty || value.title.trim().isEmpty) throw ArgumentError('شماره و عنوان قرارداد الزامی است');
    if (value.amountRial < 0) throw ArgumentError('مبلغ قرارداد معتبر نیست');
    if (value.endDate != null && value.endDate!.compareTo(value.startDate) < 0) throw ArgumentError('تاریخ پایان قبل از شروع است');
    return db.transaction((txn) async {
      final employerId = await _findOrCreateParty(txn, companyId, value.employer);
      final contractorId = await _findOrCreateParty(txn, companyId, value.contractor);
      final data = <String, Object?>{
        'company_id': companyId, 'contract_no': value.number.trim(), 'title': value.title.trim(),
        'employer_party_id': employerId, 'contractor_party_id': contractorId,
        'start_date': value.startDate, 'end_date': value.endDate,
        'amount_rial': value.amountRial, 'location': value.location.trim(),
        'scope_of_work': value.description.trim(),
      };
      if (editId == null) return txn.insert('contracts', data);
      final affected = await txn.update('contracts', data, where: 'id=? AND company_id=?', whereArgs: [editId, companyId]);
      if (affected != 1) throw StateError('قرارداد موردنظر پیدا نشد');
      return editId;
    });
  }

  Future<List<Map<String, Object?>>> contracts(int companyId, {String query = ''}) async {
    final search = query.trim();
    return db.rawQuery('''
      SELECT c.*, e.full_name AS employer_name, k.full_name AS contractor_name,
        f.cost_rial, f.paid_rial, f.received_rial, f.approved_work_rial, f.provisional_margin_rial
      FROM contracts c
      JOIN parties e ON e.id = c.employer_party_id
      JOIN parties k ON k.id = c.contractor_party_id
      JOIN v_contract_financial_summary f ON f.contract_id = c.id
      WHERE c.company_id=? AND (?='' OR c.title LIKE ? OR c.contract_no LIKE ? OR e.full_name LIKE ?)
      ORDER BY c.id DESC
    ''', [companyId, search, '%$search%', '%$search%', '%$search%']);
  }

  Future<Map<String, Object?>?> contract(int id) async {
    final rows = await db.rawQuery('''
      SELECT c.*, e.full_name employer_name, k.full_name contractor_name,
        f.cost_rial, f.paid_rial, f.received_rial, f.approved_work_rial,
        f.approved_net_payable_rial, f.provisional_margin_rial, f.cash_flow_rial
      FROM contracts c
      JOIN parties e ON e.id=c.employer_party_id
      JOIN parties k ON k.id=c.contractor_party_id
      JOIN v_contract_financial_summary f ON f.contract_id=c.id
      WHERE c.id=? LIMIT 1
    ''', [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, int>> dashboard(int companyId) async {
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS total,
        COALESCE(SUM(CASE WHEN c.status='ACTIVE' THEN 1 ELSE 0 END),0) AS active,
        COALESCE(SUM(CASE WHEN c.status='ACTIVE' THEN c.amount_rial ELSE 0 END),0) AS contracts_value,
        COALESCE(SUM(f.cost_rial),0) AS costs,
        COALESCE(SUM(f.received_rial),0) AS receipts,
        COALESCE(SUM(f.paid_rial),0) AS payments,
        COALESCE(SUM(f.approved_work_rial),0) AS approved
      FROM contracts c JOIN v_contract_financial_summary f ON f.contract_id=c.id
      WHERE c.company_id=?
    ''', [companyId]);
    return rows.first.map((key, value) => MapEntry(key, (value as int?) ?? 0));
  }

  /// Home dashboard scoped to one contract, not totals for every contract.
  Future<Map<String, int>> dashboardForContract(int companyId, int contractId) async {
    final rows = await db.rawQuery('''
      SELECT f.cost_rial AS costs, f.paid_rial AS payments,
        f.received_rial AS receipts, f.approved_work_rial AS approved
      FROM contracts c JOIN v_contract_financial_summary f ON f.contract_id=c.id
      WHERE c.company_id=? AND c.id=? LIMIT 1
    ''', [companyId, contractId]);
    if (rows.isEmpty) throw StateError('قرارداد فعال در این شرکت پیدا نشد.');
    return rows.first.map((key, value) => MapEntry(key, (value as int?) ?? 0));
  }

  Future<int> addActivity(int contractId, {required String title, required int percent, required String date, String? note}) {
    if (title.trim().isEmpty || percent < 0 || percent > 100) throw ArgumentError('اطلاعات فعالیت نامعتبر است');
    return db.insert('activities', {
      'contract_id': contractId, 'title': title.trim(), 'planned_date': date,
      'completed_date': percent == 100 ? date : null,
      'progress_percent': percent, 'status': percent == 100 ? 'DONE' : percent > 0 ? 'IN_PROGRESS' : 'PLANNED', 'note': note,
    });
  }

  Future<int> updateActivity(int contractId, int activityId, {
    required String title, required int percent, required String date, String? note,
  }) async {
    if (title.trim().isEmpty || percent < 0 || percent > 100) {
      throw ArgumentError('اطلاعات فعالیت نامعتبر است');
    }
    final count = await db.update('activities', {
      'title': title.trim(), 'planned_date': date,
      'completed_date': percent == 100 ? date : null,
      'progress_percent': percent,
      'status': percent == 100 ? 'DONE' : percent > 0 ? 'IN_PROGRESS' : 'PLANNED',
      'note': note,
    }, where: 'id=? AND contract_id=?', whereArgs: [activityId, contractId]);
    if (count != 1) throw StateError('فعالیت در این قرارداد پیدا نشد.');
    return count;
  }

  Future<List<Map<String, Object?>>> allActivities(int companyId, {required int contractId}) async {
    return db.rawQuery('''
      SELECT a.*, c.title AS contract_title, c.contract_no
      FROM activities a JOIN contracts c ON a.contract_id=c.id
      WHERE c.company_id=? AND a.contract_id=?
      ORDER BY CASE a.status WHEN 'IN_PROGRESS' THEN 0 WHEN 'PLANNED' THEN 1 ELSE 2 END,
        a.planned_date DESC, a.id DESC
    ''', [companyId, contractId]);
  }

  /// Company-scoped rows; SQL table/column names come from a closed enum.
  Future<List<Map<String, Object?>>> financialRecords(int companyId, FinanceKind kind, {required int contractId}) {
    return db.rawQuery('''
      SELECT t.*, c.title AS contract_title, c.contract_no
      FROM ${kind.table} AS t JOIN contracts c ON c.id=t.contract_id
      WHERE c.company_id=? AND t.contract_id=?
      ORDER BY t.${kind.dateField} DESC, t.id DESC
    ''',[companyId, contractId]);
  }

  Future<int> addMoney(int contractId, {required String kind, required int amountRial, required String date,
    ExpenseDetail? expenseDetail, ReceiptDetail? receiptDetail, String? memo}) async {
    if (amountRial <= 0) throw ArgumentError('مبلغ باید بزرگ‌تر از صفر باشد');
    switch (kind) {
      case 'expenses':
        final details = expenseDetail;
        if (details == null) throw ArgumentError('انتخاب نوع و تفصیلی هزینه الزامی است');
        final error = details.validate();
        if (error != null) throw ArgumentError(error);
        return db.insert('expenses', {
          'contract_id': contractId,
          'expense_date': date,
          'category': details.categoryTitle,
          'category_code': details.categoryCode,
          'detail_title': details.detailTitle.trim(),
          'counterparty_name': details.counterpartyName.trim(),
          'amount_rial': amountRial,
          'memo': memo?.trim(),
        });
      case 'payments':
        return db.insert('payments', {'contract_id': contractId, 'payment_date': date, 'amount_rial': amountRial, 'memo': memo});
      case 'receipts':
        final detail = receiptDetail;
        if (detail == null) {
          throw ArgumentError('نوع دریافت و مشخصات پرداخت‌کننده الزامی است');
        }
        final problem = detail.validate();
        if (problem != null) throw ArgumentError(problem);
        return db.insert('receipts', {
          'contract_id': contractId,
          'receipt_date': date,
          'amount_rial': amountRial,
          'category_code': detail.categoryCode,
          'detail_title': detail.detailTitle.trim(),
          'counterparty_name': detail.payerName.trim(),
          'payment_method': detail.paymentMethod,
          'reference_no': detail.referenceNo.trim(),
          'memo': memo?.trim(),
        });
      default:
        throw ArgumentError('نوع عملیات مالی نامعتبر است');
    }
  }

  Future<int> addStatement(int contractId, {
    required String number, required String date, required int grossRial,
    int vatRial = 0, int deductionsRial = 0,
    String status = 'DRAFT', String description = '',
  }) {
    if (number.trim().isEmpty || grossRial < 0 || vatRial < 0 ||
        deductionsRial < 0 || deductionsRial > grossRial + vatRial ||
        !const {'DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED'}.contains(status)) {
      throw ArgumentError('شماره، مبالغ یا وضعیت صورت‌وضعیت معتبر نیست');
    }
    return db.insert('statements', {
      'contract_id': contractId, 'statement_no': number.trim(),
      'statement_date': date, 'gross_rial': grossRial,
      'vat_rial': vatRial, 'deductions_rial': deductionsRial,
      'status': status, 'description': description.trim(),
    });
  }

  /// One transaction makes overview, charts, and exported records consistent.
  /// A report cannot leak records of another company/contract.
  Future<ContractReport> report(int companyId, int contractId) async {
    return db.transaction((txn) async {
      final contracts = await txn.rawQuery('''
        SELECT c.*, e.full_name employer_name, k.full_name contractor_name,
          f.cost_rial, f.paid_rial, f.received_rial, f.approved_work_rial,
          f.approved_net_payable_rial, f.provisional_margin_rial, f.cash_flow_rial,
          co.name company_name
        FROM contracts c
        JOIN companies co ON co.id=c.company_id
        JOIN parties e ON e.id=c.employer_party_id
        JOIN parties k ON k.id=c.contractor_party_id
        JOIN v_contract_financial_summary f ON f.contract_id=c.id
        WHERE c.id=? AND c.company_id=? LIMIT 1
      ''', [contractId, companyId]);
      if (contracts.isEmpty) throw StateError('قرارداد در این شرکت پیدا نشد');
      final c = contracts.first;
      final rows = <ReportRecord>[];
      final activities = await txn.query('activities', where: 'contract_id=?', whereArgs: [contractId]);
      for (final row in activities) {
        rows.add(ReportRecord(kind: 'activities', dateIso: (row['completed_date'] ?? row['planned_date'] ?? '').toString(),
          title: (row['title'] ?? '').toString(), amountRial: 0,
          status: '${row['progress_percent']}٪', note: (row['note'] ?? '').toString()));
      }
      final expenses = await txn.query('expenses', where: 'contract_id=?', whereArgs: [contractId]);
      for (final row in expenses) {
        final detail = (row['detail_title'] ?? '').toString().trim();
        final counterparty = (row['counterparty_name'] ?? '').toString().trim();
        final memo = (row['memo'] ?? '').toString().trim();
        rows.add(ReportRecord(kind: 'expenses', dateIso: row['expense_date'].toString(),
          title: row['category'].toString(), amountRial: row['amount_rial'] as int,
          note: [
            if (detail.isNotEmpty) 'تفصیلی: $detail',
            if (counterparty.isNotEmpty) 'طرف حساب: $counterparty',
            if (memo.isNotEmpty) memo,
          ].join(' | ')));
      }
      final payments = await txn.query('payments', where: 'contract_id=?', whereArgs: [contractId]);
      for (final row in payments) {
        rows.add(ReportRecord(kind: 'payments', dateIso: row['payment_date'].toString(),
          title: 'پرداخت', amountRial: row['amount_rial'] as int,
          note: (row['memo'] ?? '').toString()));
      }
      final receipts = await txn.query('receipts', where: 'contract_id=?', whereArgs: [contractId]);
      for (final row in receipts) {
        final category = receiptCategoryByCode((row['category_code'] ?? '').toString());
        final payer = (row['counterparty_name'] ?? '').toString().trim();
        final detail = (row['detail_title'] ?? '').toString().trim();
        final reference = (row['reference_no'] ?? '').toString().trim();
        final originalMemo = (row['memo'] ?? '').toString().trim();
        rows.add(ReportRecord(
          kind: 'receipts', dateIso: row['receipt_date'].toString(),
          title: category?.name ?? 'دریافت قدیمی (بدون دسته‌بندی)',
          amountRial: row['amount_rial'] as int,
          note: [
            if (payer.isNotEmpty) 'پرداخت‌کننده: $payer',
            if (detail.isNotEmpty) 'تفصیلی: $detail',
            if (reference.isNotEmpty) 'شماره پیگیری: $reference',
            if (originalMemo.isNotEmpty) originalMemo,
          ].join(' | '),
        ));
      }
      final statements = await txn.query('statements', where: 'contract_id=?', whereArgs: [contractId]);
      for (final row in statements) {
        final gross = row['gross_rial'] as int;
        final vat = (row['vat_rial'] as int?) ?? 0;
        final deductions = (row['deductions_rial'] as int?) ?? 0;
        final description = (row['description'] ?? '').toString().trim();
        rows.add(ReportRecord(
          kind: 'statements', dateIso: row['statement_date'].toString(),
          title: 'صورت‌وضعیت ${row['statement_no']}',
          amountRial: gross, status: (row['status'] ?? '').toString(),
          note: 'ارزش افزوده: $vat ریال | کسورات: $deductions ریال | خالص: ${gross + vat - deductions} ریال'
            '${description.isEmpty ? '' : ' | $description'}',
        ));
      }
      rows.sort((a, b) => b.dateIso.compareTo(a.dateIso));
      return ContractReport(
        companyName: c['company_name'].toString(), contractNo: c['contract_no'].toString(),
        contractTitle: c['title'].toString(), employer: c['employer_name'].toString(),
        contractor: c['contractor_name'].toString(), contractAmountRial: c['amount_rial'] as int,
        costRial: c['cost_rial'] as int, paymentRial: c['paid_rial'] as int,
        receiptRial: c['received_rial'] as int, approvedGrossRial: c['approved_work_rial'] as int,
        approvedNetRial: c['approved_net_payable_rial'] as int,
        provisionalMarginRial: c['provisional_margin_rial'] as int,
        cashFlowRial: c['cash_flow_rial'] as int,
        records: List.unmodifiable(rows),
      );
    });
  }

  Future<List<Map<String, Object?>>> records(int contractId, String kind) async {
    const allowed = {'activities', 'expenses', 'payments', 'receipts', 'statements'};
    if (!allowed.contains(kind)) throw ArgumentError('جدول نامعتبر');
    return db.query(kind, where: 'contract_id=?', whereArgs: [contractId], orderBy: 'id DESC');
  }
}

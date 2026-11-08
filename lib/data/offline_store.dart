import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../reports/report_model.dart';

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
  OfflineStore._(this.db);
  final Database db;

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
    final database = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys=ON'),
      onOpen: (db) async {
        final version = await db.rawQuery('PRAGMA user_version');
        if ((version.first['user_version'] as int) != 1) {
          throw StateError('نسخه پایگاه داده پشتیبانی نمی‌شود؛ اطلاعات را بازنشانی نکنید.');
        }
        final integrity = await db.rawQuery('PRAGMA quick_check');
        if (integrity.first.values.first != 'ok') {
          throw StateError('یکپارچگی پایگاه داده نامعتبر است؛ بازیابی لازم است.');
        }
      },
    );
    return OfflineStore._(database);
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

  Future<int> addActivity(int contractId, {required String title, required int percent, required String date, String? note}) {
    if (title.trim().isEmpty || percent < 0 || percent > 100) throw ArgumentError('اطلاعات فعالیت نامعتبر است');
    return db.insert('activities', {
      'contract_id': contractId, 'title': title.trim(), 'planned_date': date,
      'completed_date': percent == 100 ? date : null,
      'progress_percent': percent, 'status': percent == 100 ? 'DONE' : percent > 0 ? 'IN_PROGRESS' : 'PLANNED', 'note': note,
    });
  }

  Future<int> addMoney(int contractId, {required String kind, required int amountRial, required String date,
    String? category, String? memo}) async {
    if (amountRial <= 0) throw ArgumentError('مبلغ باید بزرگ‌تر از صفر باشد');
    switch (kind) {
      case 'expenses':
        if ((category ?? '').trim().isEmpty) throw ArgumentError('دسته هزینه الزامی است');
        return db.insert('expenses', {'contract_id': contractId, 'expense_date': date, 'category': category!.trim(), 'amount_rial': amountRial, 'memo': memo});
      case 'payments':
        return db.insert('payments', {'contract_id': contractId, 'payment_date': date, 'amount_rial': amountRial, 'memo': memo});
      case 'receipts':
        return db.insert('receipts', {'contract_id': contractId, 'receipt_date': date, 'amount_rial': amountRial, 'memo': memo});
      default:
        throw ArgumentError('نوع عملیات مالی نامعتبر است');
    }
  }

  Future<int> addStatement(int contractId, {required String number, required String date, required int grossRial,
    String status = 'DRAFT', String description = ''}) {
    if (number.trim().isEmpty || grossRial < 0 || !const {'DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED'}.contains(status)) {
      throw ArgumentError('اطلاعات صورت‌وضعیت نامعتبر است');
    }
    return db.insert('statements', {
      'contract_id': contractId, 'statement_no': number.trim(), 'statement_date': date,
      'gross_rial': grossRial, 'status': status, 'description': description,
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
        rows.add(ReportRecord(kind: 'expenses', dateIso: row['expense_date'].toString(),
          title: row['category'].toString(), amountRial: row['amount_rial'] as int,
          note: (row['memo'] ?? '').toString()));
      }
      final payments = await txn.query('payments', where: 'contract_id=?', whereArgs: [contractId]);
      for (final row in payments) {
        rows.add(ReportRecord(kind: 'payments', dateIso: row['payment_date'].toString(),
          title: 'پرداخت', amountRial: row['amount_rial'] as int,
          note: (row['memo'] ?? '').toString()));
      }
      final receipts = await txn.query('receipts', where: 'contract_id=?', whereArgs: [contractId]);
      for (final row in receipts) {
        rows.add(ReportRecord(kind: 'receipts', dateIso: row['receipt_date'].toString(),
          title: 'دریافت', amountRial: row['amount_rial'] as int,
          note: (row['memo'] ?? '').toString()));
      }
      final statements = await txn.query('statements', where: 'contract_id=?', whereArgs: [contractId]);
      for (final row in statements) {
        rows.add(ReportRecord(kind: 'statements', dateIso: row['statement_date'].toString(),
          title: 'صورت‌وضعیت ${row['statement_no']}', amountRial: row['gross_rial'] as int,
          status: (row['status'] ?? '').toString(), note: (row['description'] ?? '').toString()));
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

import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import '../finance/deduction_model.dart';
import 'offline_store.dart';

/// Persistent, contract-scoped and independently reviewable deduction ledger.
/// This records deductions, NOT separate expenses or cash transactions.
extension StatementDeductionStore on OfflineStore {
  Future<Map<String, Object?>> _scopedStatement(
      Transaction txn, int companyId, int contractId, int statementId) async {
    final rows = await txn.rawQuery('''
      SELECT s.*
      FROM statements s JOIN contracts c ON c.id=s.contract_id
      WHERE s.id=? AND s.contract_id=? AND c.company_id=?
      LIMIT 1
    ''', [statementId, contractId, companyId]);
    if (rows.isEmpty) {
      throw StateError('صورت‌وضعیت در شرکت و قرارداد انتخاب‌شده پیدا نشد.');
    }
    return rows.single;
  }

  Future<DeductionSnapshot> statementDeductionSnapshot({
    required int companyId,
    required int contractId,
    required int statementId,
  }) => db.transaction((txn) async {
        final statement = await _scopedStatement(
            txn, companyId, contractId, statementId);
        final rows = await txn.query('statement_deduction_lines',
            where: 'statement_id=?', whereArgs: [statementId],
            orderBy: 'kind');
        final audits = await txn.query('statement_deduction_audit',
            where: 'statement_id=? AND contract_id=?',
            whereArgs: [statementId, contractId],
            orderBy: 'id DESC', limit: 30);
        final allocated = await txn.rawQuery('''
          SELECT COALESCE(SUM(amount_rial),0) AS allocated_rial
          FROM statement_receipt_allocations WHERE statement_id=?
        ''', [statementId]);
        return DeductionSnapshot(
          number: statement['statement_no'].toString(),
          status: statement['status'].toString(),
          grossRial: statement['gross_rial'] as int,
          vatRial: statement['vat_rial'] as int,
          totalDeductionsRial: statement['deductions_rial'] as int,
          allocatedReceiptsRial: allocated.single['allocated_rial'] as int,
          lines: [
            for (final r in rows)
              DeductionLine(
                  kind: r['kind'].toString(),
                  amountRial: r['amount_rial'] as int,
                  basisRef: r['basis_ref'].toString()),
          ],
          revisions: [
            for (final r in audits)
              DeductionRevision(
                  id: r['id'] as int,
                  previousRial: r['previous_rial'] as int,
                  currentRial: r['current_rial'] as int,
                  changedAt: r['recorded_at'].toString(),
                  reason: r['reason'].toString(),
                  beforeJson: r['before_json'].toString(),
                  afterJson: r['after_json'].toString()),
          ],
        );
      });

  /// True only after an explicit per-category breakdown was persisted.
  Future<bool> hasStatementDeductionDetails(
      int contractId, int statementId) async {
    final rows = await db.rawQuery('''
      SELECT 1 FROM statement_deduction_lines d
      JOIN statements s ON s.id=d.statement_id
      WHERE d.statement_id=? AND s.contract_id=?
      LIMIT 1
    ''', [statementId, contractId]);
    return rows.isNotEmpty;
  }

  Future<void> replaceStatementDeductions({
    required int companyId,
    required int contractId,
    required int statementId,
    required List<DeductionLine> lines,
    required String reason,
  }) async {
    final normalized = reason.trim();
    if (normalized.length < 5 || normalized.length > 300) {
      throw ArgumentError('دلیل تغییر باید بین ۵ تا ۳۰۰ نویسه باشد.');
    }
    final total = checkedDeductionsTotal(lines);
    await db.transaction((txn) async {
      final statement = await _scopedStatement(
          txn, companyId, contractId, statementId);
      final previousTotal = statement['deductions_rial'] as int;
      final allocations = await txn.rawQuery('''
        SELECT COALESCE(SUM(amount_rial),0) AS allocated_rial
        FROM statement_receipt_allocations WHERE statement_id=?
      ''', [statementId]);
      validateDeductionSettlement(
        grossRial: statement['gross_rial'] as int,
        vatRial: statement['vat_rial'] as int,
        allocatedRial: allocations.single['allocated_rial'] as int,
        deductionsRial: total,
      );
      final previousRows = await txn.query('statement_deduction_lines',
          columns: ['kind', 'amount_rial', 'basis_ref'],
          where: 'statement_id=?', whereArgs: [statementId],
          orderBy: 'kind');
      final currentRows = [
        for (final line in lines)
          <String, Object?>{
            'kind': line.kind,
            'amount_rial': line.amountRial,
            'basis_ref': line.basisRef.trim(),
          }
      ]..sort((a, b) =>
            (a['kind'] as String).compareTo(b['kind'] as String));
      final beforeJson = jsonEncode(previousRows);
      final afterJson = jsonEncode(currentRows);
      if (beforeJson == afterJson && previousTotal == total) {
        throw StateError('تغییری در ریز کسورات ثبت نشده است.');
      }

      await txn.delete('statement_deduction_lines',
          where: 'statement_id=?', whereArgs: [statementId]);
      for (final line in lines) {
        await txn.insert('statement_deduction_lines', {
          'statement_id': statementId,
          'kind': line.kind,
          'amount_rial': line.amountRial,
          'basis_ref': line.basisRef.trim(),
        });
      }
      final changed = await txn.update('statements', {
        'deductions_rial': total,
      }, where: 'id=? AND contract_id=?', whereArgs: [statementId, contractId]);
      if (changed != 1) {
        throw StateError('ذخیره جمع کسورات انجام نشد.');
      }
      await txn.insert('statement_deduction_audit', {
        'contract_id': contractId,
        'statement_id': statementId,
        'previous_rial': previousTotal,
        'current_rial': total,
        'before_json': beforeJson,
        'after_json': afterJson,
        'reason': normalized,
      });
    });
  }
}

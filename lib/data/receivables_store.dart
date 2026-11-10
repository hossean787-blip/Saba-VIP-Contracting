import 'package:sqflite/sqflite.dart';
import '../finance/receivables_model.dart';
import 'offline_store.dart';

/// Contract and company scope are verified for both reads and writes.
extension ReceivablesStore on OfflineStore {
  Future<ReceivablesSnapshot> receivables(
      int companyId, int contractId) async {
    return db.transaction((txn) async {
      await _requireContract(txn, companyId, contractId);
      final statementRows = await txn.rawQuery('''
        SELECT s.id,s.statement_no,s.statement_date,s.status,
          (s.gross_rial+s.vat_rial-s.deductions_rial) AS net_rial,
          COALESCE(a.allocated_rial,0) AS allocated_rial
        FROM statements s
        LEFT JOIN (
          SELECT statement_id,SUM(amount_rial) AS allocated_rial
          FROM statement_receipt_allocations GROUP BY statement_id
        ) a ON a.statement_id=s.id
        WHERE s.contract_id=?
        ORDER BY s.statement_date DESC,s.id DESC
      ''', [contractId]);
      final receiptRows = await txn.rawQuery('''
        SELECT r.id,r.receipt_date,r.category_code,r.counterparty_name,
          r.reference_no,r.amount_rial,
          COALESCE(a.allocated_rial,0) AS allocated_rial
        FROM receipts r
        LEFT JOIN (
          SELECT receipt_id,SUM(amount_rial) AS allocated_rial
          FROM statement_receipt_allocations GROUP BY receipt_id
        ) a ON a.receipt_id=r.id
        WHERE r.contract_id=?
        ORDER BY r.receipt_date DESC,r.id DESC
      ''', [contractId]);
      final allocationRows = await txn.rawQuery('''
        SELECT a.statement_id,s.statement_no,a.receipt_id,a.amount_rial
        FROM statement_receipt_allocations a
        JOIN statements s ON s.id=a.statement_id
        WHERE s.contract_id=?
        ORDER BY s.statement_date DESC,a.receipt_id DESC
      ''', [contractId]);
      final auditRows = await txn.rawQuery('''
        SELECT a.action,a.receipt_id,a.amount_rial,a.event_at,
               s.statement_no
        FROM statement_receipt_audit a
        JOIN statements s ON s.id=a.statement_id
        WHERE a.contract_id=?
        ORDER BY a.id DESC LIMIT 30
      ''', [contractId]);
      return ReceivablesSnapshot(
        statements: [
          for (final s in statementRows)
            StatementBalance(
              id: s['id'] as int,
              number: s['statement_no'].toString(),
              date: s['statement_date'].toString(),
              status: s['status'].toString(),
              netRial: s['net_rial'] as int,
              allocatedRial: s['allocated_rial'] as int,
            ),
        ],
        receipts: [
          for (final r in receiptRows)
            ReceiptBalance(
              id: r['id'] as int,
              date: r['receipt_date'].toString(),
              categoryCode: (r['category_code'] ?? '').toString(),
              payer: (r['counterparty_name'] ?? '').toString(),
              reference: (r['reference_no'] ?? '').toString(),
              amountRial: r['amount_rial'] as int,
              allocatedRial: r['allocated_rial'] as int,
            ),
        ],
        allocations: [
          for (final a in allocationRows)
            ReceiptAllocation(
              statementId: a['statement_id'] as int,
              statementNumber: a['statement_no'].toString(),
              receiptId: a['receipt_id'] as int,
              amountRial: a['amount_rial'] as int,
            ),
        ],
        audit: [
          for (final a in auditRows)
            AllocationAudit(
              action: a['action'].toString(),
              statementNumber: a['statement_no'].toString(),
              receiptId: a['receipt_id'] as int,
              amountRial: a['amount_rial'] as int,
              happenedAt: a['event_at'].toString(),
            ),
        ],
      );
    });
  }

  Future<void> allocateStatementReceipt({
    required int companyId,
    required int contractId,
    required int statementId,
    required int receiptId,
    required int amountRial,
  }) async {
    if (amountRial <= 0) throw ArgumentError('مبلغ تخصیص باید مثبت باشد.');
    await db.transaction((txn) async {
      await _requireContract(txn, companyId, contractId);
      final statements = await txn.rawQuery('''
        SELECT s.id,s.statement_no,s.statement_date,s.status,
               (s.gross_rial+s.vat_rial-s.deductions_rial) AS net_rial,
               COALESCE((SELECT SUM(amount_rial)
                 FROM statement_receipt_allocations
                 WHERE statement_id=s.id),0) AS allocated_rial
        FROM statements s WHERE s.id=? AND s.contract_id=?
      ''', [statementId, contractId]);
      final receipts = await txn.rawQuery('''
        SELECT r.id,r.receipt_date,r.category_code,r.counterparty_name,
               r.reference_no,r.amount_rial,
               COALESCE((SELECT SUM(amount_rial)
                 FROM statement_receipt_allocations
                 WHERE receipt_id=r.id),0) AS allocated_rial
        FROM receipts r WHERE r.id=? AND r.contract_id=?
      ''', [receiptId, contractId]);
      if (statements.isEmpty || receipts.isEmpty) {
        throw StateError('صورت‌وضعیت یا دریافت در قرارداد انتخاب‌شده موجود نیست.');
      }
      final s = statements.single;
      final r = receipts.single;
      validateStatementAllocation(
        statement: StatementBalance(
          id: statementId,
          number: s['statement_no'].toString(),
          date: s['statement_date'].toString(),
          status: s['status'].toString(),
          netRial: s['net_rial'] as int,
          allocatedRial: s['allocated_rial'] as int,
        ),
        receipt: ReceiptBalance(
          id: receiptId,
          date: r['receipt_date'].toString(),
          categoryCode: (r['category_code'] ?? '').toString(),
          payer: (r['counterparty_name'] ?? '').toString(),
          reference: (r['reference_no'] ?? '').toString(),
          amountRial: r['amount_rial'] as int,
          allocatedRial: r['allocated_rial'] as int,
        ),
        amountRial: amountRial,
      );
      final existing = await txn.query('statement_receipt_allocations',
          columns: ['amount_rial'],
          where: 'statement_id=? AND receipt_id=?',
          whereArgs: [statementId, receiptId]);
      if (existing.isEmpty) {
        await txn.insert('statement_receipt_allocations', {
          'statement_id': statementId,
          'receipt_id': receiptId,
          'amount_rial': amountRial,
        });
      } else {
        final current = existing.single['amount_rial'] as int;
        await txn.update('statement_receipt_allocations',
            {'amount_rial': current + amountRial},
            where: 'statement_id=? AND receipt_id=?',
            whereArgs: [statementId, receiptId]);
      }
      await txn.insert('statement_receipt_audit', {
        'contract_id': contractId,
        'statement_id': statementId,
        'receipt_id': receiptId,
        'amount_rial': amountRial,
        'action': 'LINK',
        'note': 'تخصیص دریافت به صورت‌وضعیت تأییدشده',
      });
    });
  }

  /// Reverses an allocation LINK, NOT the cash receipt; retains immutable audit.
  Future<void> unlinkStatementReceipt({
    required int companyId,
    required int contractId,
    required int statementId,
    required int receiptId,
    required String reason,
  }) async {
    if (reason.trim().length < 5 || reason.trim().length > 300) {
      throw ArgumentError('دلیل اصلاح باید ۵ تا ۳۰۰ نویسه باشد.');
    }
    await db.transaction((txn) async {
      await _requireContract(txn, companyId, contractId);
      final found = await txn.rawQuery('''
        SELECT a.amount_rial FROM statement_receipt_allocations a
        JOIN statements s ON s.id=a.statement_id
        JOIN receipts r ON r.id=a.receipt_id
        WHERE a.statement_id=? AND a.receipt_id=?
          AND s.contract_id=? AND r.contract_id=?
      ''', [statementId, receiptId, contractId, contractId]);
      if (found.length != 1) throw StateError('تخصیص قابل اصلاح پیدا نشد.');
      final amount = found.single['amount_rial'] as int;
      final count = await txn.delete('statement_receipt_allocations',
          where: 'statement_id=? AND receipt_id=?',
          whereArgs: [statementId, receiptId]);
      if (count != 1) throw StateError('اصلاح تخصیص انجام نشد.');
      await txn.insert('statement_receipt_audit', {
        'contract_id': contractId,
        'statement_id': statementId,
        'receipt_id': receiptId,
        'amount_rial': amount,
        'action': 'UNLINK',
        'note': reason.trim(),
      });
    });
  }

  Future<void> _requireContract(
      Transaction txn, int companyId, int contractId) async {
    final owner = await txn.query('contracts',
        columns: ['id'],
        where: 'id=? AND company_id=?',
        whereArgs: [contractId, companyId],
        limit: 1);
    if (owner.isEmpty) {
      throw StateError('قرارداد متعلق به شرکت جاری نیست.');
    }
  }
}

import 'package:sqflite/sqflite.dart';
import '../finance/boq_model.dart';
import 'offline_store.dart';

/// Company/contract scoped bill-of-quantities, append-only measured quantities,
/// and a transactional link to existing DRAFT interim statement documents.
extension BoqStore on OfflineStore {
  Future<void> _boqScope(Transaction txn, int companyId, int contractId) async {
    final rows = await txn.query('contracts',
        columns: ['id'],
        where: 'id=? AND company_id=?',
        whereArgs: [contractId, companyId], limit: 1);
    if (rows.isEmpty) throw StateError('این قرارداد متعلق به شرکت فعال نیست.');
  }

  Future<BoqSnapshot> boqSnapshot(
      {required int companyId, required int contractId}) {
    return db.transaction((txn) async {
      await _boqScope(txn, companyId, contractId);
      final items = await txn.rawQuery('''
        SELECT i.*,
        COALESCE((SELECT SUM(m.quantity_milli) FROM boq_measurements m
          WHERE m.item_id=i.id),0) AS measured_milli,
        COALESCE((SELECT SUM(m.quantity_milli) FROM boq_measurements m
          WHERE m.item_id=i.id AND m.statement_id IS NOT NULL),0) AS billed_milli,
        COALESCE((SELECT SUM(m.quantity_milli) FROM boq_measurements m
          WHERE m.item_id=i.id AND m.statement_id IS NULL),0) AS pending_milli
        FROM boq_items i WHERE i.contract_id=?
        ORDER BY i.item_code COLLATE NOCASE, i.id
      ''', [contractId]);
      final measures = await txn.rawQuery('''
        SELECT m.*,i.item_code FROM boq_measurements m
        JOIN boq_items i ON i.id=m.item_id
        WHERE m.contract_id=? ORDER BY m.id DESC
      ''', [contractId]);
      return BoqSnapshot(
        items: [
          for (final r in items)
            BoqItem(
              id: r['id'] as int,
              code: r['item_code'].toString(),
              title: r['title'].toString(),
              unit: r['unit'].toString(),
              source: (r['price_source'] ?? '').toString(),
              plannedQuantityMilli: r['planned_quantity_milli'] as int,
              unitPriceRial: r['unit_price_rial'] as int,
              coefficientBp: r['coefficient_bp'] as int,
              measuredQuantityMilli: r['measured_milli'] as int,
              billedQuantityMilli: r['billed_milli'] as int,
              pendingQuantityMilli: r['pending_milli'] as int,
            ),
        ],
        measurements: [
          for (final r in measures)
            BoqMeasurement(
              id: r['id'] as int,
              itemId: r['item_id'] as int,
              itemCode: r['item_code'].toString(),
              quantityMilli: r['quantity_milli'] as int,
              date: r['measured_at'].toString(),
              documentRef: r['document_ref'].toString(),
              memo: r['note'].toString(),
              statementId: r['statement_id'] as int?,
            ),
        ],
      );
    });
  }

  Future<int> saveBoqItem({
    required int companyId,
    required int contractId,
    int? itemId,
    required String code,
    required String title,
    required String unit,
    required String source,
    required int plannedQuantityMilli,
    required int unitPriceRial,
    required int coefficientBp,
  }) {
    final trimmedCode = code.trim();
    final trimmedTitle = title.trim();
    final trimmedUnit = unit.trim();
    if (trimmedCode.isEmpty || trimmedCode.length > 40 ||
        trimmedTitle.isEmpty || trimmedTitle.length > 250 ||
        trimmedUnit.isEmpty || trimmedUnit.length > 30 ||
        source.trim().length > 250 ||
        plannedQuantityMilli < 0 ||
        plannedQuantityMilli > 1000000000000 ||
        unitPriceRial <= 0 || coefficientBp < 1 || coefficientBp > 100000) {
      throw ArgumentError('اطلاعات ردیف برآورد نامعتبر است.');
    }
    if (plannedQuantityMilli > 0) {
      estimateRial(quantityMilli: plannedQuantityMilli,
          unitPriceRial: unitPriceRial, coefficientBp: coefficientBp);
    }
    return db.transaction((txn) async {
      await _boqScope(txn, companyId, contractId);
      final values = <String, Object?>{
        'contract_id': contractId,
        'item_code': trimmedCode,
        'title': trimmedTitle,
        'unit': trimmedUnit,
        'price_source': source.trim(),
        'planned_quantity_milli': plannedQuantityMilli,
        'unit_price_rial': unitPriceRial,
        'coefficient_bp': coefficientBp,
      };
      if (itemId == null) return txn.insert('boq_items', values);
      final count = await txn.update('boq_items', values,
          where: 'id=? AND contract_id=?', whereArgs: [itemId, contractId]);
      if (count != 1) throw StateError('ردیف موردنظر در قرارداد پیدا نشد.');
      return itemId;
    });
  }

  Future<int> recordBoqMeasurement({
    required int companyId,
    required int contractId,
    required int itemId,
    required int quantityMilli,
    required String measuredAt,
    required String documentRef,
    required String note,
  }) {
    if (quantityMilli == 0 || quantityMilli.abs() > 1000000000000 ||
        DateTime.tryParse(measuredAt) == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(measuredAt) ||
        documentRef.trim().isEmpty || documentRef.trim().length > 100 ||
        note.trim().length > 600 ||
        (quantityMilli < 0 && note.trim().length < 5)) {
      throw ArgumentError('مقدار، تاریخ یا مستندات متره معتبر نیست.');
    }
    return db.transaction((txn) async {
      await _boqScope(txn, companyId, contractId);
      final items = await txn.query('boq_items',
          columns: ['unit_price_rial','coefficient_bp'],
          where: 'id=? AND contract_id=?',
          whereArgs: [itemId, contractId], limit: 1);
      if (items.isEmpty) throw StateError('ردیف در قرارداد موجود نیست.');
      estimateRial(quantityMilli: quantityMilli,
          unitPriceRial: items.single['unit_price_rial'] as int,
          coefficientBp: items.single['coefficient_bp'] as int);
      final totals = await txn.rawQuery('''
        SELECT COALESCE(SUM(quantity_milli),0) AS measured
        FROM boq_measurements WHERE item_id=?
      ''', [itemId]);
      if ((totals.single['measured'] as int) + quantityMilli < 0) {
        throw StateError('اصلاح متره، مقدار تجمعی را منفی می‌کند.');
      }
      return txn.insert('boq_measurements', {
        'contract_id': contractId,
        'item_id': itemId,
        'quantity_milli': quantityMilli,
        'measured_at': measuredAt,
        'document_ref': documentRef.trim(),
        'note': note.trim(),
      });
    });
  }

  /// Generates an actual existing-schema statement in DRAFT, zero VAT,
  /// zero deductions. An auditor must review tax/retentions and approve.
  /// Groups all currently unbilled measures by item and captures the price
  /// as an immutable snapshot, preventing duplicate billing.
  Future<int> draftStatementFromBoq({
    required int companyId,
    required int contractId,
    required String number,
    required String statementDate,
  }) async {
    if (number.trim().isEmpty || number.trim().length > 80 ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(statementDate) ||
        DateTime.tryParse(statementDate) == null) {
      throw ArgumentError('شماره یا تاریخ صورت‌وضعیت نامعتبر است.');
    }
    return db.transaction((txn) async {
      await _boqScope(txn, companyId, contractId);
      final pending = await txn.rawQuery('''
        SELECT i.id AS item_id, i.unit_price_rial, i.coefficient_bp,
               SUM(m.quantity_milli) AS quantity_milli,
               COUNT(m.id) AS entry_count
        FROM boq_measurements m
        JOIN boq_items i ON i.id=m.item_id
        WHERE m.contract_id=? AND m.statement_id IS NULL
        GROUP BY i.id,i.unit_price_rial,i.coefficient_bp
        ORDER BY i.id
      ''', [contractId]);
      if (pending.isEmpty) {
        throw StateError('متره تخصیص‌نیافته برای صدور صورت‌وضعیت وجود ندارد.');
      }
      final amounts = <int>[];
      for (final row in pending) {
        final quantity = row['quantity_milli'] as int;
        amounts.add(quantity == 0 ? 0 : estimateRial(
            quantityMilli: quantity,
            unitPriceRial: row['unit_price_rial'] as int,
            coefficientBp: row['coefficient_bp'] as int));
      }
      final gross = checkedTotal(amounts);
      if (gross <= 0) {
        throw StateError('جمع دوره باید مثبت باشد؛ اصلاحات متره را بررسی کنید.');
      }
      final statementId = await txn.insert('statements', {
        'contract_id': contractId,
        'statement_no': number.trim(),
        'statement_date': statementDate,
        'gross_rial': gross,
        'vat_rial': 0,
        'deductions_rial': 0,
        'status': 'DRAFT',
        'description': 'پیش‌نویس متصل به متره؛ مالیات و کسورات نیازمند بررسی است.',
      });
      for (var i = 0; i < pending.length; i++) {
        final row = pending[i];
        await txn.insert('boq_statement_lines', {
          'statement_id': statementId,
          'item_id': row['item_id'],
          'quantity_milli': row['quantity_milli'],
          'unit_price_rial': row['unit_price_rial'],
          'coefficient_bp': row['coefficient_bp'],
          'line_amount_rial': amounts[i],
        });
      }
      final count = await txn.rawUpdate('''
        UPDATE boq_measurements
        SET statement_id=?
        WHERE contract_id=? AND statement_id IS NULL
      ''', [statementId, contractId]);
      final expected = pending.fold<int>(
          0, (sum, row) => sum + (row['entry_count'] as int));
      if (count != expected) {
        throw StateError('متره‌ها تغییر کرده‌اند؛ صدور انجام نشد.');
      }
      final control = await txn.rawQuery('''
        SELECT COALESCE(SUM(line_amount_rial),0) AS matched
        FROM boq_statement_lines WHERE statement_id=?
      ''', [statementId]);
      if (control.single['matched'] != gross) {
        throw StateError('جمع ردیف‌های متره با صورت‌وضعیت برابر نیست.');
      }
      return statementId;
    });
  }
}

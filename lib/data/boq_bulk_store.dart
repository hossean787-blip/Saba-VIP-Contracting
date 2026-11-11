import 'package:sqflite/sqflite.dart';
import '../finance/boq_import.dart';
import 'offline_store.dart';

/// All-or-nothing import. Existing BOQ rows and measurements are NEVER replaced.
extension BoqBulkStore on OfflineStore {
  Future<int> importBoqRows({
    required int companyId,
    required int contractId,
    required BoqImportBatch batch,
  }) async {
    if (batch.rows.isEmpty || batch.rows.length > BoqExcelImport.maxRows) {
      throw ArgumentError('تعداد ردیف‌های ورود گروهی نامعتبر است.');
    }
    return db.transaction((Transaction txn) async {
      final scope = await txn.query('contracts',
        columns: ['id'], where: 'id=? AND company_id=?',
        whereArgs: [contractId, companyId], limit: 1);
      if (scope.isEmpty) {
        throw StateError('قرارداد متعلق به شرکت فعال نیست.');
      }
      final existing = await txn.query('boq_items',
        columns: ['item_code'], where: 'contract_id=?',
        whereArgs: [contractId]);
      final seen = existing.map((row) =>
          row['item_code'].toString().toLowerCase()).toSet();
      for (final row in batch.rows) {
        if (!seen.add(row.code.toLowerCase())) {
          throw StateError(
              'کد ردیف ' + row.code + ' قبلاً در این قرارداد ثبت شده است.');
        }
      }
      for (final row in batch.rows) {
        // Revalidate because callers may construct a batch directly.
        if (row.code.trim().isEmpty || row.code.length > 40 ||
            row.title.trim().isEmpty || row.title.length > 250 ||
            row.unit.trim().isEmpty || row.unit.length > 30 ||
            row.source.trim().isEmpty || row.source.length > 250 ||
            row.quantityMilli <= 0 || row.quantityMilli > 1000000000000 ||
            row.unitPriceRial <= 0 || row.coefficientBp < 1 ||
            row.coefficientBp > 100000) {
          throw ArgumentError('مقادیر ردیف ورود گروهی نامعتبر است.');
        }
        // Verify all amounts and the total before any transaction commits.
        row.plannedRial;
        await txn.insert('boq_items', {
          'contract_id': contractId,
          'item_code': row.code.trim(),
          'title': row.title.trim(),
          'unit': row.unit.trim(),
          'price_source': row.source.trim(),
          'planned_quantity_milli': row.quantityMilli,
          'unit_price_rial': row.unitPriceRial,
          'coefficient_bp': row.coefficientBp,
        });
      }
      return batch.rows.length;
    });
  }
}

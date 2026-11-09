import 'package:sqflite/sqflite.dart';

/// Additive v1 -> v2 migration. Existing data and allocations are preserved.
const expenseV2Sql = <String>[
  r'''ALTER TABLE expenses ADD COLUMN category_code TEXT''',
  r'''ALTER TABLE expenses ADD COLUMN detail_title TEXT''',
  r'''ALTER TABLE expenses ADD COLUMN counterparty_name TEXT''',
  r'''CREATE INDEX idx_expenses_category_code ON expenses(category_code)''',
  r'''CREATE TRIGGER expense_detail_insert_guard BEFORE INSERT ON expenses
  WHEN NEW.category_code IS NOT NULL
  BEGIN
    SELECT RAISE(ABORT, 'unknown expense category') WHERE NEW.category_code NOT IN
      ('salary','day_labor','equipment_rental','survey','transport','food','materials',
       'equipment_purchase','fuel','maintenance','subcontract','insurance','tax',
       'accommodation','utilities','permits','other');
    SELECT RAISE(ABORT, 'expense details missing') WHERE
      length(trim(COALESCE(NEW.detail_title,'')))=0 AND
      length(trim(COALESCE(NEW.counterparty_name,'')))=0;
    SELECT RAISE(ABORT, 'required expense detail missing') WHERE
      NEW.category_code IN ('salary','day_labor','materials','equipment_purchase',
      'subcontract','insurance','tax','utilities','permits','other')
      AND length(trim(COALESCE(NEW.detail_title,'')))=0;
  END''',
  r'''CREATE TRIGGER expense_detail_update_guard BEFORE UPDATE ON expenses
  WHEN NEW.category_code IS NOT NULL
  BEGIN
    SELECT RAISE(ABORT, 'unknown expense category') WHERE NEW.category_code NOT IN
      ('salary','day_labor','equipment_rental','survey','transport','food','materials',
       'equipment_purchase','fuel','maintenance','subcontract','insurance','tax',
       'accommodation','utilities','permits','other');
    SELECT RAISE(ABORT, 'expense details missing') WHERE
      length(trim(COALESCE(NEW.detail_title,'')))=0 AND
      length(trim(COALESCE(NEW.counterparty_name,'')))=0;
    SELECT RAISE(ABORT, 'required expense detail missing') WHERE
      NEW.category_code IN ('salary','day_labor','materials','equipment_purchase',
      'subcontract','insurance','tax','utilities','permits','other')
      AND length(trim(COALESCE(NEW.detail_title,'')))=0;
  END''',
];
Future<void> upgradeExpenseDatabase(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2 && newVersion >= 2) {
    for (final sql in expenseV2Sql) { await db.execute(sql); }
  }
}

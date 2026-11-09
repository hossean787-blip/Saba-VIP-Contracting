import 'package:sqflite/sqflite.dart';

/// v2 -> v3: Additive migration; all existing receipts and statement allocations
/// remain intact. Legacy receipts have NULL detail fields, new ones are validated.
const receiptV3Sql = <String>[
  'ALTER TABLE receipts ADD COLUMN category_code TEXT',
  'ALTER TABLE receipts ADD COLUMN detail_title TEXT',
  'ALTER TABLE receipts ADD COLUMN counterparty_name TEXT',
  'ALTER TABLE receipts ADD COLUMN reference_no TEXT',
  'CREATE INDEX idx_receipts_category_code ON receipts(category_code)',
  r'''CREATE TRIGGER receipt_detail_insert_guard BEFORE INSERT ON receipts
  BEGIN
    SELECT RAISE(ABORT, 'receipt category required') WHERE
      NEW.category_code IS NULL OR NEW.category_code NOT IN
        ('statement_collection','contract_advance','on_account','final_settlement',
         'adjustment','retention_release','old_receivable','service_fee','reimbursement','other');
    SELECT RAISE(ABORT, 'receipt payer required') WHERE
      length(trim(COALESCE(NEW.counterparty_name,'')))=0;
    SELECT RAISE(ABORT, 'required receipt detail missing') WHERE
      NEW.category_code IN ('statement_collection','final_settlement','adjustment',
        'retention_release','old_receivable','service_fee','reimbursement','other')
      AND length(trim(COALESCE(NEW.detail_title,'')))=0;
    SELECT RAISE(ABORT, 'invalid payment method') WHERE
      NEW.payment_method IS NULL OR
      NEW.payment_method NOT IN ('TRANSFER','CASH','CHECK','POS','OTHER');
  END''',
  r'''CREATE TRIGGER receipt_detail_update_guard BEFORE UPDATE ON receipts
  WHEN NEW.category_code IS NOT NULL
  BEGIN
    SELECT RAISE(ABORT, 'receipt category unknown') WHERE NEW.category_code NOT IN
        ('statement_collection','contract_advance','on_account','final_settlement',
         'adjustment','retention_release','old_receivable','service_fee','reimbursement','other');
    SELECT RAISE(ABORT, 'receipt payer required') WHERE
      length(trim(COALESCE(NEW.counterparty_name,'')))=0;
    SELECT RAISE(ABORT, 'required receipt detail missing') WHERE
      NEW.category_code IN ('statement_collection','final_settlement','adjustment',
        'retention_release','old_receivable','service_fee','reimbursement','other')
      AND length(trim(COALESCE(NEW.detail_title,'')))=0;
    SELECT RAISE(ABORT, 'invalid payment method') WHERE
      NEW.payment_method IS NULL OR
      NEW.payment_method NOT IN ('TRANSFER','CASH','CHECK','POS','OTHER');
  END''',
];

Future<void> upgradeReceiptDatabase(
    Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 3 && newVersion >= 3) {
    for (final sql in receiptV3Sql) {
      await db.execute(sql);
    }
  }
}

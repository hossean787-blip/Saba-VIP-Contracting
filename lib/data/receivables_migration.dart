import 'package:sqflite/sqflite.dart';

/// v3 -> v4, additive and transactional. Existing receipts/links stay intact.
/// LEGACY records identify historical allocations without inventing their dates.
const receivablesV4Sql = <String>[
  r'''CREATE TABLE statement_receipt_audit (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    contract_id INTEGER NOT NULL REFERENCES contracts(id) ON DELETE RESTRICT,
    statement_id INTEGER NOT NULL REFERENCES statements(id) ON DELETE RESTRICT,
    receipt_id INTEGER NOT NULL REFERENCES receipts(id) ON DELETE RESTRICT,
    action TEXT NOT NULL CHECK(action IN ('LINK','UNLINK','LEGACY')),
    amount_rial INTEGER NOT NULL CHECK(amount_rial > 0),
    event_at TEXT NOT NULL DEFAULT (datetime('now')),
    note TEXT NOT NULL DEFAULT ''
  )''',
  'CREATE INDEX idx_sra_by_receipt ON statement_receipt_allocations(receipt_id)',
  'CREATE INDEX idx_sra_audit_contract ON statement_receipt_audit(contract_id,id DESC)',
  r'''CREATE TRIGGER statement_receipt_audit_no_update
    BEFORE UPDATE ON statement_receipt_audit
    BEGIN SELECT RAISE(ABORT,'allocation audit is immutable'); END''',
  r'''CREATE TRIGGER statement_receipt_audit_no_delete
    BEFORE DELETE ON statement_receipt_audit
    BEGIN SELECT RAISE(ABORT,'allocation audit is immutable'); END''',
  r'''CREATE TRIGGER allocated_receipt_category_guard
    BEFORE UPDATE OF category_code ON receipts
    WHEN EXISTS (
      SELECT 1 FROM statement_receipt_allocations
      WHERE receipt_id=OLD.id
    )
    BEGIN
      SELECT RAISE(ABORT,'allocated receipt category must remain eligible')
      WHERE NEW.category_code IS NULL OR NEW.category_code NOT IN
        ('statement_collection','final_settlement','adjustment',
         'retention_release','old_receivable');
    END''',
  r'''CREATE TRIGGER allocation_receipt_category_insert
    BEFORE INSERT ON statement_receipt_allocations
    BEGIN
      SELECT RAISE(ABORT,'receipt category cannot settle statement')
      WHERE NOT EXISTS (
        SELECT 1 FROM receipts r WHERE r.id=NEW.receipt_id AND
        r.category_code IN ('statement_collection','final_settlement',
          'adjustment','retention_release','old_receivable'));
    END''',
  r'''CREATE TRIGGER allocation_receipt_category_update
    BEFORE UPDATE ON statement_receipt_allocations
    BEGIN
      SELECT RAISE(ABORT,'receipt category cannot settle statement')
      WHERE NOT EXISTS (
        SELECT 1 FROM receipts r WHERE r.id=NEW.receipt_id AND
        r.category_code IN ('statement_collection','final_settlement',
          'adjustment','retention_release','old_receivable'));
    END''',
  r'''INSERT INTO statement_receipt_audit(
    contract_id,statement_id,receipt_id,action,amount_rial,note)
    SELECT s.contract_id,a.statement_id,a.receipt_id,'LEGACY',
           a.amount_rial,'تخصیص پیش از ارتقا؛ زمان اصلی نامشخص است'
    FROM statement_receipt_allocations a
    JOIN statements s ON s.id=a.statement_id''',
];

Future<void> upgradeReceivablesDatabase(
    Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 4 && newVersion >= 4) {
    for (final sql in receivablesV4Sql) {
      await db.execute(sql);
    }
  }
}

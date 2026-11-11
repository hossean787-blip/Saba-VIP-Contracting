import 'package:sqflite/sqflite.dart';

/// v5 -> v6: additive. Existing statement deduction totals are untouched.
/// Records without a breakdown remain explicitly unclassified until reviewed.
const deductionV6Sql = <String>[
  r'''CREATE TABLE statement_deduction_lines (
    statement_id INTEGER NOT NULL REFERENCES statements(id)
      ON DELETE RESTRICT,
    kind TEXT NOT NULL CHECK(kind IN
      ('retention','insurance','advance','withholding','penalty','other')),
    amount_rial INTEGER NOT NULL CHECK(amount_rial > 0),
    basis_ref TEXT NOT NULL
      CHECK(length(trim(basis_ref)) BETWEEN 3 AND 160),
    PRIMARY KEY(statement_id,kind)
  )''',
  r'''CREATE TABLE statement_deduction_audit (
    id INTEGER PRIMARY KEY,
    contract_id INTEGER NOT NULL REFERENCES contracts(id) ON DELETE RESTRICT,
    statement_id INTEGER NOT NULL REFERENCES statements(id) ON DELETE RESTRICT,
    previous_rial INTEGER NOT NULL CHECK(previous_rial >= 0),
    current_rial INTEGER NOT NULL CHECK(current_rial >= 0),
    before_json TEXT NOT NULL,
    after_json TEXT NOT NULL,
    reason TEXT NOT NULL CHECK(length(trim(reason)) BETWEEN 5 AND 300),
    recorded_at TEXT NOT NULL DEFAULT (datetime('now'))
  )''',
  'CREATE INDEX idx_deduction_audit_contract ON statement_deduction_audit(contract_id,id DESC)',
  r'''CREATE TRIGGER deduction_audit_insert_scope
    BEFORE INSERT ON statement_deduction_audit
    BEGIN
      SELECT RAISE(ABORT,'cross-contract deduction audit')
      WHERE (SELECT contract_id FROM statements WHERE id=NEW.statement_id)
        != NEW.contract_id;
    END''',
  r'''CREATE TRIGGER deduction_audit_no_update
    BEFORE UPDATE ON statement_deduction_audit
    BEGIN SELECT RAISE(ABORT,'deduction audit is immutable'); END''',
  r'''CREATE TRIGGER deduction_audit_no_delete
    BEFORE DELETE ON statement_deduction_audit
    BEGIN SELECT RAISE(ABORT,'deduction audit is immutable'); END''',
  r'''CREATE TRIGGER deduction_detail_no_update
    BEFORE UPDATE ON statement_deduction_lines
    BEGIN SELECT RAISE(ABORT,'replace detailed deductions in transaction'); END''',
  r'''CREATE TRIGGER deduction_parent_total_guard
    BEFORE UPDATE OF deductions_rial ON statements
    WHEN EXISTS(SELECT 1 FROM statement_deduction_lines
      WHERE statement_id=OLD.id)
    BEGIN
      SELECT RAISE(ABORT,'statement deductions must match detail')
      WHERE NEW.deductions_rial !=
        (SELECT COALESCE(SUM(amount_rial),0)
          FROM statement_deduction_lines WHERE statement_id=OLD.id);
    END''',
  r'''CREATE TRIGGER deduction_audit_referential_guard
    BEFORE DELETE ON statements
    WHEN EXISTS (SELECT 1 FROM statement_deduction_audit
      WHERE statement_id=OLD.id)
    BEGIN SELECT RAISE(ABORT,'statement has immutable deduction history'); END''',
];

Future<void> upgradeDeductionDatabase(
    Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 6 && newVersion >= 6) {
    for (final sql in deductionV6Sql) {
      await db.execute(sql);
    }
  }
}

import 'package:sqflite/sqflite.dart';

/// Additive v4 -> v5. Never rewrite original contracts/expenses/receipts.
const boqV5Sql = <String>[
  r'''CREATE TABLE boq_items (
    id INTEGER PRIMARY KEY,
    contract_id INTEGER NOT NULL REFERENCES contracts(id) ON DELETE RESTRICT,
    item_code TEXT NOT NULL CHECK(length(trim(item_code)) BETWEEN 1 AND 40),
    title TEXT NOT NULL CHECK(length(trim(title)) BETWEEN 1 AND 250),
    unit TEXT NOT NULL CHECK(length(trim(unit)) BETWEEN 1 AND 30),
    price_source TEXT NOT NULL DEFAULT '',
    planned_quantity_milli INTEGER NOT NULL
      CHECK(planned_quantity_milli BETWEEN 0 AND 1000000000000),
    unit_price_rial INTEGER NOT NULL CHECK(unit_price_rial > 0),
    coefficient_bp INTEGER NOT NULL DEFAULT 10000
      CHECK(coefficient_bp BETWEEN 1 AND 100000),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(contract_id,item_code)
  )''',
  r'''CREATE TABLE boq_measurements (
    id INTEGER PRIMARY KEY,
    contract_id INTEGER NOT NULL REFERENCES contracts(id) ON DELETE RESTRICT,
    item_id INTEGER NOT NULL REFERENCES boq_items(id) ON DELETE RESTRICT,
    quantity_milli INTEGER NOT NULL
      CHECK(quantity_milli BETWEEN -1000000000000 AND 1000000000000
        AND quantity_milli != 0),
    measured_at TEXT NOT NULL CHECK(length(measured_at)=10),
    document_ref TEXT NOT NULL CHECK(length(trim(document_ref)) BETWEEN 1 AND 100),
    note TEXT NOT NULL DEFAULT '',
    statement_id INTEGER REFERENCES statements(id) ON DELETE RESTRICT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )''',
  r'''CREATE TABLE boq_statement_lines (
    statement_id INTEGER NOT NULL REFERENCES statements(id) ON DELETE RESTRICT,
    item_id INTEGER NOT NULL REFERENCES boq_items(id) ON DELETE RESTRICT,
    quantity_milli INTEGER NOT NULL,
    unit_price_rial INTEGER NOT NULL CHECK(unit_price_rial > 0),
    coefficient_bp INTEGER NOT NULL CHECK(coefficient_bp BETWEEN 1 AND 100000),
    line_amount_rial INTEGER NOT NULL,
    PRIMARY KEY(statement_id,item_id)
  )''',
  'CREATE INDEX idx_boq_contract ON boq_items(contract_id,item_code)',
  'CREATE INDEX idx_measure_item ON boq_measurements(item_id,id)',
  'CREATE INDEX idx_measure_contract_pending ON boq_measurements(contract_id,statement_id)',
  r'''CREATE TRIGGER boq_item_lock_update
    BEFORE UPDATE ON boq_items
    WHEN EXISTS(SELECT 1 FROM boq_measurements WHERE item_id=OLD.id)
    BEGIN SELECT RAISE(ABORT,'measured boq item is immutable'); END''',
  r'''CREATE TRIGGER boq_item_lock_delete
    BEFORE DELETE ON boq_items
    WHEN EXISTS(SELECT 1 FROM boq_measurements WHERE item_id=OLD.id)
    BEGIN SELECT RAISE(ABORT,'cannot delete measured boq item'); END''',
  r'''CREATE TRIGGER boq_measure_insert_guard
    BEFORE INSERT ON boq_measurements BEGIN
      SELECT RAISE(ABORT,'cross-contract boq measurement')
      WHERE (SELECT contract_id FROM boq_items WHERE id=NEW.item_id)
          != NEW.contract_id;
      SELECT RAISE(ABORT,'negative cumulative quantity')
      WHERE (SELECT COALESCE(SUM(quantity_milli),0)
             FROM boq_measurements WHERE item_id=NEW.item_id)
            + NEW.quantity_milli < 0;
      SELECT RAISE(ABORT,'measurement must start unbilled')
      WHERE NEW.statement_id IS NOT NULL;
    END''',
  r'''CREATE TRIGGER boq_measure_update_guard
    BEFORE UPDATE ON boq_measurements BEGIN
      SELECT RAISE(ABORT,'measurement is append-only')
      WHERE NEW.contract_id!=OLD.contract_id
         OR NEW.item_id!=OLD.item_id
         OR NEW.quantity_milli!=OLD.quantity_milli
         OR NEW.measured_at!=OLD.measured_at
         OR NEW.document_ref!=OLD.document_ref
         OR NEW.note!=OLD.note;
      SELECT RAISE(ABORT,'cannot reassign billed measurement')
      WHERE OLD.statement_id IS NOT NULL
         OR NEW.statement_id IS NULL;
      SELECT RAISE(ABORT,'cross-contract billed measurement')
      WHERE (SELECT contract_id FROM statements WHERE id=NEW.statement_id)
         != OLD.contract_id;
      SELECT RAISE(ABORT,'only draft statement accepts measurements')
      WHERE (SELECT status FROM statements WHERE id=NEW.statement_id)
         != 'DRAFT';
    END''',
  r'''CREATE TRIGGER boq_measure_no_delete
    BEFORE DELETE ON boq_measurements
    BEGIN SELECT RAISE(ABORT,'measurement is append-only'); END''',
  r'''CREATE TRIGGER boq_statement_line_insert_guard
    BEFORE INSERT ON boq_statement_lines BEGIN
      SELECT RAISE(ABORT,'cross-contract boq statement line')
      WHERE (SELECT contract_id FROM boq_items WHERE id=NEW.item_id)
         != (SELECT contract_id FROM statements WHERE id=NEW.statement_id);
      SELECT RAISE(ABORT,'only draft accepts line')
      WHERE (SELECT status FROM statements WHERE id=NEW.statement_id)
         != 'DRAFT';
    END''',
  r'''CREATE TRIGGER boq_statement_line_no_update
    BEFORE UPDATE ON boq_statement_lines
    BEGIN SELECT RAISE(ABORT,'boq statement line is immutable'); END''',
  r'''CREATE TRIGGER boq_statement_line_no_delete
    BEFORE DELETE ON boq_statement_lines
    BEGIN SELECT RAISE(ABORT,'boq statement line is immutable'); END''',
  r'''CREATE TRIGGER boq_statement_gross_guard
    BEFORE UPDATE OF gross_rial ON statements
    WHEN EXISTS (SELECT 1 FROM boq_statement_lines WHERE statement_id=OLD.id)
    BEGIN SELECT RAISE(ABORT,'gross is locked to measured boq lines')
      WHERE NEW.gross_rial != OLD.gross_rial;
    END''',
  r'''CREATE TRIGGER boq_statement_approve_guard
    BEFORE UPDATE OF status ON statements
    WHEN NEW.status IN ('SUBMITTED','APPROVED')
      AND EXISTS (SELECT 1 FROM boq_statement_lines WHERE statement_id=OLD.id)
    BEGIN SELECT RAISE(ABORT,'boq lines do not reconcile to gross')
      WHERE (SELECT SUM(line_amount_rial) FROM boq_statement_lines
             WHERE statement_id=OLD.id) != OLD.gross_rial;
    END''',
];

Future<void> upgradeBoqDatabase(
    Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 5 && newVersion >= 5) {
    for (final sql in boqV5Sql) {
      await db.execute(sql);
    }
  }
}

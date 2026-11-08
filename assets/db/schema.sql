-- Schema for NEW offline Android app. Reconstructed from verified requirements of the older
-- Saba Contracting project; NOT a copy of its inaccessible v0.2 code.
-- Storage: rial INTEGER, dates ISO 8601 (Gregorian); display Jalali in the app.
PRAGMA foreign_keys = ON;
PRAGMA user_version = 1;

CREATE TABLE companies (
 id INTEGER PRIMARY KEY,
 name TEXT NOT NULL CHECK(length(trim(name)) > 0),
 national_id TEXT,
 registration_no TEXT,
 economic_code TEXT,
 phone TEXT,
 address TEXT,
 logo_relative_path TEXT,
 created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE parties (
 id INTEGER PRIMARY KEY,
 company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
 full_name TEXT NOT NULL CHECK(length(trim(full_name)) > 0),
 type TEXT NOT NULL CHECK(type IN ('PERSON','COMPANY')),
 national_id TEXT,
 phone TEXT,
 notes TEXT
);
CREATE TABLE contracts (
 id INTEGER PRIMARY KEY,
 company_id INTEGER NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
 contract_no TEXT NOT NULL,
 title TEXT NOT NULL CHECK(length(trim(title)) > 0),
 employer_party_id INTEGER NOT NULL REFERENCES parties(id) ON DELETE RESTRICT,
 contractor_party_id INTEGER NOT NULL REFERENCES parties(id) ON DELETE RESTRICT,
 start_date TEXT NOT NULL,
 end_date TEXT,
 amount_rial INTEGER NOT NULL CHECK(amount_rial >= 0),
 location TEXT,
 scope_of_work TEXT,
 status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('DRAFT','ACTIVE','SUSPENDED','FINISHED','CANCELLED')),
 notes TEXT,
 created_at TEXT NOT NULL DEFAULT (datetime('now')),
 UNIQUE(company_id, contract_no),
 CHECK(end_date IS NULL OR end_date >= start_date)
);
CREATE TABLE activities (
 id INTEGER PRIMARY KEY,
 contract_id INTEGER NOT NULL REFERENCES contracts(id) ON DELETE CASCADE,
 title TEXT NOT NULL,
 planned_date TEXT,
 completed_date TEXT,
 progress_percent INTEGER NOT NULL DEFAULT 0 CHECK(progress_percent BETWEEN 0 AND 100),
 status TEXT NOT NULL DEFAULT 'PLANNED' CHECK(status IN ('PLANNED','IN_PROGRESS','DONE','CANCELLED')),
 note TEXT
);
CREATE TABLE expenses (
 id INTEGER PRIMARY KEY,
 contract_id INTEGER NOT NULL REFERENCES contracts(id) ON DELETE RESTRICT,
 activity_id INTEGER REFERENCES activities(id) ON DELETE SET NULL,
 expense_date TEXT NOT NULL,
 category TEXT NOT NULL,
 amount_rial INTEGER NOT NULL CHECK(amount_rial > 0),
 supplier_party_id INTEGER REFERENCES parties(id) ON DELETE RESTRICT,
 memo TEXT,
 created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE payments (
 id INTEGER PRIMARY KEY,
 contract_id INTEGER NOT NULL REFERENCES contracts(id) ON DELETE RESTRICT,
 payment_date TEXT NOT NULL,
 amount_rial INTEGER NOT NULL CHECK(amount_rial > 0),
 payee_party_id INTEGER REFERENCES parties(id) ON DELETE RESTRICT,
 payment_method TEXT,
 memo TEXT
);
CREATE TABLE receipts (
 id INTEGER PRIMARY KEY,
 contract_id INTEGER NOT NULL REFERENCES contracts(id) ON DELETE RESTRICT,
 receipt_date TEXT NOT NULL,
 amount_rial INTEGER NOT NULL CHECK(amount_rial > 0),
 payer_party_id INTEGER REFERENCES parties(id) ON DELETE RESTRICT,
 payment_method TEXT,
 memo TEXT
);
CREATE TABLE statements (
 id INTEGER PRIMARY KEY,
 contract_id INTEGER NOT NULL REFERENCES contracts(id) ON DELETE RESTRICT,
 statement_no TEXT NOT NULL,
 statement_date TEXT NOT NULL,
 gross_rial INTEGER NOT NULL CHECK(gross_rial >= 0),
 vat_rial INTEGER NOT NULL DEFAULT 0 CHECK(vat_rial >= 0),
 deductions_rial INTEGER NOT NULL DEFAULT 0 CHECK(deductions_rial >= 0),
 status TEXT NOT NULL DEFAULT 'DRAFT' CHECK(status IN ('DRAFT','SUBMITTED','APPROVED','REJECTED')),
 description TEXT,
 UNIQUE(contract_id,statement_no),
 CHECK(deductions_rial <= gross_rial + vat_rial)
);
-- One outgoing payment may settle several expenses, and vice versa.
CREATE TABLE expense_payment_allocations (
 expense_id INTEGER NOT NULL REFERENCES expenses(id) ON DELETE RESTRICT,
 payment_id INTEGER NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
 amount_rial INTEGER NOT NULL CHECK(amount_rial > 0),
 PRIMARY KEY(expense_id,payment_id)
);
-- One incoming receipt may settle several approved statements, and vice versa.
CREATE TABLE statement_receipt_allocations (
 statement_id INTEGER NOT NULL REFERENCES statements(id) ON DELETE RESTRICT,
 receipt_id INTEGER NOT NULL REFERENCES receipts(id) ON DELETE RESTRICT,
 amount_rial INTEGER NOT NULL CHECK(amount_rial > 0),
 PRIMARY KEY(statement_id,receipt_id)
);
CREATE TABLE attachments (
 id INTEGER PRIMARY KEY,
 contract_id INTEGER NOT NULL REFERENCES contracts(id) ON DELETE CASCADE,
 document_kind TEXT NOT NULL CHECK(document_kind IN ('CONTRACT','EXPENSE','PAYMENT','RECEIPT','STATEMENT','ACTIVITY','OTHER')),
 document_record_id INTEGER,
 relative_path TEXT NOT NULL,
 original_name TEXT NOT NULL,
 content_sha256 TEXT,
 created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE reminders (
 id INTEGER PRIMARY KEY,
 contract_id INTEGER REFERENCES contracts(id) ON DELETE CASCADE,
 title TEXT NOT NULL,
 due_at TEXT NOT NULL,
 is_done INTEGER NOT NULL DEFAULT 0 CHECK(is_done IN (0,1))
);
-- Cross-contract and over-allocation guards for payment settlement.
CREATE TRIGGER epa_insert_guard BEFORE INSERT ON expense_payment_allocations
BEGIN
 SELECT RAISE(ABORT,'cross-contract expense payment') WHERE
   (SELECT contract_id FROM expenses WHERE id=NEW.expense_id) !=
   (SELECT contract_id FROM payments WHERE id=NEW.payment_id);
 SELECT RAISE(ABORT,'expense allocation exceeds amount') WHERE
   (SELECT COALESCE(SUM(amount_rial),0) FROM expense_payment_allocations WHERE expense_id=NEW.expense_id)
   + NEW.amount_rial > (SELECT amount_rial FROM expenses WHERE id=NEW.expense_id);
 SELECT RAISE(ABORT,'payment allocation exceeds amount') WHERE
   (SELECT COALESCE(SUM(amount_rial),0) FROM expense_payment_allocations WHERE payment_id=NEW.payment_id)
   + NEW.amount_rial > (SELECT amount_rial FROM payments WHERE id=NEW.payment_id);
END;
CREATE TRIGGER epa_update_guard BEFORE UPDATE ON expense_payment_allocations
BEGIN
 SELECT RAISE(ABORT,'cross-contract expense payment') WHERE
   (SELECT contract_id FROM expenses WHERE id=NEW.expense_id) !=
   (SELECT contract_id FROM payments WHERE id=NEW.payment_id);
 SELECT RAISE(ABORT,'expense allocation exceeds amount') WHERE
   (SELECT COALESCE(SUM(amount_rial),0) FROM expense_payment_allocations WHERE expense_id=NEW.expense_id AND NOT (expense_id=OLD.expense_id AND payment_id=OLD.payment_id))
   + NEW.amount_rial > (SELECT amount_rial FROM expenses WHERE id=NEW.expense_id);
 SELECT RAISE(ABORT,'payment allocation exceeds amount') WHERE
   (SELECT COALESCE(SUM(amount_rial),0) FROM expense_payment_allocations WHERE payment_id=NEW.payment_id AND NOT (expense_id=OLD.expense_id AND payment_id=OLD.payment_id))
   + NEW.amount_rial > (SELECT amount_rial FROM payments WHERE id=NEW.payment_id);
END;
CREATE TRIGGER sra_insert_guard BEFORE INSERT ON statement_receipt_allocations
BEGIN
 SELECT RAISE(ABORT,'cross-contract statement receipt') WHERE
  (SELECT contract_id FROM statements WHERE id=NEW.statement_id) !=
  (SELECT contract_id FROM receipts WHERE id=NEW.receipt_id);
 SELECT RAISE(ABORT,'only approved statements may be settled') WHERE
  (SELECT status FROM statements WHERE id=NEW.statement_id) != 'APPROVED';
 SELECT RAISE(ABORT,'statement allocation exceeds net payable') WHERE
  (SELECT COALESCE(SUM(amount_rial),0) FROM statement_receipt_allocations WHERE statement_id=NEW.statement_id)
  + NEW.amount_rial > (SELECT gross_rial+vat_rial-deductions_rial FROM statements WHERE id=NEW.statement_id);
 SELECT RAISE(ABORT,'receipt allocation exceeds amount') WHERE
  (SELECT COALESCE(SUM(amount_rial),0) FROM statement_receipt_allocations WHERE receipt_id=NEW.receipt_id)
  + NEW.amount_rial > (SELECT amount_rial FROM receipts WHERE id=NEW.receipt_id);
END;
CREATE TRIGGER sra_update_guard BEFORE UPDATE ON statement_receipt_allocations
BEGIN
 SELECT RAISE(ABORT,'cross-contract statement receipt') WHERE
  (SELECT contract_id FROM statements WHERE id=NEW.statement_id) !=
  (SELECT contract_id FROM receipts WHERE id=NEW.receipt_id);
 SELECT RAISE(ABORT,'only approved statements may be settled') WHERE
  (SELECT status FROM statements WHERE id=NEW.statement_id) != 'APPROVED';
 SELECT RAISE(ABORT,'statement allocation exceeds net payable') WHERE
  (SELECT COALESCE(SUM(amount_rial),0) FROM statement_receipt_allocations WHERE statement_id=NEW.statement_id AND NOT (statement_id=OLD.statement_id AND receipt_id=OLD.receipt_id))
  + NEW.amount_rial > (SELECT gross_rial+vat_rial-deductions_rial FROM statements WHERE id=NEW.statement_id);
 SELECT RAISE(ABORT,'receipt allocation exceeds amount') WHERE
  (SELECT COALESCE(SUM(amount_rial),0) FROM statement_receipt_allocations WHERE receipt_id=NEW.receipt_id AND NOT (statement_id=OLD.statement_id AND receipt_id=OLD.receipt_id))
  + NEW.amount_rial > (SELECT amount_rial FROM receipts WHERE id=NEW.receipt_id);
END;
-- Existing allocations cannot be invalidated by shrinking or moving parent records.
CREATE TRIGGER expense_alloc_parent_guard BEFORE UPDATE OF amount_rial,contract_id ON expenses
BEGIN
 SELECT RAISE(ABORT,'expense smaller than allocated') WHERE NEW.amount_rial <
 (SELECT COALESCE(SUM(amount_rial),0) FROM expense_payment_allocations WHERE expense_id=OLD.id);
 SELECT RAISE(ABORT,'cannot move settled expense') WHERE NEW.contract_id != OLD.contract_id
 AND EXISTS (SELECT 1 FROM expense_payment_allocations WHERE expense_id=OLD.id);
END;
CREATE TRIGGER payment_alloc_parent_guard BEFORE UPDATE OF amount_rial,contract_id ON payments
BEGIN
 SELECT RAISE(ABORT,'payment smaller than allocated') WHERE NEW.amount_rial <
 (SELECT COALESCE(SUM(amount_rial),0) FROM expense_payment_allocations WHERE payment_id=OLD.id);
 SELECT RAISE(ABORT,'cannot move allocated payment') WHERE NEW.contract_id != OLD.contract_id
 AND EXISTS (SELECT 1 FROM expense_payment_allocations WHERE payment_id=OLD.id);
END;
CREATE TRIGGER statement_alloc_parent_guard BEFORE UPDATE OF gross_rial,vat_rial,deductions_rial,contract_id,status ON statements
BEGIN
 SELECT RAISE(ABORT,'statement smaller than allocated') WHERE NEW.gross_rial+NEW.vat_rial-NEW.deductions_rial <
 (SELECT COALESCE(SUM(amount_rial),0) FROM statement_receipt_allocations WHERE statement_id=OLD.id);
 SELECT RAISE(ABORT,'cannot move settled statement') WHERE NEW.contract_id != OLD.contract_id
 AND EXISTS (SELECT 1 FROM statement_receipt_allocations WHERE statement_id=OLD.id);
 SELECT RAISE(ABORT,'cannot unapprove settled statement') WHERE NEW.status!='APPROVED'
 AND EXISTS (SELECT 1 FROM statement_receipt_allocations WHERE statement_id=OLD.id);
END;
CREATE TRIGGER receipt_alloc_parent_guard BEFORE UPDATE OF amount_rial,contract_id ON receipts
BEGIN
 SELECT RAISE(ABORT,'receipt smaller than allocated') WHERE NEW.amount_rial <
 (SELECT COALESCE(SUM(amount_rial),0) FROM statement_receipt_allocations WHERE receipt_id=OLD.id);
 SELECT RAISE(ABORT,'cannot move allocated receipt') WHERE NEW.contract_id != OLD.contract_id
 AND EXISTS (SELECT 1 FROM statement_receipt_allocations WHERE receipt_id=OLD.id);
END;

CREATE INDEX idx_contracts_company ON contracts(company_id);
CREATE INDEX idx_activities_contract ON activities(contract_id);
CREATE INDEX idx_expenses_contract_date ON expenses(contract_id,expense_date);
CREATE INDEX idx_payments_contract_date ON payments(contract_id,payment_date);
CREATE INDEX idx_receipts_contract_date ON receipts(contract_id,receipt_date);
CREATE INDEX idx_statements_contract_status ON statements(contract_id,status);
CREATE INDEX idx_reminders_date ON reminders(due_at,is_done);

CREATE VIEW v_contract_financial_summary AS
SELECT c.id AS contract_id, c.contract_no, c.title,
       c.amount_rial AS contract_amount_rial,
       COALESCE((SELECT SUM(e.amount_rial) FROM expenses e WHERE e.contract_id=c.id),0) AS cost_rial,
       COALESCE((SELECT SUM(p.amount_rial) FROM payments p WHERE p.contract_id=c.id),0) AS paid_rial,
       COALESCE((SELECT SUM(r.amount_rial) FROM receipts r WHERE r.contract_id=c.id),0) AS received_rial,
       COALESCE((SELECT SUM(s.gross_rial) FROM statements s WHERE s.contract_id=c.id AND s.status='APPROVED'),0) AS approved_work_rial,
       COALESCE((SELECT SUM(s.gross_rial+s.vat_rial-s.deductions_rial)
                 FROM statements s WHERE s.contract_id=c.id AND s.status='APPROVED'),0) AS approved_net_payable_rial,
       COALESCE((SELECT SUM(s.gross_rial) FROM statements s WHERE s.contract_id=c.id AND s.status='APPROVED'),0)
       - COALESCE((SELECT SUM(e.amount_rial) FROM expenses e WHERE e.contract_id=c.id),0) AS provisional_margin_rial,
       COALESCE((SELECT SUM(r.amount_rial) FROM receipts r WHERE r.contract_id=c.id),0)
       - COALESCE((SELECT SUM(p.amount_rial) FROM payments p WHERE p.contract_id=c.id),0) AS cash_flow_rial
FROM contracts c;

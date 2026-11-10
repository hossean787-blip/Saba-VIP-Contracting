import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/finance/receivables_model.dart';

void main() {
  const statement = StatementBalance(
      id: 1,
      number: 'S-01',
      date: '2026-01-01',
      status: 'APPROVED',
      netRial: 1200000,
      allocatedRial: 200000);
  const receipt = ReceiptBalance(
      id: 5,
      date: '2026-02-01',
      categoryCode: 'statement_collection',
      payer: 'کارفرما',
      reference: 'BANK-01',
      amountRial: 800000,
      allocatedRial: 300000);

  test('report splits claims, assigned cash and unallocated receipts', () {
    const pending = StatementBalance(
        id: 2,
        number: 'S-02',
        date: '2026-02-01',
        status: 'SUBMITTED',
        netRial: 2000000,
        allocatedRial: 0);
    const advance = ReceiptBalance(
        id: 6,
        date: '2026-02-01',
        categoryCode: 'contract_advance',
        payer: 'کارفرما',
        reference: 'BANK-02',
        amountRial: 900000,
        allocatedRial: 0);
    const data = ReceivablesSnapshot(
      statements: [statement, pending],
      receipts: [receipt, advance],
      allocations: [],
      audit: [],
    );
    expect(data.approvedNetRial, 1200000);
    expect(data.allocatedRial, 200000);
    expect(data.outstandingRial, 1000000);
    expect(data.unallocatedReceiptsRial, 1400000);
    expect(data.selectableReceipts.length, 1);
    expect(data.selectableReceipts.single.id, receipt.id);
  });

  test('allocations validate both available balances', () {
    expect(
      () => validateStatementAllocation(
          statement: statement, receipt: receipt, amountRial: 500000),
      returnsNormally,
    );
    expect(
      () => validateStatementAllocation(
          statement: statement, receipt: receipt, amountRial: 500001),
      throwsArgumentError,
    );
    expect(
      () => validateStatementAllocation(
          statement: statement, receipt: receipt, amountRial: 0),
      throwsArgumentError,
    );
    expect(
      () => validateStatementAllocation(
          statement: const StatementBalance(
              id: 7,
              number: 'S-07',
              date: '2026-04-01',
              status: 'SUBMITTED',
              netRial: 600000,
              allocatedRial: 0),
          receipt: receipt,
          amountRial: 100),
      throwsStateError,
    );
  });

  test('contract advances cannot be linked as statement collection', () {
    const advance = ReceiptBalance(
        id: 8,
        date: '2026-01-01',
        categoryCode: 'contract_advance',
        payer: 'کارفرما',
        reference: 'ADV',
        amountRial: 200000,
        allocatedRial: 0);
    expect(advance.eligible, false);
    expect(
      () => validateStatementAllocation(
          statement: statement, receipt: advance, amountRial: 100),
      throwsStateError,
    );
  });

  test('30-day alert is informational and only for approved unpaid', () {
    expect(statement.needsReviewOn(DateTime(2026, 1, 30)), false);
    expect(statement.needsReviewOn(DateTime(2026, 1, 31)), true);
    const fullyPaid = StatementBalance(
        id: 9,
        number: 'S-09',
        date: '2026-01-01',
        status: 'APPROVED',
        netRial: 200000,
        allocatedRial: 200000);
    expect(fullyPaid.needsReviewOn(DateTime(2026, 12, 1)), false);
  });

  test('all valid receipt categories are narrow and explicit', () {
    expect(eligibleReceiptCategoriesForStatements.contains('statement_collection'), true);
    expect(eligibleReceiptCategoriesForStatements.contains('retention_release'), true);
    expect(eligibleReceiptCategoriesForStatements.contains('other'), false);
    expect(eligibleReceiptCategoriesForStatements.contains('reimbursement'), false);
  });
}

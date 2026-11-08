import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/finance/finance_kind.dart';
void main(){
  test('different finance tabs never mix cash and accrual records',(){
    expect(FinanceArea.outflows.kinds,[FinanceKind.expenses,FinanceKind.payments]);
    expect(FinanceArea.inflows.kinds,[FinanceKind.receipts,FinanceKind.statements]);
    expect(FinanceKind.receipts.amountField,'amount_rial');
    expect(FinanceKind.statements.amountField,'gross_rial');
    expect(FinanceKind.values.map((x)=>x.table).toSet(),
      {'expenses','payments','receipts','statements'});
  });
}

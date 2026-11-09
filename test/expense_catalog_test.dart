import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/finance/expense_catalog.dart';

void main() {
  test('unique categories', () {
    expect(expenseCategories.map((x) => x.code).toSet().length,
        expenseCategories.length);
    expect(expenseCategories.length, greaterThanOrEqualTo(15));
  });
  test('salary needs identified person', () {
    expect(
        const ExpenseDetail(
                categoryCode: 'salary',
                detailTitle: '',
                counterpartyName: 'شرکت')
            .validate(),
        isNotNull);
    expect(
        const ExpenseDetail(
                categoryCode: 'salary',
                detailTitle: 'سارا',
                counterpartyName: '')
            .validate(),
        isNull);
  });
  test('rental requires equipment or owner', () {
    expect(
        const ExpenseDetail(
                categoryCode: 'equipment_rental',
                detailTitle: '',
                counterpartyName: '')
            .validate(),
        isNotNull);
    expect(
        const ExpenseDetail(
                categoryCode: 'equipment_rental',
                detailTitle: 'دوربین',
                counterpartyName: '')
            .validate(),
        isNull);
    expect(
        const ExpenseDetail(
                categoryCode: 'equipment_rental',
                detailTitle: '',
                counterpartyName: 'اجاره‌دهنده')
            .validate(),
        isNull);
  });
  test('other must have description', () {
    expect(
        const ExpenseDetail(
                categoryCode: 'other', detailTitle: '', counterpartyName: 'شخص')
            .validate(),
        isNotNull);
    expect(
        const ExpenseDetail(
                categoryCode: 'unknown',
                detailTitle: 'شرح',
                counterpartyName: '')
            .validate(),
        isNotNull);
  });
}

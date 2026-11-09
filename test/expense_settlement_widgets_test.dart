import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/core/theme.dart';
import 'package:saba_vip_contracting/data/offline_store.dart';
import 'package:saba_vip_contracting/finance/expense_catalog.dart';
import 'package:saba_vip_contracting/screens/entry_sheet.dart';
import 'package:saba_vip_contracting/screens/expense_payment_sheet.dart';
import 'package:saba_vip_contracting/widgets/expense_payment_status.dart';

class PaymentStore extends Fake implements OfflineStore {
  final pending = Completer<int>();
  final paid = <int>[];
  final pendingExpense = Completer<int>();
  final expenses = <({
    int contractId,
    int amountRial,
    int paidRial,
    ExpenseDetail detail
  })>[];

  @override
  Future<int> addExpenseWithPayment(
    int contractId, {
    required int amountRial,
    required String date,
    required ExpenseDetail expenseDetail,
    int paidRial = 0,
    String? memo,
  }) {
    expenses.add((
      contractId: contractId,
      amountRial: amountRial,
      paidRial: paidRial,
      detail: expenseDetail
    ));
    return pendingExpense.future;
  }

  @override
  Future<int> addExpensePayment(
    int contractId,
    int expenseId, {
    required int amountRial,
    required String date,
    String? memo,
  }) {
    expect(contractId, 7);
    expect(expenseId, 9);
    paid.add(amountRial);
    return pending.future;
  }
}

Widget harness(Widget sheet) => MaterialApp(
      theme: vipTheme(),
      home: Scaffold(
          body: Builder(
              builder: (context) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.5)),
                    child: Directionality(
                        textDirection: TextDirection.rtl, child: sheet),
                  ))),
    );

Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label);

Future<void> select(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> fillExpense(WidgetTester tester, PaymentStore store) async {
  await tester.pumpWidget(
      harness(EntrySheet(store: store, contractId: 7, kind: 'expenses')));
  final category = find.byType(DropdownButtonFormField<String>);
  await tester.tap(category);
  await tester.pumpAndSettle();
  await tester.tap(find.text('حقوق کارکنان').last);
  await tester.pumpAndSettle();
  await tester.enterText(field('نام و نام خانوادگی شخص *'), 'علی محمدی');
  await tester.enterText(field('طرف حساب (در صورت تفاوت با شخص)'), 'شرکت صبا');
  await tester.enterText(field('مبلغ (تومان) *'), '100000');
  await tester.pumpAndSettle();
}

void main() {
  for (final scenario
      in {'unpaid': 0, 'full': 1000000, 'partial': 400000}.entries) {
    testWidgets(
        'expense save persists ${scenario.key} payment and contract detail',
        (tester) async {
      final store = PaymentStore();
      await fillExpense(tester, store);
      if (scenario.key != 'unpaid') {
        await select(tester, 'ثبت پرداخت برای این هزینه');
      }
      if (scenario.key == 'partial') {
        await select(tester, 'پرداخت جزئی');
        await tester.enterText(field('مبلغ پرداخت‌شده (تومان) *'), '40000');
      }
      await select(tester, 'ذخیره');
      expect(store.expenses, hasLength(1));
      final expense = store.expenses.single;
      expect(expense.contractId, 7);
      expect(expense.amountRial, 1000000);
      expect(expense.paidRial, scenario.value);
      expect(expense.detail.categoryCode, 'salary');
      expect(expense.detail.detailTitle, 'علی محمدی');
      expect(expense.detail.counterpartyName, 'شرکت صبا');
      expect(store.paid, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.pendingExpense.complete(1);
      await tester.pump();
    });
  }

  testWidgets(
      'invalid initial partial payments never reach expense persistence',
      (tester) async {
    final store = PaymentStore();
    await fillExpense(tester, store);
    await select(tester, 'ثبت پرداخت برای این هزینه');
    await select(tester, 'پرداخت جزئی');
    for (final invalid in ['0', '-1', '100000', '100001']) {
      await tester.enterText(field('مبلغ پرداخت‌شده (تومان) *'), invalid);
      await select(tester, 'ذخیره');
      expect(store.expenses, isEmpty);
      expect(store.paid, isEmpty);
      expect(find.text('مبلغ جزئی باید مثبت و کمتر از هزینه باشد.'),
          findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'RTL narrow expense form previews unpaid full and partial balances',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness(
        EntrySheet(store: PaymentStore(), contractId: 7, kind: 'expenses')));
    await tester.enterText(field('مبلغ (تومان) *'), '100000');
    await tester.pumpAndSettle();
    ExpensePaymentStatus status() =>
        tester.widget<ExpensePaymentStatus>(find.byType(ExpensePaymentStatus));
    expect(status().expenseRial, 1000000);
    expect(status().paidRial, 0);
    expect(Directionality.of(tester.element(find.byType(EntrySheet))),
        TextDirection.rtl);
    await select(tester, 'ثبت پرداخت برای این هزینه');
    expect(status().paidRial, 1000000);
    await select(tester, 'پرداخت جزئی');
    await tester.enterText(field('مبلغ پرداخت‌شده (تومان) *'), '40000');
    await tester.pumpAndSettle();
    expect(status().paidRial, 400000);
    await tester.enterText(field('مبلغ (تومان) *'), '30000');
    await tester.pumpAndSettle();
    expect(find.byType(ExpensePaymentStatus), findsNothing);
    expect(
        find.text('مبلغ جزئی باید مثبت و کمتر از هزینه باشد.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial boundaries show feedback without saving',
      (tester) async {
    await tester.pumpWidget(harness(
        EntrySheet(store: PaymentStore(), contractId: 7, kind: 'expenses')));
    await tester.enterText(field('مبلغ (تومان) *'), '100000');
    await select(tester, 'ثبت پرداخت برای این هزینه');
    await select(tester, 'پرداخت جزئی');
    for (final invalid in ['0', '-1', '100000', '100001']) {
      await tester.enterText(field('مبلغ پرداخت‌شده (تومان) *'), invalid);
      await tester.pumpAndSettle();
      expect(find.byType(ExpensePaymentStatus), findsNothing);
      expect(find.text('مبلغ جزئی باید مثبت و کمتر از هزینه باشد.'),
          findsOneWidget);
    }
    await select(tester, 'ثبت پرداخت برای این هزینه');
    expect(
        tester
            .widget<ExpensePaymentStatus>(find.byType(ExpensePaymentStatus))
            .paidRial,
        0);
    expect(field('مبلغ پرداخت‌شده (تومان) *'), findsNothing);
  });

  testWidgets(
      'exact one rial remainder submits once with original expense link',
      (tester) async {
    final store = PaymentStore();
    await tester.pumpWidget(harness(ExpensePaymentSheet(
        store: store, contractId: 7, expenseId: 9, remainingRial: 1)));
    await select(tester, 'تسویه دقیق تمام مانده');
    expect(field('مبلغ پرداخت (تومان) *'), findsNothing);
    final button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'ثبت پرداخت'));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(store.paid, [1]);
    expect(tester.takeException(), isNull);
    // Remove the sheet before resolving the mocked write: no navigation is needed.
    await tester.pumpWidget(const SizedBox());
    store.pending.complete(1);
    await tester.pump();
  });
}

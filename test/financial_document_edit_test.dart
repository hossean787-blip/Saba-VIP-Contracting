import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/data/offline_store.dart';
import 'package:saba_vip_contracting/finance/expense_catalog.dart';
import 'package:saba_vip_contracting/finance/receipt_catalog.dart';
import 'package:saba_vip_contracting/screens/entry_sheet.dart';

class EditStore extends Fake implements OfflineStore {
  final pending = Completer<int>();
  final updates = <String, int>{};

  @override
  Future<int> updateExpense(int contractId, int expenseId,
      {required int amountRial,
      required String date,
      required ExpenseDetail expenseDetail,
      String? memo}) {
    expect(contractId, 7);
    expect(expenseId, 9);
    expect(expenseDetail.categoryCode, 'salary');
    updates['expense'] = amountRial;
    return pending.future;
  }

  @override
  Future<int> updateReceipt(int contractId, int receiptId,
      {required int amountRial,
      required String date,
      required ReceiptDetail receiptDetail,
      String? memo}) {
    expect(contractId, 7);
    expect(receiptId, 9);
    expect(receiptDetail.payerName, 'کارفرمای نمونه');
    updates['receipt'] = amountRial;
    return pending.future;
  }

  @override
  Future<int> updateStatement(int contractId, int statementId,
      {required String number,
      required String date,
      required int grossRial,
      required int vatRial,
      required int deductionsRial,
      required String status,
      String description = ''}) {
    expect(contractId, 7);
    expect(statementId, 9);
    expect(number, '03');
    expect(vatRial, 0);
    expect(deductionsRial, 0);
    updates['statement'] = grossRial;
    return pending.future;
  }
}

Widget editing(Widget sheet) => MaterialApp(
    home: Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: sheet,
      ),
    ));

Future<void> saveEdit(WidgetTester tester) async {
  final button = find.text('ثبت ویرایش');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  final expense = <String, Object?>{
    'id': 9,
    'contract_id': 7,
    'expense_date': '2026-11-09',
    'category': 'حقوق کارکنان',
    'category_code': 'salary',
    'detail_title': 'علی محمدی',
    'counterparty_name': 'شرکت',
    'amount_rial': 1000000,
    'allocated_paid_rial': 400000,
    'memo': 'حقوق آبان',
  };

  testWidgets('expense edit preserves paid allocation and hides new-payment checkbox',
      (tester) async {
    final store = EditStore();
    await tester.pumpWidget(editing(EntrySheet(
        store: store, contractId: 7, kind: 'expenses', previous: expense)));
    expect(find.text('ویرایش هزینه'), findsOneWidget);
    expect(find.text('ثبت پرداخت برای این هزینه'), findsNothing);
    await saveEdit(tester);
    expect(store.updates['expense'], 1000000);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.pending.complete(1);
    await tester.pump();
  });

  testWidgets('expense edit rejects value lower than allocated payments',
      (tester) async {
    final store = EditStore();
    await tester.pumpWidget(editing(EntrySheet(
        store: store, contractId: 7, kind: 'expenses', previous: expense)));
    final field = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'مبلغ (تومان) *');
    await tester.enterText(field, '30000');
    await saveEdit(tester);
    expect(find.text('مبلغ هزینه از پرداخت ثبت‌شده کمتر است'), findsOneWidget);
    expect(store.updates, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('receipt edit reuses saved payer/category and updates scoped record',
      (tester) async {
    final store = EditStore();
    await tester.pumpWidget(editing(EntrySheet(
      store: store,
      contractId: 7,
      kind: 'receipts',
      previous: {
        'id': 9,
        'receipt_date': '2026-11-09',
        'amount_rial': 1200000,
        'category_code': 'on_account',
        'detail_title': 'علی‌الحساب',
        'counterparty_name': 'کارفرمای نمونه',
        'payment_method': 'TRANSFER',
        'reference_no': '123',
      },
    )));
    await saveEdit(tester);
    expect(store.updates['receipt'], 1200000);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.pending.complete(1);
    await tester.pump();
  });

  testWidgets('statement edit preserves exact old rial remainder',
      (tester) async {
    final store = EditStore();
    await tester.pumpWidget(editing(EntrySheet(
      store: store,
      contractId: 7,
      kind: 'statements',
      previous: {
        'id': 9,
        'statement_no': '03',
        'statement_date': '2026-11-09',
        'gross_rial': 2000001,
        'vat_rial': 0,
        'deductions_rial': 0,
        'status': 'DRAFT',
      },
    )));
    expect(find.text('ویرایش صورت‌وضعیت'), findsOneWidget);
    await saveEdit(tester);
    expect(store.updates['statement'], 2000001);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.pending.complete(1);
    await tester.pump();
  });
}

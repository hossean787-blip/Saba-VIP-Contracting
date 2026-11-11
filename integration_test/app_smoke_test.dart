import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saba_vip_contracting/main.dart' as app;
import 'package:saba_vip_contracting/data/offline_store.dart';
import 'package:saba_vip_contracting/data/statement_deduction_store.dart';
import 'package:saba_vip_contracting/finance/deduction_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('install boots, saves company, opens privacy and backups',
      (tester) async {
    await app.main();
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Brand-new emulator has an empty seed; test the real SQLite write path.
    expect(find.text('مشخصات رسمی شرکت'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first,
        'شرکت آزمون پیمانکاری صبا');
    final saveCompany = find.text('ذخیره و ورود به داشبورد');
    await tester.ensureVisible(saveCompany);
    await tester.tap(saveCompany);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.byTooltip('اطلاعات شرکت'), findsOneWidget);

    await tester.tap(find.byTooltip('درباره برنامه و حریم خصوصی'));
    await tester.pumpAndSettle();
    expect(find.text('درباره برنامه و حریم خصوصی'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('پشتیبان‌گیری و بازیابی'));
    await tester.pumpAndSettle();
    expect(find.text('امنیت و پشتیبان‌گیری'), findsOneWidget);
    expect(find.text('ساخت نسخه پشتیبان'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('اطلاعات شرکت'), findsOneWidget);
  });

  testWidgets('real Android SQLite v6 stores categorized deductions safely',
      (tester) async {
    // Uses the actual sqflite Android plugin and upgraded bundled database.
    final store = await OfflineStore.open();
    final db = store.db;
    final companyId = await db.insert('companies', {
      'name': 'آزمون مستقل دفتر کسورات'
    });
    final employerId = await db.insert('parties', {
      'company_id': companyId,
      'full_name': 'کارفرمای آزمایشی',
      'type': 'COMPANY',
    });
    final contractorId = await db.insert('parties', {
      'company_id': companyId,
      'full_name': 'پیمانکار آزمایشی',
      'type': 'COMPANY',
    });
    final contractId = await db.insert('contracts', {
      'company_id': companyId,
      'contract_no': 'DED-RC2',
      'title': 'پروژه آزمون کسورات',
      'employer_party_id': employerId,
      'contractor_party_id': contractorId,
      'start_date': '2026-11-01',
      'amount_rial': 10000000,
    });
    final statementId = await db.insert('statements', {
      'contract_id': contractId,
      'statement_no': 'INT-001',
      'statement_date': '2026-11-10',
      'gross_rial': 1000000,
      'vat_rial': 0,
      'deductions_rial': 0,
      'status': 'APPROVED',
    });
    final receiptId = await db.insert('receipts', {
      'contract_id': contractId,
      'receipt_date': '2026-11-11',
      'amount_rial': 500000,
      'category_code': 'statement_collection',
      'detail_title': 'وصول کار تأییدشده',
      'counterparty_name': 'کارفرمای آزمایشی',
      'reference_no': 'BANK-001',
      'payment_method': 'TRANSFER',
    });
    await db.insert('statement_receipt_allocations', {
      'statement_id': statementId,
      'receipt_id': receiptId,
      'amount_rial': 400000,
    });
    await store.replaceStatementDeductions(
      companyId: companyId,
      contractId: contractId,
      statementId: statementId,
      lines: const [
        DeductionLine(
            kind: 'retention', amountRial: 100000, basisRef: 'بند ۱۰ پیمان'),
        DeductionLine(
            kind: 'insurance', amountRial: 200000, basisRef: 'نامه بیمه ۲۱'),
      ],
      reason: 'تفکیک مبالغ با مدارک پیمان',
    );
    final result = await store.statementDeductionSnapshot(
      companyId: companyId,
      contractId: contractId,
      statementId: statementId,
    );
    expect(result.totalDeductionsRial, 300000);
    expect(result.classifiedRial, 300000);
    expect(result.netPayableRial, 700000);
    expect(result.remainingReceivableRial, 300000);
    expect(result.revisions.single.previousRial, 0);
    expect(result.revisions.single.currentRial, 300000);

    await expectLater(
      store.replaceStatementDeductions(
        companyId: companyId,
        contractId: contractId,
        statementId: statementId,
        lines: const [
          DeductionLine(
              kind: 'retention', amountRial: 700001,
              basisRef: 'نامه اصلاحی ۹'),
        ],
        reason: 'آزمون جلوگیری از اضافه‌کسور',
      ),
      throwsStateError,
    );
    final unchanged = await store.statementDeductionSnapshot(
      companyId: companyId,
      contractId: contractId,
      statementId: statementId,
    );
    expect(unchanged.totalDeductionsRial, 300000);
    expect(unchanged.revisions.length, 1);
    final integrity = await db.rawQuery('PRAGMA integrity_check');
    expect(integrity.first.values.first, 'ok');
    final foreign = await db.rawQuery('PRAGMA foreign_key_check');
    expect(foreign, isEmpty);
  });
}

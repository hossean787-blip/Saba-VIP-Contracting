import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/finance/contracting_intelligence.dart';
import 'package:saba_vip_contracting/reports/report_model.dart';
import 'package:saba_vip_contracting/screens/contracting_center_screen.dart';

void main() {
  test('earned value uses COST budget and recognized cost, never receipts', () {
    final result = EarnedValueAssessment(
      costBudgetRial: 10000000,
      actualCostRial: 5000000,
      actualProgressPercent: 40,
      plannedProgressPercent: 50,
    );
    expect(result.earnedValueRial, 4000000);
    expect(result.plannedValueRial, 5000000);
    expect(result.costVarianceRial, -1000000);
    expect(result.scheduleVarianceRial, -1000000);
    expect(result.costPerformanceIndex, closeTo(.8, .000001));
    expect(result.schedulePerformanceIndex, closeTo(.8, .000001));
    expect(result.forecastCostAtCompletionRial, 12500000);
    expect(result.forecastVarianceRial, -2500000);
  });

  test('undefined CPI and SPI remain unknown instead of success', () {
    final zero = EarnedValueAssessment(
      costBudgetRial: 10000000,
      actualCostRial: 0,
      actualProgressPercent: 0,
      plannedProgressPercent: 0,
    );
    expect(zero.costPerformanceIndex, isNull);
    expect(zero.schedulePerformanceIndex, isNull);
    expect(zero.forecastCostAtCompletionRial, isNull);
    final spentWithoutProgress = EarnedValueAssessment(
      costBudgetRial: 10000000,
      actualCostRial: 1000000,
      actualProgressPercent: 0,
      plannedProgressPercent: 30,
    );
    expect(spentWithoutProgress.costPerformanceIndex, 0);
    expect(spentWithoutProgress.forecastCostAtCompletionRial, isNull);
  });

  test('huge budget preserves exact integer rial math', () {
    final value = EarnedValueAssessment(
      costBudgetRial: EarnedValueAssessment.maxRial,
      actualCostRial: 0,
      actualProgressPercent: 100,
      plannedProgressPercent: 100,
    );
    expect(value.earnedValueRial, EarnedValueAssessment.maxRial);
    expect(value.plannedValueRial, EarnedValueAssessment.maxRial);
  });

  test('invalid progress and budget are rejected', () {
    expect(
      () => EarnedValueAssessment(
        costBudgetRial: 0,
        actualCostRial: 0,
        actualProgressPercent: 20,
        plannedProgressPercent: 20,
      ),
      throwsArgumentError,
    );
    expect(
      () => EarnedValueAssessment(
        costBudgetRial: 2000,
        actualCostRial: 0,
        actualProgressPercent: 101,
        plannedProgressPercent: 20,
      ),
      throwsArgumentError,
    );
    expect(
      () => EarnedValueAssessment(
        costBudgetRial: 2000,
        actualCostRial: -1,
        actualProgressPercent: 20,
        plannedProgressPercent: 20,
      ),
      throwsArgumentError,
    );
  });

  test('cumulative interim statement calculates current period only', () {
    final value = InterimStatementAssessment(
      cumulativeGrossRial: 20000000,
      previousGrossRial: 12000000,
      periodVatRial: 800000,
      periodDeductionsRial: 100000,
    );
    expect(value.periodGrossRial, 8000000);
    expect(value.periodNetRial, 8700000);
  });

  test('negative, reversed, excessive and overflowing statements fail', () {
    expect(
      () => InterimStatementAssessment(
        cumulativeGrossRial: 100,
        previousGrossRial: 101,
        periodVatRial: 0,
        periodDeductionsRial: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => InterimStatementAssessment(
        cumulativeGrossRial: 100,
        previousGrossRial: 0,
        periodVatRial: 0,
        periodDeductionsRial: 101,
      ),
      throwsArgumentError,
    );
    expect(
      () => InterimStatementAssessment(
        cumulativeGrossRial: EarnedValueAssessment.maxRial,
        previousGrossRial: 0,
        periodVatRial: 1,
        periodDeductionsRial: 0,
      ),
      throwsArgumentError,
    );
  });

  test('offline reference cards have traceable public source links', () {
    expect(contractingReferences.length, greaterThanOrEqualTo(10));
    expect(contractingReferences.map((row) => row.topic).toSet().length,
        contractingReferences.length);
    for (final topic in contractingReferences) {
      expect(topic.summary, isNotEmpty);
      expect(topic.action, isNotEmpty);
      expect(Uri.tryParse(topic.url)?.scheme, 'https');
    }
  });

  testWidgets('contract-specific center exposes calculation and knowledge tabs',
      (tester) async {
    const report = ContractReport(
      companyName: 'آزمایشی',
      contractNo: '123',
      contractTitle: 'پروژه آزمایشی',
      employer: 'کارفرما',
      contractor: 'پیمانکار',
      contractAmountRial: 50000000,
      costRial: 12000000,
      paymentRial: 8000000,
      receiptRial: 6000000,
      approvedGrossRial: 15000000,
      approvedNetRial: 14500000,
      provisionalMarginRial: 3000000,
      cashFlowRial: -2000000,
      records: [],
    );
    await tester.pumpWidget(const MaterialApp(
        home: ContractingCenterScreen(report: report)));
    expect(find.text('مرکز تخصصی پیمان'), findsOneWidget);
    expect(find.text('کنترل پروژه'), findsOneWidget);
    expect(find.text('صورت‌وضعیت'), findsOneWidget);
    expect(find.text('دانشنامه'), findsOneWidget);
    expect(find.textContaining('هزینه شناسایی‌شده واقعی'), findsOneWidget);
  });
}

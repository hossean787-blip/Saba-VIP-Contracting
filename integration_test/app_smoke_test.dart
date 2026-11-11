import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saba_vip_contracting/main.dart' as app;

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
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saba_vip_contracting/widgets/ui.dart';

void main() {
  testWidgets('VIP empty-state renders correctly', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: EmptyView(
      title: 'قراردادی پیدا نشد',
      subtitle: 'قرارداد جدید ثبت کنید.',
    ))));
    expect(find.text('قراردادی پیدا نشد'), findsOneWidget);
    expect(find.text('قرارداد جدید ثبت کنید.'), findsOneWidget);
  });
}

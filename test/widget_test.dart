import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:third_intermediate_iraq/main.dart';

void main() {
  testWidgets('home screen loads', (tester) async {
    await tester.pumpWidget(const StudyApp());
    expect(find.text('دليلك للنجاح'), findsOneWidget);
    expect(find.text('الثالث متوسط • العراق'), findsOneWidget);
    expect(find.text('المواد الدراسية'), findsWidgets);
  });

  testWidgets('archive search screen loads and shows available archive results', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ArchiveSearchScreen()));
    expect(find.text('البحث في الأرشيف'), findsOneWidget);
    expect(find.textContaining('النتائج:'), findsOneWidget);
    expect(find.text('اللغة العربية'), findsWidgets);
    expect(find.text('الكيمياء'), findsWidgets);
  });

  testWidgets('archive search filters by subject', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ArchiveSearchScreen()));
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('الكيمياء').last);
    await tester.pumpAndSettle();
    expect(find.text('الكيمياء'), findsWidgets);
    expect(find.text('اللغة العربية'), findsNothing);
  });
}

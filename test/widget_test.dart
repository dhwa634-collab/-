// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:third_intermediate_iraq/student_tools.dart';
import 'package:third_intermediate_iraq/main.dart';

void main() {
  testWidgets('home screen loads', (tester) async {
    await tester.pumpWidget(const StudyApp());

    // The subjects catalog is intentionally displayed in its own bottom tab,
    // not on the home screen. Keep this test focused on the home screen.
    expect(find.text('دليلك للنجاح'), findsOneWidget);
    expect(find.text('الثالث متوسط • العراق'), findsOneWidget);
    expect(find.text('المساعد الذكي'), findsOneWidget);
    expect(find.text('ابدأ المحادثة الآن'), findsOneWidget);
  });

  testWidgets('subjects catalog scrolls from ministerial archive to review notes', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      home: Catalog(onOpen: (_) {}),
    ));

    expect(find.text('الأسئلة الوزارية للسنين السابقة'), findsOneWidget);
    expect(find.text('كتب المواد الدراسية'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1400));
    await tester.pumpAndSettle();

    expect(find.text('مفكرة المراجعة الخاصة بي'), findsOneWidget);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('study notes are saved locally for the selected subject', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: StudyNotesScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'قانون مهم للمراجعة');
    await tester.tap(find.text('حفظ الملاحظات'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('dalilak_subject_note_v1_التربية الإسلامية'),
      'قانون مهم للمراجعة');
  });

  testWidgets('archive search screen loads and shows available archive results', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ArchiveSearchScreen()));
    expect(find.text('البحث في الأرشيف'), findsOneWidget);
    expect(find.textContaining('النتائج:'), findsOneWidget);
    expect(find.text('اللغة العربية'), findsWidgets);
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

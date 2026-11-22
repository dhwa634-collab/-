// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:third_intermediate_iraq/main.dart';
import 'package:third_intermediate_iraq/student_tools.dart';
import 'package:third_intermediate_iraq/exam_archive_data.dart';
import 'package:third_intermediate_iraq/review_quiz.dart';

void main() {

  test('textbook catalog keeps eight books separate from six exam subjects', () {
    final bookNames = bookSubjects.map((book) => book.name).toSet();
    final examNames = subjects.map((subject) => subject.name).toSet();

    expect(bookSubjects, hasLength(8));
    expect(bookNames, containsAll([
      'اللغة العربية', 'التربية الإسلامية', 'اللغة الإنكليزية',
      'الاجتماعيات', 'الفيزياء', 'الكيمياء', 'الأحياء', 'الرياضيات',
    ]));
    expect(subjects, hasLength(7));
    expect(examNames, contains('الكيمياء'));
    expect(examNames, isNot(contains('التربية الإسلامية')));
    expect(bookSubjects.firstWhere((book) => book.name == 'اللغة الإنكليزية').availableParts, hasLength(2));
    expect(chemistryExams, isNotEmpty);
    expect(unclassifiedExamImages['الكيمياء'], isNotEmpty);

    // جميع الكتب لها مصدر PDF مهيأ داخل فهرس الكتب.
    for (final book in bookSubjects) {
      expect(book.hasPdf, isTrue, reason: book.name);
    }
    expect(
      bookSubjects.firstWhere((book) => book.name == 'اللغة العربية').availableParts,
      hasLength(2),
    );
    expect(
      bookSubjects.firstWhere((book) => book.name == 'اللغة الإنكليزية').hasPdf,
      isTrue,
    );
  });


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


  testWidgets('review quiz explains a wrong answer and reveals the correct one', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReviewQuizScreen()));
    await tester.tap(find.text('اللغة العربية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('النحو: الجملة الفعلية'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('مفعول به منصوب'));
    await tester.pumpAndSettle();

    expect(find.text('مو مشكلة، نتعلّم من الخطأ'), findsOneWidget);
    expect(find.text('الإجابة الصحيحة: فاعل مرفوع'), findsOneWidget);
    expect(find.textContaining('الطالبُ هو من قام بالفعل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('archive search includes chemistry as a separate subject', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ArchiveSearchScreen()));
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('الكيمياء'), findsWidgets);
  });

  testWidgets('study notes are saved locally for the selected subject', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: StudyNotesScreen()));
    await tester.pumpAndSettle();

    // Notes now use a separate editor with a title and a full body.
    await tester.tap(find.text('ملاحظة جديدة'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'قوانين الفصل الأول');
    await tester.enterText(fields.at(1), 'قانون مهم للمراجعة');
    // The editor's AppBar save action stays visible even when the
    // multiline body field extends below the viewport.
    await tester.tap(find.byTooltip('حفظ'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('dalilak_subject_notes_v2_اللغة العربية');
    expect(saved, isNotNull);
    expect(saved, contains('قوانين الفصل الأول'));
    expect(saved, contains('قانون مهم للمراجعة'));
  });

  testWidgets('saved screen shows a stable empty state and quick navigation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: Saved()));
    await tester.pumpAndSettle();

    expect(find.text('محفوظاتك بانتظارك'), findsOneWidget);
    expect(find.text('استكشاف المواد'), findsOneWidget);
    expect(find.text('فتح الأرشيف الوزاري'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved screen renders saved items even when the asset is missing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    SavedExamsStore.items.value = [
      {'path': 'assets/not_existing_exam.png', 'subject': 'الفيزياء',
       'year': '2025', 'round': 'الدور الأول'},
    ];
    await tester.pumpWidget(const MaterialApp(home: Saved()));
    await tester.pumpAndSettle();

    expect(find.text('أوراقي المحفوظة'), findsOneWidget);
    expect(find.text('الفيزياء'), findsOneWidget);
    expect(tester.takeException(), isNull);
    SavedExamsStore.items.value = [];
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
    await tester.tap(find.text('الفيزياء').last);
    await tester.pumpAndSettle();
    expect(find.text('الفيزياء'), findsWidgets);
    expect(find.text('اللغة العربية'), findsNothing);
  });
}

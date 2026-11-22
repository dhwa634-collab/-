// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

/// المراحل الدراسية المدعومة في التطبيق.
enum AcademicStage {
  primarySixth('السادس الابتدائي'),
  intermediateThird('الثالث المتوسط'),
  preparatorySixth('السادس الإعدادي');

  final String label;
  const AcademicStage(this.label);

  static AcademicStage fromStorage(String? value) =>
      AcademicStage.values.firstWhere(
        (stage) => stage.name == value,
        orElse: () => AcademicStage.intermediateThird,
      );
}

/// بيانات فهرس المواد للمرحلتين المضافتين.
/// لا تُضاف روابط أو أوراق وزارية غير موجودة وموثقة في المستودع.
class StageSubjectInfo {
  final String name;
  final IconData icon;
  final Color color;
  const StageSubjectInfo(this.name, this.icon, this.color);
}

const List<StageSubjectInfo> sixthPrimarySubjects = [
  StageSubjectInfo('التربية الإسلامية', Icons.mosque_rounded, Color(0xFF16866A)),
  StageSubjectInfo('اللغة العربية', Icons.menu_book_rounded, Color(0xFFB76E24)),
  StageSubjectInfo('اللغة الإنكليزية', Icons.translate_rounded, Color(0xFF5267C9)),
  StageSubjectInfo('الرياضيات', Icons.functions_rounded, Color(0xFF7A52C7)),
  StageSubjectInfo('العلوم', Icons.science_rounded, Color(0xFF2787B8)),
  StageSubjectInfo('الاجتماعيات', Icons.public_rounded, Color(0xFFB65C69)),
];

const List<StageSubjectInfo> sixthPreparatorySubjects = [
  StageSubjectInfo('التربية الإسلامية', Icons.mosque_rounded, Color(0xFF16866A)),
  StageSubjectInfo('اللغة العربية', Icons.menu_book_rounded, Color(0xFFB76E24)),
  StageSubjectInfo('اللغة الإنكليزية', Icons.translate_rounded, Color(0xFF5267C9)),
  StageSubjectInfo('الرياضيات', Icons.functions_rounded, Color(0xFF7A52C7)),
  StageSubjectInfo('الفيزياء', Icons.bolt_rounded, Color(0xFFD18A25)),
  StageSubjectInfo('الكيمياء', Icons.science_rounded, Color(0xFF2787B8)),
  StageSubjectInfo('الأحياء', Icons.biotech_rounded, Color(0xFF269B75)),
];

const List<String> sixthPreparatoryBranches = [
  'العلمي',
  'الأدبي',
];

const List<String> sixthPreparatoryScientificTracks = [
  'الأحيائي',
  'التطبيقي',
];

/// يوضح أن الفهرس موجود لكن الملفات لم تُرفع أو تُراجع بعد.
const String stageContentPendingMessage =
    'المحتوى الخاص بهذه المرحلة قيد التجهيز والتحقق، وسيُضاف هنا عند توفر الملفات الموثوقة.';

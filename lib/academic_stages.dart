// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// المراحل الدراسية المدعومة في التطبيق.
enum AcademicStage {
  primarySixth('السادس الابتدائي'),
  intermediateThird('الثالث المتوسط'),
  preparatorySixth('السادس الإعدادي'),
  vocationalThird('الثالث المتوسط المهني'),
  vocationalSixth('السادس المهني');

  final String label;
  const AcademicStage(this.label);

  static AcademicStage fromStorage(String? value) =>
      AcademicStage.values.firstWhere(
        (stage) => stage.name == value,
        orElse: () => AcademicStage.intermediateThird,
      );

  static AcademicStage fromProfileLabel(String? value) {
    switch (value?.trim()) {
      case 'السادس الابتدائي':
        return AcademicStage.primarySixth;
      case 'الثالث المتوسط':
        return AcademicStage.intermediateThird;
      case 'الثالث المتوسط المهني':
        return AcademicStage.vocationalThird;
      case 'السادس المهني':
        return AcademicStage.vocationalSixth;
      case 'السادس العلمي':
      case 'السادس الأدبي':
      case 'السادس الإعدادي':
        return AcademicStage.preparatorySixth;
      default:
        return AcademicStage.intermediateThird;
    }
  }
}

class StageSubjectInfo {
  final String name;
  final IconData icon;
  final Color color;
  /// صفحة مصدر الكتاب التي تعرض ملف PDF وإصداره؛ ليست رابط PDF مباشراً.
  final String? resourceUrl;
  final String edition;

  const StageSubjectInfo(
    this.name,
    this.icon,
    this.color, {
    this.resourceUrl,
    this.edition = '2026–2027',
  });

  bool get hasResource => resourceUrl != null && resourceUrl!.startsWith('https://');
}

const String primaryBooksCatalogUrl =
    'https://iraqedu.net/الكتب-السادس-الابتدائي/';
const String preparatoryBooksCatalogUrl =
    'https://iraqedu.net/كتب-السادس-الاعدادي/';

const List<StageSubjectInfo> sixthPrimarySubjects = [
  StageSubjectInfo('التربية الإسلامية', Icons.mosque_rounded, Color(0xFF16866A),
    resourceUrl: 'https://iraqedu.net/كتاب-اسلامية-للصف-السادس-الابتدائي/'),
  StageSubjectInfo('اللغة العربية', Icons.menu_book_rounded, Color(0xFFB76E24),
    resourceUrl: 'https://iraqedu.net/كتاب-قراءة-للصف-السادس-الابتدائي/'),
  StageSubjectInfo('اللغة الإنكليزية', Icons.translate_rounded, Color(0xFF5267C9),
    resourceUrl: 'https://iraqedu.net/كتاب-الانكليزي-للصف-السادس-الابتدائي/'),
  StageSubjectInfo('الرياضيات', Icons.functions_rounded, Color(0xFF7A52C7),
    resourceUrl: 'https://iraqedu.net/كتاب-رياضيات-للصف-السادس-الابتدائي/'),
  StageSubjectInfo('العلوم', Icons.science_rounded, Color(0xFF2787B8),
    resourceUrl: 'https://iraqedu.net/كتاب-العلوم-للصف-السادس-الابتدائي/'),
  StageSubjectInfo('الاجتماعيات', Icons.public_rounded, Color(0xFFB65C69),
    resourceUrl: 'https://iraqedu.net/كتاب-اجتماعيات-للصف-السادس-الابتدائي/'),
];

/// الكتب العلمية المتاحة في فهرس الكتب؛ بعض المواد ما زالت معروضة بطبعة 2025–2026.
const List<StageSubjectInfo> sixthPreparatorySubjects = [
  StageSubjectInfo('التربية الإسلامية', Icons.mosque_rounded, Color(0xFF16866A),
    resourceUrl: 'https://iraqedu.net/كتاب-الاسلامية-للصف-السادس-العلمي/',
    edition: '2025–2026'),
  StageSubjectInfo('اللغة العربية', Icons.menu_book_rounded, Color(0xFFB76E24),
    resourceUrl: 'https://iraqedu.net/كتب-السادس-الاعدادي/',
    edition: 'الجزآن 2025–2026'),
  StageSubjectInfo('اللغة الإنكليزية', Icons.translate_rounded, Color(0xFF5267C9),
    resourceUrl: 'https://iraqedu.net/كتب-السادس-الاعدادي/',
    edition: '2025–2027'),
  StageSubjectInfo('الرياضيات', Icons.functions_rounded, Color(0xFF7A52C7),
    resourceUrl: 'https://iraqedu.net/كتاب-الرياضيات-للصف-السادس-العلمي/'),
  StageSubjectInfo('الفيزياء', Icons.bolt_rounded, Color(0xFFD18A25),
    resourceUrl: 'https://iraqedu.net/كتاب-الفيزياء-للصف-السادس-العلمي/'),
  StageSubjectInfo('الكيمياء', Icons.science_rounded, Color(0xFF2787B8),
    resourceUrl: 'https://iraqedu.net/كتاب-الكيمياء-للصف-السادس-العلمي/',
    edition: '2025–2026'),
  StageSubjectInfo('الأحياء', Icons.biotech_rounded, Color(0xFF269B75),
    resourceUrl: 'https://iraqedu.net/كتاب-الاحياء-للصف-السادس-العلمي/'),
];

const List<StageSubjectInfo> sixthPreparatoryLiterarySubjects = [
  StageSubjectInfo('التربية الإسلامية', Icons.mosque_rounded, Color(0xFF16866A),
    resourceUrl: 'https://iraqedu.net/كتاب-الاسلامية-للصف-السادس-الادبي/',
    edition: '2025–2026'),
  StageSubjectInfo('اللغة العربية', Icons.menu_book_rounded, Color(0xFFB76E24),
    resourceUrl: 'https://iraqedu.net/كتب-السادس-الاعدادي/',
    edition: 'الجزآن 2025–2026'),
  StageSubjectInfo('اللغة الإنكليزية', Icons.translate_rounded, Color(0xFF5267C9),
    resourceUrl: 'https://iraqedu.net/كتاب-ادب-الانكليزي-السادس-الاعدادي/',
    edition: '2026–2027'),
  StageSubjectInfo('الرياضيات', Icons.functions_rounded, Color(0xFF7A52C7),
    resourceUrl: 'https://iraqedu.net/كتاب-الرياضيات-للصف-السادس-الادبي/',
    edition: '2025–2026'),
  StageSubjectInfo('التاريخ', Icons.history_edu_rounded, Color(0xFF9B6842),
    resourceUrl: 'https://iraqedu.net/كتاب-التاريخ-للصف-السادس-الادبي/',
    edition: '2025–2026'),
  StageSubjectInfo('الجغرافية', Icons.public_rounded, Color(0xFFB65C69),
    resourceUrl: 'https://iraqedu.net/كتاب-الجغرافية-للصف-السادس-الادبي/',
    edition: '2025–2026'),
  StageSubjectInfo('الاقتصاد', Icons.account_balance_rounded, Color(0xFF268477),
    resourceUrl: 'https://iraqedu.net/كتاب-الاقتصاد-للصف-السادس-الادبي/',
    edition: '2025–2026'),
];

const List<StageSubjectInfo> vocationalCommonSubjects = [
  StageSubjectInfo('التربية الإسلامية', Icons.mosque_rounded, Color(0xFF16866A)),
  StageSubjectInfo('اللغة العربية', Icons.menu_book_rounded, Color(0xFFB76E24)),
  StageSubjectInfo('اللغة الإنكليزية', Icons.translate_rounded, Color(0xFF5267C9)),
  StageSubjectInfo('الرياضيات', Icons.functions_rounded, Color(0xFF7A52C7)),
];

const List<String> sixthPreparatoryBranches = ['العلمي', 'الأدبي'];
const List<String> sixthPreparatoryScientificTracks = ['الأحيائي', 'التطبيقي'];

const String sixthPrimaryArchiveUrl =
    'https://iraqedu.net/ملزمة-وزاريات-السادس-الابتدائي-طابعي/';
const String sixthPreparatoryArchiveUrl =
    'https://iraqedu.net/وزاريات-السادس-الاعدادي/';
const String sixthPrimaryReviewUrl = 'https://talemiq.com/sdsb6';
const String sixthPreparatoryReviewUrl =
    'https://iraqedu.net/المراجعات-المركزة-السادس-الاعدادي/';

/// يوضح للطالب عند غياب رابط موثوق، دون عرض استثناء تقني.
const String stageContentPendingMessage =
    'لم نعثر بعد على رابط موثوق لهذا المحتوى. يمكنك الرجوع لاحقاً بعد تحديث المصادر.';


/// يحفظ المرحلة الدراسية المختارة ويتيح لبقية الشاشات مراقبتها.
class AcademicStageController {
  AcademicStageController._();

  static const String _storageKey = 'dalilak_selected_academic_stage_v1';
  static final ValueNotifier<AcademicStage> current =
      ValueNotifier<AcademicStage>(AcademicStage.intermediateThird);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    current.value = AcademicStage.fromStorage(prefs.getString(_storageKey));
  }

  static Future<void> select(AcademicStage stage) async {
    current.value = stage;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, stage.name);
  }
}

// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'student_tools.dart';
import 'student_community.dart';
import 'student_onboarding.dart';
import 'exam_archive_data.dart';
import 'review_quiz.dart';
import 'academic_stages.dart';
import 'notifications/study_notification_service.dart';
Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); await Supabase.initialize(url: SupabaseConfig.projectUrl, publishableKey: SupabaseConfig.publishableKey); await SavedExamsStore.load(); await ThemeController.load(); await AcademicStageController.load(); await StudyNotificationService.instance.initialize(); runApp(const StudyApp()); }
const navy=Color(0xFF142D50), blue=Color(0xFF2868D7), bg=Color(0xFFF3F6FB);
class SavedExamsStore {
  static const String _storageKey = 'saved_exam_sheets_v1';
  static final ValueNotifier<List<Map<String, String>>> items =
      ValueNotifier<List<Map<String, String>>>([]);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        items.value = [];
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        items.value = decoded.whereType<Map>()
            .map((entry) => Map<String, String>.from(entry))
            .where((entry) => (entry['path'] ?? '').isNotEmpty)
            .toList();
      } else {
        items.value = [];
      }
    } catch (_) {
      // A damaged or temporarily unavailable local store must not prevent
      // the application or the saved-items screen from opening.
      items.value = [];
    }
  }

  static bool contains(String path) =>
      items.value.any((item) => item['path'] == path);

  static Future<bool> toggle(Map<String, String> exam) async {
    final updated = items.value
        .map((item) => Map<String, String>.from(item)).toList();
    final index = updated.indexWhere((item) => item['path'] == exam['path']);
    final saved = index < 0;
    if (saved) {
      updated.insert(0, exam);
    } else {
      updated.removeAt(index);
    }
    items.value = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(updated));
    return saved;
  }

  static Future<void> remove(String path) async {
    final updated = items.value.where((item) => item['path'] != path)
        .map((item) => Map<String, String>.from(item)).toList();
    items.value = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(updated));
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    items.value = [];
  }
}

class AiReportStore {
  static const String _storageKey = 'ai_answer_reports_v1';

  static Future<void> save({required String category, String note = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final reports = <Map<String, dynamic>>[];
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) reports.add(Map<String, dynamic>.from(item));
          }
        }
      } catch (_) {}
    }
    reports.insert(0, {
      'category': category,
      'note': note.trim(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    if (reports.length > 100) reports.removeRange(100, reports.length);
    await prefs.setString(_storageKey, jsonEncode(reports));
  }
}

class ThemeController {
  static const _key = 'study_app_dark_mode_v1';
  static const _paletteKey = 'study_app_palette_v1';
  static const _fontKey = 'study_app_font_scale_v1';
  static const _bookStyleKey = 'study_app_book_style_v1';
  static const _radiusKey = 'study_app_card_radius_v1';
  static const _motionKey = 'study_app_motion_v1';
  static const _eyeCareKey = 'study_app_eye_care_v1';

  static const List<Color> paletteColors = [
    Color(0xFF2868D7), // أزرق التطبيق الأصلي
    Color(0xFF16866A), // أخضر هادئ
    Color(0xFF7652C7), // بنفسجي
    Color(0xFFB87524), // ذهبي دافئ
  ];
  static const List<Color> lightBackgrounds = [
    Color(0xFFF3F6FB),
    Color(0xFFF0F7F5),
    Color(0xFFF5F2FA),
    Color(0xFFFBF6ED),
  ];
  static const List<Color> lightCardSurfaces = [
    Color(0xFFFFFFFF),
    Color(0xFFFBFEFD),
    Color(0xFFFCFAFF),
    Color(0xFFFFFDFA),
  ];
  static const List<Color> darkBackgrounds = [
    Color(0xFF101827),
    Color(0xFF0D1A18),
    Color(0xFF171321),
    Color(0xFF1A160F),
  ];
  static const List<Color> darkCardSurfaces = [
    Color(0xFF1B2A40),
    Color(0xFF19302B),
    Color(0xFF29213A),
    Color(0xFF302719),
  ];

  static final ValueNotifier<bool> isDark = ValueNotifier<bool>(false);
  static final ValueNotifier<int> paletteIndex = ValueNotifier<int>(0);
  static final ValueNotifier<double> fontScale = ValueNotifier<double>(1.0);
  static final ValueNotifier<int> bookCardStyle = ValueNotifier<int>(0);
  static final ValueNotifier<double> cardRadius = ValueNotifier<double>(18);
  static final ValueNotifier<bool> motionEnabled = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> eyeCare = ValueNotifier<bool>(false);

  static Color get accent => paletteColors[paletteIndex.value.clamp(0, 3).toInt()];
  static Color bookCardColor(Color subjectColor, ColorScheme scheme) {
    switch (bookCardStyle.value) {
      case 1:
        return Color.alphaBlend(subjectColor.withValues(alpha: .10), scheme.surface);
      case 2:
        return Color.alphaBlend(accent.withValues(alpha: .13), scheme.surface);
      default:
        return scheme.surfaceContainerLow;
    }
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isDark.value = prefs.getBool(_key) ?? false;
    paletteIndex.value = (prefs.getInt(_paletteKey) ?? 0).clamp(0, 3).toInt();
    final savedScale = prefs.getDouble(_fontKey) ?? 1.0;
    fontScale.value = [0.95, 1.0, 1.08].contains(savedScale) ? savedScale : 1.0;
    bookCardStyle.value = (prefs.getInt(_bookStyleKey) ?? 0).clamp(0, 2).toInt();
    final radius = prefs.getDouble(_radiusKey) ?? 18;
    cardRadius.value = [12.0, 18.0, 24.0].contains(radius) ? radius : 18;
    motionEnabled.value = prefs.getBool(_motionKey) ?? true;
    eyeCare.value = prefs.getBool(_eyeCareKey) ?? false;
  }

  static Future<void> toggle(bool value) async {
    isDark.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  static Future<void> setPalette(int value) async {
    paletteIndex.value = value.clamp(0, 3).toInt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_paletteKey, paletteIndex.value);
  }

  static Future<void> setFontScale(double value) async {
    fontScale.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontKey, value);
  }

  static Future<void> setBookCardStyle(int value) async {
    bookCardStyle.value = value.clamp(0, 2).toInt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bookStyleKey, bookCardStyle.value);
  }

  static Future<void> setCardRadius(double value) async {
    cardRadius.value = [12.0, 18.0, 24.0].contains(value) ? value : 18;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_radiusKey, cardRadius.value);
  }

  static Future<void> setMotionEnabled(bool value) async {
    motionEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_motionKey, value);
  }

  static Future<void> setEyeCare(bool value) async {
    eyeCare.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_eyeCareKey, value);
  }

  static Future<void> restoreDefaults() async {
    isDark.value = false;
    paletteIndex.value = 0;
    fontScale.value = 1.0;
    bookCardStyle.value = 0;
    cardRadius.value = 18;
    motionEnabled.value = true;
    eyeCare.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
    await prefs.setInt(_paletteKey, 0);
    await prefs.setDouble(_fontKey, 1.0);
    await prefs.setInt(_bookStyleKey, 0);
    await prefs.setDouble(_radiusKey, 18);
    await prefs.setBool(_motionKey, true);
    await prefs.setBool(_eyeCareKey, false);
  }
}

class AcademicStagePicker extends StatelessWidget {
  const AcademicStagePicker({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AcademicStage>(
    valueListenable: AcademicStageController.current,
    builder: (context, selected, _) => Card(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(children: [
          Icon(Icons.school_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          const Expanded(child: Text('المرحلة الدراسية',
            style: TextStyle(fontWeight: FontWeight.w800))),
          DropdownButton<AcademicStage>(
            value: selected,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(14),
            items: AcademicStage.values.map((stage) => DropdownMenuItem(
              value: stage, child: Text(stage.label,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            )).toList(),
            onChanged: (stage) {
              if (stage != null) AcademicStageController.select(stage);
            },
          ),
        ]),
      ),
    ),
  );
}

class StageContentPlaceholderScreen extends StatelessWidget {
  final AcademicStage stage;
  final String title;
  final String description;
  const StageContentPlaceholderScreen({
    super.key, required this.stage, required this.title,
    this.description = stageContentPendingMessage,
  });

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.menu_book_rounded, size: 58,
            color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(stage.label, style: const TextStyle(
            fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(description, textAlign: TextAlign.center,
            style: TextStyle(height: 1.7,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          const Chip(label: Text('قيد التوفير')),
        ]),
      )),
    ),
  );
}

class StageCatalogScreen extends StatefulWidget {
  final AcademicStage stage;
  const StageCatalogScreen({super.key, required this.stage});
  @override
  State<StageCatalogScreen> createState() => _StageCatalogScreenState();
}

class _StageCatalogScreenState extends State<StageCatalogScreen> {
  String _branch = 'العلمي';
  String _scientificTrack = 'الأحيائي';

  List<StageSubjectInfo> get _stageSubjects {
    if (widget.stage == AcademicStage.primarySixth) {
      return sixthPrimarySubjects;
    }
    return _branch == 'الأدبي'
        ? sixthPreparatoryLiterarySubjects
        : sixthPreparatorySubjects;
  }


  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPreparatory = widget.stage == AcademicStage.preparatorySixth;
    final subjectsForNotes = _stageSubjects.map((subject) => subject.name).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        key: PageStorageKey<String>('stage_catalog_${widget.stage.name}'),
        padding: const EdgeInsets.all(16),
        children: [
          const AcademicStagePicker(),
          Text(widget.stage.label, style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w900, color: colors.onSurface)),
          const SizedBox(height: 6),
          Text('كتب وموارد وأدوات مخصصة لهذه المرحلة فقط',
            style: TextStyle(color: colors.onSurfaceVariant)),
          if (isPreparatory) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _branch,
              decoration: const InputDecoration(labelText: 'الفرع الدراسي'),
              items: sixthPreparatoryBranches.map((branch) =>
                DropdownMenuItem(value: branch, child: Text(branch))).toList(),
              onChanged: (value) => setState(() {
                _branch = value ?? 'العلمي';
                _scientificTrack = 'الأحيائي';
              }),
            ),
            if (_branch == 'العلمي') ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _scientificTrack,
                decoration: const InputDecoration(labelText: 'مسار الفرع العلمي'),
                items: sixthPreparatoryScientificTracks.map((track) =>
                  DropdownMenuItem(value: track, child: Text(track))).toList(),
                onChanged: (value) => setState(() =>
                  _scientificTrack = value ?? 'الأحيائي'),
              ),
            ],
            const SizedBox(height: 8),
            Text(_branch == 'الأدبي'
                ? 'يعرض هذا القسم كتب الفرع الأدبي المتاحة في فهرس المصادر.'
                : 'المسار: $_scientificTrack — يعرض الكتب العلمية المدرجة حالياً.',
              style: TextStyle(color: colors.onSurfaceVariant)),
          ],
          const SizedBox(height: 18),
          Feature(
            icon: Icons.history_edu_rounded,
            title: 'الأسئلة الوزارية والحلول',
            desc: 'تصفح الأرشيف الداخلي للمرحلة دون مغادرة التطبيق',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => StageInternalArchiveScreen(
                stage: widget.stage, subjects: _stageSubjects,
                isReview: false,
              ),
            )),
          ),
          Feature(
            icon: Icons.quiz_rounded,
            title: 'المراجعة المركزة',
            desc: 'فتح مكتبة المراجعة الداخلية للمرحلة',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => StageInternalArchiveScreen(
                stage: widget.stage, subjects: _stageSubjects,
                isReview: true,
              ),
            )),
          ),
          const SizedBox(height: 8),
          Text('كتب المواد الدراسية', style: TextStyle(
            fontSize: 19, fontWeight: FontWeight.w900, color: colors.onSurface)),
          const SizedBox(height: 5),
          Text('اختر بطاقة المادة لفتح صفحة الكتاب وملفات PDF المتاحة.',
            style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _stageSubjects.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 11,
              mainAxisSpacing: 11,
              childAspectRatio: 1.08,
            ),
            itemBuilder: (context, index) {
              final subject = _stageSubjects[index];
              final available = subject.hasResource;
              return Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                color: ThemeController.bookCardColor(subject.color, colors),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThemeController.cardRadius.value),
                  side: BorderSide(color: subject.color.withValues(alpha: .35)),
                ),
                child: InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => StageBookResourceScreen(
                      stage: widget.stage, subject: subject,
                    ),
                  )),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: subject.color.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: Icon(subject.icon, size: 31, color: subject.color),
                        ),
                        const SizedBox(height: 10),
                        Text(subject.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 5),
                        Text(available ? 'صفحة مصدر • ${subject.edition}' : 'المصدر غير متوفر',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(fontSize: 10,
                            color: colors.onSurfaceVariant)),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(Icons.arrow_outward_rounded,
                              size: 19, color: colors.primary),
                            const Spacer(),
                            FutureBuilder<List<Map<String, String>>>(
                              future: StageResourceBookmarks.load(widget.stage),
                              builder: (context, snapshot) {
                                final isSaved = (snapshot.data ?? const [])
                                    .any((item) => item['url'] == subject.resourceUrl);
                                return IconButton(
                                  tooltip: isSaved ? 'إزالة من المحفوظات' : 'حفظ المادة',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () async {
                                    if (isSaved) {
                                      await StageResourceBookmarks.remove(
                                        widget.stage, subject.resourceUrl ?? '');
                                    } else {
                                      await StageResourceBookmarks.save(
                                        widget.stage, subject);
                                    }
                                    if (mounted) setState(() {});
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(isSaved
                                          ? 'أزيلت المادة من المحفوظات'
                                          : 'تم حفظ المادة في محفوظات المرحلة')),
                                      );
                                    }
                                  },
                                  icon: Icon(isSaved
                                    ? Icons.bookmark_added_rounded
                                    : Icons.bookmark_add_outlined),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Feature(
            icon: Icons.bookmarks_rounded,
            title: 'المحفوظات',
            desc: 'عرض أوراقك ومواردك المحفوظة على هذا الجهاز',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => StageSavedResourcesScreen(stage: widget.stage))),
          ),
          Feature(
            icon: Icons.edit_note_rounded,
            title: 'مفكرة هذه المرحلة',
            desc: 'احفظ ملاحظاتك منفصلة حسب مواد المرحلة المختارة',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => StudyNotesScreen(
                subjectNames: subjectsForNotes,
                storageScope: widget.stage.name,
              ),
            )),
          ),
        ],
      ),
    );
  }
}

class StageResourceBookmarks {
  static String _key(AcademicStage stage) =>
      'dalilak_stage_saved_resources_${stage.name}';

  static Future<List<Map<String, String>>> load(AcademicStage stage) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(stage));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>()
          .map((item) => Map<String, String>.from(item))
          .where((item) => (item['url'] ?? '').startsWith('https://'))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(
      AcademicStage stage, StageSubjectInfo subject) async {
    if (!subject.hasResource) return;
    final items = await load(stage);
    if (items.any((item) => item['url'] == subject.resourceUrl)) return;
    items.insert(0, {
      'title': subject.name,
      'url': subject.resourceUrl!,
      'edition': subject.edition,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(stage), jsonEncode(items));
  }

  static Future<void> remove(
      AcademicStage stage, String url) async {
    final items = await load(stage);
    items.removeWhere((item) => item['url'] == url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(stage), jsonEncode(items));
  }
}

class StageSavedResourcesScreen extends StatefulWidget {
  final AcademicStage stage;
  const StageSavedResourcesScreen({super.key, required this.stage});

  @override
  State<StageSavedResourcesScreen> createState() =>
      _StageSavedResourcesScreenState();
}

class _StageSavedResourcesScreenState extends State<StageSavedResourcesScreen> {
  List<Map<String, String>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await StageResourceBookmarks.load(widget.stage);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _open(String url, String title) async {
    if (!mounted) return;
    final item = _items.firstWhere(
      (entry) => entry['url'] == url,
      orElse: () => <String, String>{},
    );
    final description = item['edition'] ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(
          'تم حفظ مصدر هذه المادة في محفوظاتك. $description\\n'
          'المصدر الحالي صفحة فهرس وليس ملف PDF مباشراً؛ لذلك لم نفتح متصفحاً '
          'ولم نعرض ملفاً غير متحقق منه. أضف رابط PDF مباشر أو ملفاً داخل التطبيق '
          'حتى يتاح فتحه هنا.',
          textDirection: TextDirection.rtl,
        ),
        actions: [TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('حسناً'),
        )],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text('محفوظات ${widget.stage.label}')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bookmarks_outlined, size: 54,
                        color: colors.primary),
                      const SizedBox(height: 12),
                      const Text('ما عندك كتب محفوظة بعد',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text('اضغط علامة الحفظ على بطاقة أي مادة حتى تضيف مصدرها هنا.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant)),
                    ]),
                  ))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final title = item['title'] ?? 'كتاب';
                      final url = item['url'] ?? '';
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.picture_as_pdf_rounded),
                          title: Text(title,
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(item['edition'] ?? ''),
                          onTap: () => _open(url, title),
                          trailing: IconButton(
                            tooltip: 'إزالة من المحفوظات',
                            icon: const Icon(Icons.bookmark_remove_outlined),
                            onPressed: () async {
                              await StageResourceBookmarks.remove(widget.stage, url);
                              await _load();
                            },
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class StudyApp extends StatelessWidget {
  const StudyApp({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      ThemeController.isDark,
      ThemeController.paletteIndex,
      ThemeController.fontScale,
      ThemeController.cardRadius,
      ThemeController.motionEnabled,
      ThemeController.eyeCare,
    ]),
    builder: (context, _) {
      final isDark = ThemeController.isDark.value;
      final palette = ThemeController.paletteColors[
        ThemeController.paletteIndex.value.clamp(0, 3).toInt()];
      final fontScale = ThemeController.fontScale.value;
      final paletteIndex = ThemeController.paletteIndex.value.clamp(0, 3).toInt();
      final lightBackground = ThemeController.lightBackgrounds[paletteIndex];
      final lightCard = ThemeController.lightCardSurfaces[paletteIndex];
      final darkBackground = ThemeController.darkBackgrounds[paletteIndex];
      final darkCard = ThemeController.darkCardSurfaces[paletteIndex];
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'دليلك للنجاح — العراق',
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: lightBackground,
          colorScheme: ColorScheme.fromSeed(seedColor: palette),
          cardTheme: CardThemeData(
            color: lightCard,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeController.cardRadius.value))),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: palette.withValues(alpha: .15)),
          appBarTheme: AppBarTheme(
            backgroundColor: lightBackground,
            surfaceTintColor: Colors.transparent)),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: darkBackground,
          colorScheme: ColorScheme.fromSeed(
            seedColor: palette,
            brightness: Brightness.dark,
            surface: darkCard),
          cardColor: darkCard,
          cardTheme: CardThemeData(
            color: darkCard,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeController.cardRadius.value))),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: Color(0xFF172337),
            indicatorColor: Color(0xFF294A78)),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF101827),
            surfaceTintColor: Colors.transparent),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: darkCard,
            hintStyle: const TextStyle(color: Color(0xFFB8C7DA), fontSize: 14),
            labelStyle: const TextStyle(color: Color(0xFFD0DCEE)),
            floatingLabelStyle: const TextStyle(color: Color(0xFF9FC2FF)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: Color(0xFF40536D))),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: Color(0xFF79A9FF), width: 1.6)),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: Color(0xFFFF7777))),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14))),
          )),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontScale),
            disableAnimations: !ThemeController.motionEnabled.value),
          child: Stack(children: [
            child ?? const SizedBox.shrink(),
            if (ThemeController.eyeCare.value)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: Color(0x12FFD28A)),
                ),
              ),
          ]),
        ),
        home: const StudentOnboardingGate(child: Shell()));
    },
  );
}
class Shell extends StatefulWidget {const Shell({super.key}); @override State<Shell> createState()=>_ShellState();}
class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int tab=0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    StudyNotificationService.instance.onAppResumed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      StudyNotificationService.instance.onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void open(Subject s)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>SubjectScreen(subject:s)));
  @override Widget build(BuildContext context){
    final pages=[Home(onOpen:open,onAll:()=>setState(()=>tab=1)),Catalog(onOpen:open),const NewsScreen(),const PomodoroScreen(),const MoreScreen()];
    return Directionality(textDirection:TextDirection.rtl,child:Scaffold(
      body:SafeArea(child:IndexedStack(index:tab,children:pages)),
      bottomNavigationBar:NavigationBar(
        selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),
        backgroundColor:Theme.of(context).colorScheme.surface,
        destinations:const [
          NavigationDestination(icon:Icon(Icons.home_rounded),label:'الرئيسية'),
          NavigationDestination(icon:Icon(Icons.grid_view_rounded),label:'المواد'),
          NavigationDestination(icon:Icon(Icons.campaign_rounded),label:'الأخبار'),
          NavigationDestination(icon:Icon(Icons.timer_rounded),label:'المؤقت'),
          NavigationDestination(icon:Icon(Icons.more_horiz_rounded),label:'المزيد')
        ])));
  }
}
class HomeChatRoomEntryCard extends StatelessWidget {
  const HomeChatRoomEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StudentCommunityScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.forum_rounded, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('غرفة الدردشة',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text('تواصل مع زملائك وشارك الفائدة الدراسية',
                      style: TextStyle(fontSize: 11,
                        color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeProfileButton extends StatefulWidget {
  const _HomeProfileButton();
  @override
  State<_HomeProfileButton> createState() => _HomeProfileButtonState();
}
class _HomeProfileButtonState extends State<_HomeProfileButton> {
  String? _avatarUrl;
  StreamSubscription<dynamic>? _authSubscription;
  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => _loadAvatar());
  }
  Future<void> _loadAvatar() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _avatarUrl = null);
      return;
    }
    String? imageUrl = user.userMetadata?['picture']?.toString();
    try {
      final profile = await Supabase.instance.client.from('profiles')
          .select('avatar_url').eq('user_id', user.id).maybeSingle();
      final savedUrl = profile?['avatar_url']?.toString();
      if (savedUrl != null && savedUrl.startsWith('http')) imageUrl = savedUrl;
    } catch (_) {
      // Keep the Google profile photo as a fallback while offline.
    }
    if (mounted && Supabase.instance.client.auth.currentUser?.id == user.id) {
      setState(() => _avatarUrl = imageUrl);
    }
  }
  void _openProfile() {
    final signedIn = Supabase.instance.client.auth.currentUser != null;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => signedIn
          ? const StudentProfileScreen()
          : const StudentGoogleLoginScreen(),
    )).then((_) => _loadAvatar());
  }
  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasPhoto = _avatarUrl != null && _avatarUrl!.startsWith('http');
    return Tooltip(
      message: 'الملف الشخصي',
      child: InkWell(
        onTap: _openProfile,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: colors.primaryContainer,
            backgroundImage: hasPhoto ? NetworkImage(_avatarUrl!) : null,
            child: hasPhoto ? null : Icon(Icons.person_rounded,
              size: 21, color: colors.onPrimaryContainer),
          ),
        ),
      ),
    );
  }
}

class Home extends StatefulWidget {
  final ValueChanged<Subject> onOpen;
  final VoidCallback onAll;
  const Home({super.key, required this.onOpen, required this.onAll});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  bool _showWelcome = false;
  late final AnimationController _welcomeController;
  late final Animation<double> _welcomeSize;
  late final Animation<double> _welcomeOpacity;
  late final Animation<Offset> _welcomeSlide;
  Timer? _welcomeTimer;

  @override
  void initState() {
    super.initState();
    _welcomeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
      value: 1,
    );
    final curved = CurvedAnimation(
      parent: _welcomeController,
      curve: Curves.easeInOutCubic,
    );
    _welcomeSize = curved;
    _welcomeOpacity = curved;
    _welcomeSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.18),
    ).animate(curved);
    _loadFirstWelcome();
  }

  Future<void> _loadFirstWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('dalilak_home_welcome_seen_v1') ?? false;
    if (alreadyShown || !mounted) return;
    await prefs.setBool('dalilak_home_welcome_seen_v1', true);
    if (!mounted) return;
    setState(() => _showWelcome = true);
    _welcomeTimer = Timer(const Duration(seconds: 4), _dismissWelcome);
  }

  void _dismissWelcome() {
    if (!mounted || !_showWelcome || _welcomeController.isAnimating) return;
    _welcomeTimer?.cancel();
    _welcomeController.reverse().then((_) {
      if (mounted) setState(() => _showWelcome = false);
    });
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    _welcomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
    children: [
      Row(children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(gradient: const LinearGradient(
            colors: [Color(0xFF17427E), Color(0xFF347FE8)]),
            borderRadius: BorderRadius.circular(15)),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 27)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('دليلك للنجاح', style: TextStyle(fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface)),
            ValueListenableBuilder<AcademicStage>(
              valueListenable: AcademicStageController.current,
              builder: (context, stage, _) => Text('${stage.label} • العراق',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ])),
        IconButton(
          tooltip: 'البحث عن الطلاب',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentSearchScreen()),
          ),
          icon: const Icon(Icons.search_rounded),
        ),
        const _HomeProfileButton(),
        ValueListenableBuilder<bool>(
          valueListenable: ThemeController.isDark,
          builder: (context, isDark, _) => IconButton(
            tooltip: isDark ? 'تفعيل الوضع النهاري' : 'تفعيل الوضع الليلي',
            onPressed: () => ThemeController.toggle(!isDark),
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded)),
        ),
      ]),
      const HomeChatRoomEntryCard(),
      if (_showWelcome)
        SizeTransition(
          sizeFactor: _welcomeSize,
          axisAlignment: -1,
          child: FadeTransition(
            opacity: _welcomeOpacity,
            child: SlideTransition(
              position: _welcomeSlide,
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.fromLTRB(15, 14, 10, 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF203A5B)
                      : const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF36577F)
                        : const Color(0xFFD1E1FA),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.waving_hand_rounded,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFFD27A)
                          : const Color(0xFF2868D7),
                      size: 25),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('أهلاً بك في دليلك للنجاح',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.onSurface,
                            )),
                          const SizedBox(height: 5),
                          Text(
                            'نتمنى لك دراسة موفقة ونجاحاً قريباً. راجع الأسئلة والحلول بهدوء، وتأكد دائماً من مطابقتها للكتاب المدرسي وتوجيهات مدرسك.',
                            style: TextStyle(
                              height: 1.55,
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'إغلاق رسالة الترحيب',
                      visualDensity: VisualDensity.compact,
                      onPressed: _dismissWelcome,
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: 20),
      Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const AiAssistantScreen())),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? const [Color(0xFF183B61), Color(0xFF234F7C)]
                    : const [Color(0xFF17427E), Color(0xFF347FE8)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: .16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 27)),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المساعد الذكي',
                        style: TextStyle(color: Colors.white,
                          fontSize: 18, fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text('مساعدك الدراسي للثالث متوسط',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  )),
                  const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 17),
                ]),
                const SizedBox(height: 13),
                const Text(
                  'اسأل عن أي درس أو مسألة، واحصل على شرح واضح خطوة بخطوة يساعدك على الفهم والمراجعة.',
                  style: TextStyle(color: Colors.white, height: 1.55,
                    fontSize: 13)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const AiAssistantScreen())),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: navy,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                    label: const Text('ابدأ المحادثة الآن',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      ValueListenableBuilder<AcademicStage>(
        valueListenable: AcademicStageController.current,
        builder: (context, stage, _) => stage == AcademicStage.intermediateThird
            ? const ExamCountdownSection()
            : const SizedBox.shrink(),
      ),
      const SizedBox(height: 12),
      ValueListenableBuilder<List<Map<String, String>>>(
        valueListenable: SavedExamsStore.items,
        builder: (context, savedItems, _) => Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => Saved(onOpenCatalog: widget.onAll))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(children: [
                Icon(Icons.bookmark_added_rounded,
                  color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 9),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إنجاز مراجعتك • المحفوظات',
                      style: TextStyle(fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Text('ارجع إلى أوراقك التي حفظتها بلمسة واحدة',
                      style: TextStyle(fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                )),
                Text('${savedItems.length} محفوظ',
                  style: TextStyle(fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary)),
                const SizedBox(width: 5),
                Icon(Icons.arrow_forward_ios_rounded, size: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const SizedBox(height: 20),
      Text('أدوات المراجعة والأسئلة', style: TextStyle(fontSize: 18,
        fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
      const SizedBox(height: 12),
      Text('مميزات التطبيق', style: TextStyle(fontSize: 18,
        fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: [
          _HomeToolTile(icon: Icons.history_edu_rounded, title: 'الأرشيف حسب السنة والدور', subtitle: 'وزاري وتمهيدي', onTap: () {
            final stage = AcademicStageController.current.value;
            Navigator.push(context, MaterialPageRoute(builder: (_) =>
              stage == AcademicStage.intermediateThird
                  ? const ArchiveSearchScreen()
                  : StageContentPlaceholderScreen(stage: stage,
                      title: 'الأرشيف الوزاري')));
          }),
          _HomeToolTile(icon: Icons.fact_check_outlined, title: 'الحلول النموذجية', subtitle: 'شرح وخطوات الحل', onTap: () {
            final stage = AcademicStageController.current.value;
            Navigator.push(context, MaterialPageRoute(builder: (_) =>
              stage == AcademicStage.intermediateThird
                  ? const SolutionsHubScreen()
                  : SolutionsHubScreen(
                      stageLabel: stage.label,
                      availableSubjects: (stage == AcademicStage.primarySixth
                        ? sixthPrimarySubjects : sixthPreparatorySubjects)
                        .map((item) => Subject(item.name, item.icon, item.color))
                        .toList(),
                    )));
          }),
          _HomeToolTile(icon: Icons.search_rounded, title: 'بحث وحفظ سريع', subtitle: 'ابحث واحتفظ للمراجعة', onTap: () {
            final stage = AcademicStageController.current.value;
            Navigator.push(context, MaterialPageRoute(builder: (_) =>
              stage == AcademicStage.intermediateThird
                  ? const SearchSaveScreen()
                  : StageContentPlaceholderScreen(stage: stage,
                      title: 'البحث والحفظ')));
          }),
          _HomeToolTile(icon: Icons.edit_note_rounded, title: 'مفكرة المراجعة', subtitle: 'أضف وعدّل ملاحظاتك', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyNotesScreen()))),
          _HomeToolTile(icon: Icons.bookmarks_rounded, title: 'المحفوظات', subtitle: 'أوراقك المحفوظة', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Saved(onOpenCatalog: widget.onAll)))),
          _HomeToolTile(icon: Icons.quiz_rounded, title: 'مراجعة', subtitle: 'اختبر معلوماتك حسب الفصل', onTap: () {
            final stage = AcademicStageController.current.value;
            Navigator.push(context, MaterialPageRoute(builder: (_) =>
              stage == AcademicStage.intermediateThird
                  ? const ReviewQuizScreen()
                  : StageInternalArchiveScreen(
                      stage: stage,
                      subjects: (stage == AcademicStage.primarySixth
                        ? sixthPrimarySubjects : sixthPreparatorySubjects),
                      isReview: true,
                    )));
          }),
        ],
      ),
      const SizedBox(height: 8),

    ]);
}
class SubjectTile extends StatelessWidget {
  final Subject subject; final VoidCallback onTap;
  const SubjectTile({super.key, required this.subject, required this.onTap});
  @override Widget build(BuildContext context) => Material(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18),
      child: Padding(padding: const EdgeInsets.all(12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 39, height: 39,
                decoration: BoxDecoration(color: subject.color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(12)),
                child: Icon(subject.icon, color: subject.color, size: 22)),
              const Spacer(),
              Icon(Icons.arrow_outward_rounded, size: 17,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            ]),
            const SizedBox(height: 9),
            Text('كتاب ${subject.name}', maxLines: 3, softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5,
                height: 1.22, letterSpacing: 0,
                color: Theme.of(context).colorScheme.onSurface)),
          ]))));
}
class Catalog extends StatelessWidget {
  final ValueChanged<Subject> onOpen;
  const Catalog({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<AcademicStage>(
        valueListenable: AcademicStageController.current,
        builder: (context, stage, _) {
          if (stage != AcademicStage.intermediateThird) {
            return StageCatalogScreen(
              key: ValueKey('catalog_${stage.name}'),
              stage: stage,
            );
          }
          final colors = Theme.of(context).colorScheme;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: CustomScrollView(
              key: const PageStorageKey<String>('subjects_catalog_scroll'),
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  sliver: SliverToBoxAdapter(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const AcademicStagePicker(),
                      Text('المواد الدراسية', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: colors.onSurface)),
                      const SizedBox(height: 6),
                      Text('اختر المادة لفتح كتابها، أو ابدأ بمراجعة الأسئلة الوزارية', style: TextStyle(color: colors.onSurfaceVariant)),
                      const SizedBox(height: 18),
                      Feature(
                        icon: Icons.history_edu_rounded,
                        title: 'الأسئلة الوزارية للسنين السابقة',
                        desc: 'تصفح الأوراق الامتحانية حسب المادة والسنة والدور',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchiveSearchScreen())),
                      ),
                      const SizedBox(height: 18),
                      Text('كتب المواد الدراسية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colors.onSurface)),
                      const SizedBox(height: 5),
                      Text('اختر المادة للوصول إلى كتابها وملفات PDF', style: TextStyle(color: colors.onSurfaceVariant)),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 11, mainAxisSpacing: 11, childAspectRatio: 1.34),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => SubjectTile(
                        subject: bookSubjects[index],
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BooksLibraryScreen(
                          subject: bookSubjects[index],
                          cardStyle: ThemeController.bookCardStyle.value,
                          accentColor: ThemeController.accent,
                          cardRadius: ThemeController.cardRadius.value,
                        ))),
                      ),
                      childCount: bookSubjects.length,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                  sliver: SliverToBoxAdapter(
                    child: Feature(
                      icon: Icons.edit_note_rounded,
                      title: 'مفكرة المراجعة الخاصة بي',
                      desc: 'سجّل القوانين والأسئلة الصعبة والملاحظات لكل مادة واحفظها على جهازك',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyNotesScreen())),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class ArchiveSearchScreen extends StatefulWidget {
  const ArchiveSearchScreen({super.key});

  @override
  State<ArchiveSearchScreen> createState() => _ArchiveSearchScreenState();
}

class _ArchiveSearchScreenState extends State<ArchiveSearchScreen> {
  final TextEditingController queryController = TextEditingController();
  String subjectFilter = 'كل المواد';
  String yearFilter = 'كل السنوات';
  String roundFilter = 'كل الأدوار';

  List<_ArchiveSearchItem> get allItems => _getAvailableArchiveItems();

  List<_ArchiveSearchItem> get filteredItems {
    final query = queryController.text.trim().toLowerCase();
    return allItems.where((item) {
      final matchesQuery = query.isEmpty ||
          '${item.subject.name} ${item.academicYear} ${item.round}'.toLowerCase().contains(query);
      return matchesQuery &&
          (subjectFilter == 'كل المواد' || item.subject.name == subjectFilter) &&
          (yearFilter == 'كل السنوات' || item.year == yearFilter) &&
          (roundFilter == 'كل الأدوار' || item.round == roundFilter);
    }).toList();
  }

  @override
  void dispose() {
    queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = filteredItems;
    final years = allItems.map((item) => item.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    const rounds = ['التمهيدي', 'الدور الأول', 'الدور الثاني', 'الدور الثالث', 'كل الصور'];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('البحث في الأرشيف',
          style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: queryController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ابحث باسم المادة أو السنة أو الدور',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: subjectFilter,
              decoration: const InputDecoration(labelText: 'المادة'),
              items: ['كل المواد', ...archiveSubjects.map((s) => s.name)]
                .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => subjectFilter = v ?? 'كل المواد'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: yearFilter,
              decoration: const InputDecoration(labelText: 'السنة'),
              items: ['كل السنوات', ...years]
                .map((v) => DropdownMenuItem(value: v, child: Text(v == 'كل السنوات' || v == 'غير مصنف' ? v : '${int.parse(v)-1}–$v'))).toList(),
              onChanged: (v) => setState(() => yearFilter = v ?? 'كل السنوات'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: roundFilter,
              decoration: const InputDecoration(labelText: 'الدور'),
              items: ['كل الأدوار', ...rounds]
                .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => roundFilter = v ?? 'كل الأدوار'),
            ),
            const SizedBox(height: 16),
            Text('النتائج: ${items.length}',
              style: const TextStyle(fontWeight: FontWeight.w900, )),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Text(subjectFilter == 'كل المواد'
                  ? 'ماكو أوراق مطابقة حالياً. الأرشيف يُحدّث تدريجياً.'
                  : 'أرشيف مادة $subjectFilter لهذا الاختيار قيد التجهيز، وسيظهر هنا بعد تصنيف الأوراق والتحقق منها.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.7)),
              )
            else
              ...items.map((item) => Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined, color: blue),
                  title: Text(item.subject.name,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${item.academicYear} • ${item.round}'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => SubjectScreen(
                      subject: item.subject,
                      initialYear: item.year,
                      initialKind: item.round,
                    ),
                  )),
                ),
              )),
          ],
        ),
      ),
    );
  }
}

class _ArchiveSearchItem {
  final Subject subject;
  final String year;
  final String round;
  final String path;
  const _ArchiveSearchItem(this.subject, this.year, this.round, this.path);
  String get academicYear {
    final endYear = int.tryParse(year);
    return endYear == null ? year : '${endYear - 1}–$endYear';
  }
}

class SubjectScreen extends StatefulWidget {
  final Subject subject;
  final String initialYear;
  final String initialKind;
  const SubjectScreen({super.key, required this.subject, this.initialYear = '2025', this.initialKind = 'الدور الأول'});
  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  late String kind;
  late String year;

  static const rounds = <String>[
    'التمهيدي','الدور الأول','الدور الثاني','الدور الثالث'
  ];

  @override
  void initState() {
    super.initState();
    final options = availableYears;
    year = options.contains(widget.initialYear)
        ? widget.initialYear
        : (options.isNotEmpty ? options.first : 'غير مصنف');
    final roundOptions = availableRounds;
    kind = roundOptions.contains(widget.initialKind)
        ? widget.initialKind
        : (roundOptions.isNotEmpty ? roundOptions.first : 'كل الصور');
  }

  // Arabic exam images classified by the printed academic year and exam round.
  static const Map<String, Map<String, List<String>>> arabicExams = {
    '2025': {
      'التمهيدي': ['assets/exams/arabic/FB_IMG_1792869997603.jpg'],
      'الدور الأول': ['assets/exams/arabic/FB_IMG_1792870030332.jpg'],
      'الدور الثاني': ['assets/exams/arabic/FB_IMG_1792870002244.jpg'],
      'الدور الثالث': ['assets/exams/arabic/FB_IMG_1792869993721.jpg', 'assets/exams/arabic/FB_IMG_1792870000103.jpg'],
    },
    '2024': {
      'التمهيدي': ['assets/exams/arabic/FB_IMG_1792869964620.jpg'],
      'الدور الأول': ['assets/exams/arabic/FB_IMG_1792870013556.jpg'],
      'الدور الثاني': ['assets/exams/arabic/FB_IMG_1792870004467.jpg'],
      'الدور الثالث': ['assets/exams/arabic/FB_IMG_1792870006365.jpg', 'assets/exams/arabic/FB_IMG_1792870008323.jpg', 'assets/exams/arabic/FB_IMG_1792870010077.jpg', 'assets/exams/arabic/FB_IMG_1792870011765.jpg'],
    },
    '2023': {
      'التمهيدي': ['assets/exams/arabic/FB_IMG_1792870015879.jpg'],
      'الدور الأول': ['assets/exams/arabic/FB_IMG_1792870017997.jpg'],
    },
    '2022': {
      'الدور الثاني': ['assets/exams/arabic/FB_IMG_1792870023756.jpg'],
      'الدور الثالث': ['assets/exams/arabic/FB_IMG_1792870021692.jpg'],
    },
    '2021': {
      'الدور الثاني': ['assets/exams/arabic/FB_IMG_1792870025323.jpg'],
      'الدور الأول': ['assets/exams/arabic/FB_IMG_1792870027167.jpg'],
      'التمهيدي': ['assets/exams/arabic/FB_IMG_1792870028788.jpg'],
    },
  };


  List<String> get availableYears {
    final Map<String, Map<String, List<String>>>? classified =
        widget.subject.name == 'اللغة العربية'
            ? arabicExams
            : widget.subject.name == 'الكيمياء'
                ? chemistryExams
                : null;
    if (classified != null) {
      final values = classified.keys.toList()
        ..sort((a, b) => int.parse(b).compareTo(int.parse(a)));
      if ((unclassifiedExamImages[widget.subject.name] ?? const []).isNotEmpty) {
        values.add('غير مصنف');
      }
      return values;
    }
    return (unclassifiedExamImages[widget.subject.name] ?? const []).isNotEmpty
        ? ['غير مصنف']
        : <String>[];
  }

  List<String> get availableRounds {
    if (year == 'غير مصنف') return const ['كل الصور'];
    final Map<String, List<String>>? selectedYear =
        widget.subject.name == 'اللغة العربية'
            ? arabicExams[year]
            : widget.subject.name == 'الكيمياء'
                ? chemistryExams[year]
                : null;
    final available = selectedYear?.keys.toSet() ?? <String>{};
    return rounds.where(available.contains).toList();
  }

  List<String> get selectedImages {
    if (year == 'غير مصنف') {
      return unclassifiedExamImages[widget.subject.name] ?? const <String>[];
    }
    final Map<String, List<String>>? selectedYear =
        widget.subject.name == 'اللغة العربية'
            ? arabicExams[year]
            : widget.subject.name == 'الكيمياء'
                ? chemistryExams[year]
                : null;
    return selectedYear?[kind] ?? const <String>[];
  }

  String get academicYear {
    if (year == 'غير مصنف') return 'غير مصنف';
    final endYear = int.tryParse(year);
    return endYear == null ? year : '${endYear - 1}–$endYear';
  }

  void openImages(List<String> paths, int initialIndex) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _ExamImageViewer(
        images: paths,
        initialIndex: initialIndex,
        title: widget.subject.name,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final images = selectedImages;
    final years = availableYears;
    final roundsForYear = availableRounds;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.subject.name,
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: widget.subject.color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(children: [
                Icon(widget.subject.icon, color: widget.subject.color, size: 35),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('أرشيف ${widget.subject.name}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    if (widget.subject.name == 'اللغة العربية')
                      const Text('ويشمل مادة التربية الإسلامية',
                        style: TextStyle(fontSize: 12, height: 1.6)),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 22),
            const Text('السنة الدراسية',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (years.isNotEmpty)
              DropdownButtonFormField<String>(
                value: year,
                decoration: InputDecoration(
                  filled: true, fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: years.map((y) => DropdownMenuItem(
                  value: y,
                  child: Text(y == 'غير مصنف' ? y : '${int.parse(y)-1}–$y'),
                )).toList(),
                onChanged: (v) => setState(() {
                  year = v ?? years.first;
                  final nextRounds = availableRounds;
                  kind = nextRounds.isNotEmpty ? nextRounds.first : 'كل الصور';
                }),
              )
            else
              const Text('لا توجد صور مضافة لهذه المادة حالياً.'),
            const SizedBox(height: 18),
            const Text('الدور الامتحاني',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: roundsForYear.map((v) => ChoiceChip(
                label: Text(v), selected: kind == v,
                onSelected: (_) => setState(() => kind = v),
              )).toList(),
            ),
            const SizedBox(height: 22),
            if (images.isNotEmpty) ...[
              Text(
                year == 'غير مصنف'
                    ? 'صور ${widget.subject.name} • تحتاج تحديد السنة والدور'
                    : 'أسئلة ${widget.subject.name} • $academicYear • $kind',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              if (year == 'غير مصنف') ...[
                const SizedBox(height: 6),
                Text(
                  'هذه الصور موجودة فعلياً في مجلد المادة، لكن لم نتحقق بعد من السنة والدور المطبوعين عليها؛ لذلك لم ننسبها إلى امتحان محدد.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ...images.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Material(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => openImages(images, entry.key),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            const Icon(Icons.description_outlined, color: blue),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              images.length > 1 ? 'ورقة ${entry.key + 1}' : 'ورقة الأسئلة',
                              style: const TextStyle(fontWeight: FontWeight.w800))),
                            IconButton(
                              tooltip: SavedExamsStore.contains(entry.value)
                                  ? 'إزالة من المحفوظات' : 'حفظ للمراجعة',
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  final saved = await SavedExamsStore.toggle({
                                    'path': entry.value,
                                    'subject': widget.subject.name,
                                    'year': academicYear,
                                    'round': kind,
                                  });
                                  if (!mounted || !messenger.mounted) return;
                                  setState(() {});
                                  messenger.showSnackBar(SnackBar(
                                    content: Text(saved
                                      ? 'انحفظت الورقة بالمحفوظات'
                                      : 'انحذفت الورقة من المحفوظات'),
                                    duration: const Duration(seconds: 2),
                                  ));
                                } catch (_) {
                                  if (!messenger.mounted) return;
                                  messenger.showSnackBar(const SnackBar(
                                    content: Text('تعذر حفظ الورقة على الجهاز'),
                                  ));
                                }
                              },
                              icon: Icon(
                                SavedExamsStore.contains(entry.value)
                                  ? Icons.bookmark : Icons.bookmark_border,
                                color: blue,
                              ),
                            ),
                          ]),
                        ),
                        Image.asset(
                          entry.value,
                          fit: BoxFit.contain,
                          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded || frame != null) return child;
                            return const SizedBox(
                              height: 190,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (_, __, ___) => const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('الصورة غير متاحة حالياً، جرّب تحديث التطبيق.',
                              textAlign: TextAlign.center),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('اضغط على الصورة للتكبير واسحب للتنقل بين الأوراق',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
            ] else
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(children: [
                  Icon(Icons.photo_library_outlined, size: 48,
                      color: widget.subject.color),
                  const SizedBox(height: 12),
                  const Text('لا توجد صورة لهذا الاختيار حالياً',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text(
                    'جرّب سنة أو دوراً آخر. الصور التي لم نتحقق من سنتها ودورها تظهر ضمن خيار «غير مصنف».',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.8),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExamImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String title;
  const _ExamImageViewer({
    required this.images,
    required this.initialIndex,
    required this.title,
  });

  @override
  State<_ExamImageViewer> createState() => _ExamImageViewerState();
}

class _ExamImageViewerState extends State<_ExamImageViewer> {
  late final PageController _controller;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${widget.title} • ${_currentPage + 1}/${widget.images.length}'),
        ),
        body: PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemBuilder: (context, index) => Center(
            child: InteractiveViewer(
              minScale: 0.7,
              maxScale: 6,
              child: Image.asset(
                widget.images[index],
                fit: BoxFit.contain,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return const Center(child: CircularProgressIndicator(
                    color: Colors.white,
                  ));
                },
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('تعذر تحميل هذه الصورة. تحقق من اتصالك أو حدّث التطبيق.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, height: 1.7)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Saved extends StatelessWidget {
  final VoidCallback? onOpenCatalog;

  const Saved({super.key, this.onOpenCatalog});

  void _openArchive(BuildContext context) {
    final stage = AcademicStageController.current.value;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => stage == AcademicStage.intermediateThird
          ? const ArchiveSearchScreen()
          : StageContentPlaceholderScreen(stage: stage,
              title: 'الأرشيف الوزاري'),
    ));
  }

  void _openCatalog(BuildContext context) {
    Navigator.pop(context);
    if (onOpenCatalog != null) {
      onOpenCatalog!();
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => Catalog(onOpen: (_) {}),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المحفوظات'),
          centerTitle: false,
        ),
        body: ValueListenableBuilder<List<Map<String, String>>>(
          valueListenable: SavedExamsStore.items,
          builder: (context, saved, _) {
            if (saved.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 94,
                            height: 94,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withValues(alpha: .65),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Icon(Icons.bookmarks_outlined,
                              size: 48, color: colors.primary),
                          ),
                          const SizedBox(height: 20),
                          Text('محفوظاتك بانتظارك',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: colors.onSurface,
                            )),
                          const SizedBox(height: 8),
                          Text(
                            'ما حفظت أي ورقة لحد الآن. اختَر مادة أو افتح الأرشيف واحفظ أوراقك المهمة حتى ترجع إلها بسرعة.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              height: 1.7,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _openCatalog(context),
                              icon: const Icon(Icons.menu_book_rounded),
                              label: const Text('استكشاف المواد'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _openArchive(context),
                              icon: const Icon(Icons.archive_outlined),
                              label: const Text('فتح الأرشيف الوزاري'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                Text('أوراقي المحفوظة',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  )),
                const SizedBox(height: 5),
                Text('${saved.length} ورقة محفوظة للمراجعة',
                  style: TextStyle(color: colors.onSurfaceVariant)),
                const SizedBox(height: 16),
                ...saved.map((exam) {
                  final path = exam['path'] ?? '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 11),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: path.isEmpty ? null : () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => Directionality(
                            textDirection: TextDirection.rtl,
                            child: Scaffold(
                              backgroundColor: Colors.black,
                              appBar: AppBar(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                title: Text(exam['subject'] ?? 'صورة الامتحان'),
                              ),
                              body: Center(
                                child: InteractiveViewer(
                                  minScale: 0.8,
                                  maxScale: 5,
                                  child: Image.asset(
                                    path,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                        'تعذر عرض هذه الورقة لأن ملف الصورة غير متوفر داخل التطبيق.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ));
                      },
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 54,
                            height: 64,
                            child: path.isEmpty
                                ? Icon(Icons.description_outlined, color: colors.primary)
                                : Image.asset(
                                    path,
                                    width: 54,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: colors.surfaceContainerHighest,
                                      alignment: Alignment.center,
                                      child: Icon(Icons.description_outlined,
                                        color: colors.onSurfaceVariant),
                                    ),
                                  ),
                          ),
                        ),
                        title: Text(exam['subject'] ?? 'مادة دراسية',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${exam['year'] ?? ''} • ${exam['round'] ?? ''}'),
                        trailing: IconButton(
                          tooltip: 'إزالة من المحفوظات',
                          icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent),
                          onPressed: () async {
                            try {
                              await SavedExamsStore.remove(path);
                            } catch (_) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تعذر حذف الورقة حالياً')),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PersonalizationScreen extends StatelessWidget {
  const PersonalizationScreen({super.key});

  static const _paletteNames = ['الأزرق الأصلي', 'الأخضر الهادئ', 'البنفسجي', 'الذهبي'];
  static const _paletteDots = [
    Color(0xFF2868D7), Color(0xFF16866A),
    Color(0xFF7652C7), Color(0xFFB87524),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تخصيص التطبيق')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('اختر المظهر الذي يريحك أثناء الدراسة.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.6)),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('لون التطبيق والخلفية',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<int>(
                      valueListenable: ThemeController.paletteIndex,
                      builder: (context, selected, _) => Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: List.generate(_paletteNames.length, (index) =>
                          ChoiceChip(
                            avatar: CircleAvatar(
                              radius: 8, backgroundColor: _paletteDots[index]),
                            label: Text(_paletteNames[index]),
                            selected: selected == index,
                            onSelected: (_) => ThemeController.setPalette(index),
                          )),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('تتغير ألوان الواجهة مع بقاء ألوان النصوص متوافقة مع الوضع النهاري والليلي.',
                      style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('حجم الخط',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<double>(
                      valueListenable: ThemeController.fontScale,
                      builder: (context, selected, _) => SegmentedButton<double>(
                        segments: const [
                          ButtonSegment(value: .95, label: Text('مريح')),
                          ButtonSegment(value: 1.0, label: Text('متوسط')),
                          ButtonSegment(value: 1.08, label: Text('أكبر')),
                        ],
                        selected: {selected},
                        onSelectionChanged: (value) =>
                          ThemeController.setFontScale(value.first),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text('يمكنك تكبير النصوص قليلاً لتسهيل القراءة.',
                      style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('طابع بطاقات الكتب',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<int>(
                      valueListenable: ThemeController.bookCardStyle,
                      builder: (context, selected, _) => Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(label: const Text('هادئ'), selected: selected == 0,
                            onSelected: (_) => ThemeController.setBookCardStyle(0)),
                          ChoiceChip(label: const Text('بلون المادة'), selected: selected == 1,
                            onSelected: (_) => ThemeController.setBookCardStyle(1)),
                          ChoiceChip(label: const Text('بلون الثيم'), selected: selected == 2,
                            onSelected: (_) => ThemeController.setBookCardStyle(2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('استدارة البطاقات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<double>(
                    valueListenable: ThemeController.cardRadius,
                    builder: (context, value, _) => SegmentedButton<double>(
                      segments: const [
                        ButtonSegment(value: 12, label: Text('ناعمة')),
                        ButtonSegment(value: 18, label: Text('متوازنة')),
                        ButtonSegment(value: 24, label: Text('دائرية')),
                      ],
                      selected: {value},
                      onSelectionChanged: (v) => ThemeController.setCardRadius(v.first),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(children: [
                ValueListenableBuilder<bool>(
                  valueListenable: ThemeController.motionEnabled,
                  builder: (context, value, _) => SwitchListTile(
                    secondary: const Icon(Icons.animation_rounded),
                    title: const Text('الحركات الناعمة', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('التحكم بالحركات البصرية في عناصر التطبيق'),
                    value: value,
                    onChanged: ThemeController.setMotionEnabled,
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: ThemeController.eyeCare,
                  builder: (context, value, _) => SwitchListTile(
                    secondary: const Icon(Icons.visibility_rounded),
                    title: const Text('وضع راحة العين', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('دفء خفيف للألوان أثناء المذاكرة الطويلة'),
                    value: value,
                    onChanged: ThemeController.setEyeCare,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await ThemeController.restoreDefaults();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('تمت استعادة المظهر الافتراضي.')));
                }
              },
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('استعادة الإعدادات الافتراضية'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 12),
            Text('تُحفظ اختياراتك على هذا الجهاز، ولا تؤثر في المحفوظات أو ملفات الكتب أو بيانات المساعد الذكي.',
              style: TextStyle(fontSize: 12, height: 1.6, color: colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}


class StudyNotesScreen extends StatefulWidget {
  final List<String>? subjectNames;
  final String storageScope;

  const StudyNotesScreen({
    super.key,
    this.subjectNames,
    this.storageScope = '',
  });
  @override
  State<StudyNotesScreen> createState() => _StudyNotesScreenState();
}

class _StudyNotesScreenState extends State<StudyNotesScreen> {
  static const _legacy = 'dalilak_subject_note_v1_';
  static const _prefix = 'dalilak_subject_notes_v2_';
  late String _subject;
  List<Map<String, String>> _notes = [];
  bool _loading = true;

  List<String> get _subjectNames =>
      widget.subjectNames ?? subjects.map((subject) => subject.name).toList();

  String get _key => widget.storageScope.isEmpty
      ? '$_prefix$_subject'
      : '$_prefix${widget.storageScope}_$_subject';

  @override
  void initState() {
    super.initState();
    _subject = _subjectNames.isNotEmpty ? _subjectNames.first : subjects.first.name;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    var items = <Map<String, String>>[];
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          items = decoded.whereType<Map>()
              .map((e) => Map<String, String>.from(e)).toList();
        }
      } catch (_) {}
    } else if (widget.storageScope.isEmpty) {
      final old = prefs.getString('$_legacy$_subject') ?? '';
      if (old.trim().isNotEmpty) {
        items = [{
          'id': DateTime.now().microsecondsSinceEpoch.toString(),
          'title': 'ملاحظة سابقة',
          'body': old,
        }];
        await prefs.setString(_key, jsonEncode(items));
      }
    }
    if (mounted) {
      setState(() {
        _notes = items;
        _loading = false;
      });
    }
  }

  Future<void> _persist(List<Map<String, String>> updated) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(updated));
    if (mounted) setState(() => _notes = updated);
  }

  Future<void> _createNote() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => StudyNoteEditorScreen(subject: _subject),
      ),
    );
    if (result == null || !mounted) return;
    final item = <String, String>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'title': result['title'] ?? '',
      'body': result['body'] ?? '',
    };
    await _persist([item, ..._notes]);
  }

  Future<void> _openNote(Map<String, String> note) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => StudyNoteDetailScreen(
          subject: _subject,
          note: Map<String, String>.from(note),
          onUpdate: (updatedNote) {
            final updated = _notes.map((entry) =>
              entry['id'] == updatedNote['id']
                  ? Map<String, String>.from(updatedNote)
                  : entry).toList();
            _persist(updated);
          },
          onDelete: (id) {
            final updated = _notes.where((entry) => entry['id'] != id).toList();
            _persist(updated);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مفكرة المراجعة')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createNote,
          icon: const Icon(Icons.add_rounded),
          label: const Text('ملاحظة جديدة'),
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            Card(
              color: colors.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Icon(Icons.edit_note_rounded,
                      color: colors.onPrimaryContainer, size: 27),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'نظّم قوانينك وتعريفاتك وملاحظاتك حسب المادة. لكل ملاحظة عنوان مستقل ونص كامل قابل للقراءة والتعديل.',
                      style: TextStyle(
                        color: colors.onPrimaryContainer, height: 1.55),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _subject,
              decoration: const InputDecoration(
                labelText: 'اختر المادة',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.menu_book_rounded),
              ),
              items: _subjectNames.map((name) => DropdownMenuItem(
                value: name,
                child: Text(name),
              )).toList(),
              onChanged: (value) async {
                if (value == null || value == _subject) return;
                setState(() => _subject = value);
                await _load();
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text('ملاحظات ${_notes.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 18))),
                TextButton.icon(
                  onPressed: _createNote,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة'),
                ),
              ],
            ),
            const SizedBox(height: 7),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )),
            if (!_loading && _notes.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 26),
                  child: Column(
                    children: [
                      Icon(Icons.sticky_note_2_outlined,
                        size: 42, color: colors.primary),
                      const SizedBox(height: 9),
                      const Text('ما عندك ملاحظات لهذه المادة بعد',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text('اضغط «ملاحظة جديدة» حتى تحفظ أول ملاحظة.',
                        style: TextStyle(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ..._notes.map((note) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openNote(note),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 42, height: 46,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.description_outlined,
                          color: colors.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(note['title'] ?? 'ملاحظة بدون عنوان',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15)),
                          const SizedBox(height: 5),
                          Text(note['body'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              height: 1.45, fontSize: 12,
                              color: colors.onSurfaceVariant)),
                        ],
                      )),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_left_rounded,
                        color: colors.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class StudyNoteEditorScreen extends StatefulWidget {
  final String subject;
  final String? initialTitle;
  final String? initialBody;

  const StudyNoteEditorScreen({
    super.key,
    required this.subject,
    this.initialTitle,
    this.initialBody,
  });

  @override
  State<StudyNoteEditorScreen> createState() => _StudyNoteEditorScreenState();
}

class _StudyNoteEditorScreenState extends State<StudyNoteEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;

  bool get _isEditing => widget.initialTitle != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle ?? '');
    _body = TextEditingController(text: widget.initialBody ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('اكتب عنوان الملاحظة ونصها الكامل أولاً.'),
      ));
      return;
    }
    Navigator.pop(context, <String, String>{
      'title': title,
      'body': body,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'تعديل الملاحظة' : 'ملاحظة جديدة'),
          actions: [
            IconButton(
              tooltip: 'حفظ',
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(widget.subject,
                style: TextStyle(
                  color: colors.primary, fontWeight: FontWeight.w900)),
              const SizedBox(height: 18),
              Text('عنوان الملاحظة',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface)),
              const SizedBox(height: 8),
              TextField(
                controller: _title,
                maxLength: 80,
                textDirection: TextDirection.rtl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'مثلاً: قوانين الفصل الأول',
                  prefixIcon: Icon(Icons.title_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('الملاحظة الكاملة',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface)),
              const SizedBox(height: 8),
              TextField(
                controller: _body,
                minLines: 12,
                maxLines: 24,
                maxLength: 10000,
                keyboardType: TextInputType.multiline,
                textDirection: TextDirection.rtl,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  hintText: 'اكتب الشرح أو القوانين أو نقاط المراجعة هنا...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_isEditing ? 'حفظ التعديلات' : 'حفظ الملاحظة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudyNoteDetailScreen extends StatefulWidget {
  final String subject;
  final Map<String, String> note;
  final ValueChanged<Map<String, String>> onUpdate;
  final ValueChanged<String> onDelete;

  const StudyNoteDetailScreen({
    super.key,
    required this.subject,
    required this.note,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<StudyNoteDetailScreen> createState() => _StudyNoteDetailScreenState();
}

class _StudyNoteDetailScreenState extends State<StudyNoteDetailScreen> {
  late Map<String, String> _note;

  @override
  void initState() {
    super.initState();
    _note = Map<String, String>.from(widget.note);
  }

  Future<void> _edit() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => StudyNoteEditorScreen(
          subject: widget.subject,
          initialTitle: _note['title'] ?? '',
          initialBody: _note['body'] ?? '',
        ),
      ),
    );
    if (result == null || !mounted) return;
    final updated = <String, String>{
      ..._note,
      'title': result['title'] ?? '',
      'body': result['body'] ?? '',
    };
    setState(() => _note = updated);
    widget.onUpdate(updated);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الملاحظة؟'),
          content: const Text(
            'سيتم حذف هذه الملاحظة نهائياً من جهازك. هل تريد المتابعة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف نهائياً'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.onDelete(_note['id'] ?? '');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الملاحظة')),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.menu_book_rounded,
                          color: colors.primary, size: 19),
                        const SizedBox(width: 7),
                        Text(widget.subject,
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(_note['title'] ?? '',
                      style: TextStyle(
                        fontSize: 25,
                        height: 1.4,
                        fontWeight: FontWeight.w900,
                        color: colors.onSurface)),
                    const SizedBox(height: 18),
                    Divider(color: colors.outlineVariant),
                    const SizedBox(height: 14),
                    SelectableText(
                      _note['body'] ?? '',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.9,
                        letterSpacing: .1,
                        color: colors.onSurface),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _edit,
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('تعديل'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final text = (_note['body'] ?? '').trim();
                        if (text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('لا يوجد نص لنسخه')),
                          );
                          return;
                        }
                        await Clipboard.setData(ClipboardData(text: text));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم نسخ نص الملاحظة بنجاح'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('نسخ النص'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'حذف الملاحظة',
                      onPressed: _delete,
                      style: IconButton.styleFrom(
                        foregroundColor: colors.error,
                        side: BorderSide(color: colors.error),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewsPost {
  final String id, title, body, category, date;
  final bool pinned;
  const NewsPost({required this.id, required this.title, required this.body,
    required this.category, required this.date, this.pinned = false});
  factory NewsPost.fromJson(Map<String, dynamic> json) => NewsPost(
    id: (json['id'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    body: (json['body'] ?? '').toString(),
    category: (json['category'] ?? 'updates').toString(),
    date: (json['date'] ?? '').toString(),
    pinned: json['pinned'] == true,
  );
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});
  @override State<NewsScreen> createState() => _NewsScreenState();
}
class _NewsScreenState extends State<NewsScreen> {
  // The PIN is entered by the owner and checked only by the Cloudflare Worker.
  static final Uri _workerNewsUri = Uri.parse(
    'https://wispy-union-276e.dhwa634.workers.dev/news');
  static final Uri _feedUri = Uri.parse(
    'https://raw.githubusercontent.com/dhwa634-collab/wizariyat-privacy/main/news.json');
  static const Map<String, String> _categories = {
    'all': 'الكل', 'updates': 'المستجدات', 'tips': 'نصائح دراسية',
    'students': 'تنويهات الطلبة / الخارجي', 'app': 'إرشادات التطبيق',
  };
  static const List<NewsPost> _fallback = [
    NewsPost(id:'welcome', title:'مرحباً بك في مساحة أخبار دليلك للنجاح',
      body:'ستظهر هنا أخبار التطبيق والتنويهات والنصائح التي ينشرها المطوّر. عند توفر اتصال ستُحدّث المنشورات من المصدر الرسمي.',
      category:'updates', date:'2026-11-21', pinned:true),
    NewsPost(id:'study-tip', title:'اجعل مراجعتك على مراحل قصيرة',
      body:'قسّم الدرس إلى أجزاء، ثم اختبر نفسك بسؤال أو مثال بعد كل جزء. خصص وقتاً لمراجعة الأخطاء قبل الانتقال إلى موضوع جديد.',
      category:'tips', date:'2026-11-21'),
    NewsPost(id:'external-students', title:'تنويه لطلبة الدراسة الخارجية',
      body:'تابع الإعلانات الرسمية الصادرة من وزارة التربية والمديريات المعنية، وتأكد من المواعيد والتعليمات من مصادرها الرسمية.',
      category:'students', date:'2026-11-21'),
    NewsPost(id:'app-guide', title:'كيف تستفيد من أدوات التطبيق؟',
      body:'استخدم المؤقت لتنظيم جلساتك، واحفظ الأوراق المهمة، وافتح ملفات PDF داخل التطبيق للعودة إليها بسهولة.',
      category:'app', date:'2026-11-21'),
  ];
  List<NewsPost> _posts = _fallback;
  String _selected = 'all';
  bool _loading = false;
  @override void initState() { super.initState(); _loadNews(); }
  Future<void> _loadNews() async {
    if (!mounted) return;
    setState(() => _loading = true);
    var loadedFromWorker = false;
    try {
      http.Response response;
      try {
        response = await http.get(_workerNewsUri,
          headers: const {'Accept':'application/json', 'Cache-Control':'no-cache'})
          .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) throw Exception('Worker news unavailable');
        final workerDecoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (workerDecoded is! Map || workerDecoded['posts'] is! List) {
          throw const FormatException('Invalid Worker news feed');
        }
        loadedFromWorker = true;
      } catch (_) {
        response = await http.get(_feedUri,
          headers: const {'Accept':'application/json', 'Cache-Control':'no-cache'})
          .timeout(const Duration(seconds: 12));
      }
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded['posts'] is! List) {
        throw const FormatException('Invalid news feed');
      }
      final posts = (decoded['posts'] as List)
        .whereType<Map>().map((e) => NewsPost.fromJson(Map<String,dynamic>.from(e)))
        .where((p) => p.id.isNotEmpty && p.title.isNotEmpty && p.body.isNotEmpty).toList();
      posts.sort((a,b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.date.compareTo(a.date);
      });
      // An empty Worker feed is intentional after the owner deletes all posts.
      if (posts.isEmpty && !loadedFromWorker) {
        throw const FormatException('Empty news feed');
      }
      if (mounted) setState(() { _posts = posts; });
    } catch (_) {
      if (mounted) setState(() { _posts = _fallback; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  Future<void> _openDeveloperTools() async {
    final controller = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
        title: const Text('دخول أدوات المطوّر'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.visiblePassword,
          maxLength: 64,
          decoration: const InputDecoration(
            labelText: 'رمز المطوّر',
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('تحقق ودخول')),
        ],
      )),
    );
    controller.dispose();
    if (!mounted || entered == null) return;

    final pin = entered.trim();
    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رمز المطوّر أولاً.')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://wispy-union-276e.dhwa634.workers.dev/news/admin'),
        headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'action': 'verify', 'pin': pin}),
      ).timeout(const Duration(seconds: 15));

      Map<String, dynamic> result = {};
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map) result = Map<String, dynamic>.from(decoded);
      } catch (_) {}

      if (response.statusCode != 200 || result['success'] != true ||
          result['verified'] != true) {
        final code = (result['code'] ?? '').toString();
        final detail = (result['error'] ?? 'رفض الخادم التحقق من الرمز.').toString();
        if (code == 'UNKNOWN_NEWS_ADMIN_ACTION' ||
            detail.contains('عملية إدارة الأخبار غير معروفة') ||
            detail.contains('عملية إدارة الأخبار غير مدعومة')) {
          throw Exception(
            'نسخة Cloudflare Worker المنشورة قديمة ولا تدعم التحقق من رمز المطوّر. '
            'يجب نشر الملف worker/src/index.js من فرع التطوير على Worker wispy-union-276e.',
          );
        }
        throw Exception('HTTP ${response.statusCode}: $detail');
      }

      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => NewsAdminScreen(adminPin: pin),
      ));
      if (mounted) await _loadNews();
    } catch (error) {
      if (mounted) {
        final details = error.toString().replaceFirst('Exception: ', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            details.isEmpty
              ? 'تعذر فتح غرفة المطوّر. تحقق من اتصال الخادم وإعداداته.'
              : 'تعذر فتح غرفة المطوّر: $details',
          )),
        );
      }
    }
  }
  Future<void> _share(NewsPost post) async {
    final text = '${post.title}\n\n${post.body}\n\nمن تطبيق دليلك للنجاح — الثالث متوسط • العراق';
    try { await Share.share(text, subject: post.title); }
    catch (_) {
      await Clipboard.setData(ClipboardData(text:text));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم نسخ نص الخبر للمشاركة.')));
    }
  }
  @override Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visible = _posts.where((p) => _selected == 'all' || p.category == _selected).toList();
    return Directionality(textDirection:TextDirection.rtl, child:Scaffold(
      appBar:AppBar(title:GestureDetector(
        onLongPress: _openDeveloperTools,
        child: const Text('الأخبار'),
      ), actions:[
        IconButton(tooltip:'تحديث الأخبار', onPressed:_loading ? null : _loadNews,
          icon:const Icon(Icons.refresh_rounded))
      ]),
      body:RefreshIndicator(onRefresh:_loadNews, child:ListView(
        padding:const EdgeInsets.all(16), children:[
          Container(padding:const EdgeInsets.all(16),
            decoration:BoxDecoration(
              gradient:LinearGradient(colors:[colors.primary, colors.primary.withValues(alpha:.78)]),
              borderRadius:BorderRadius.circular(20)),
            child:const Row(children:[
              Icon(Icons.campaign_rounded,color:Colors.white,size:30),
              SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('مساحة دليلك للأخبار',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:17)),
                SizedBox(height:4),
                Text('تنويهات موثوقة ونصائح تساعدك في رحلتك الدراسية',style:TextStyle(color:Colors.white70,height:1.5,fontSize:12))
              ]))
            ])),
          const SizedBox(height:14),

          if (_loading) const LinearProgressIndicator(),
          const SizedBox(height:10),
          SingleChildScrollView(scrollDirection:Axis.horizontal, child:Row(children:
            _categories.entries.map((entry)=>Padding(
              padding:const EdgeInsetsDirectional.only(end:7),
              child:ChoiceChip(label:Text(entry.value),selected:_selected==entry.key,
                onSelected:(_)=>setState(()=>_selected=entry.key)),
            )).toList())),
          const SizedBox(height:12),
          if (visible.isEmpty) const Padding(padding:EdgeInsets.all(28),
            child:Center(child:Text('لا توجد منشورات في هذا التصنيف حالياً.'))),
          ...visible.map((post)=>Card(
            margin:const EdgeInsets.only(bottom:11),
            child:Padding(padding:const EdgeInsets.all(15), child:Column(
              crossAxisAlignment:CrossAxisAlignment.start, children:[
                Row(children:[
                  if(post.pinned) ...[
                    const Icon(Icons.push_pin_rounded,color:Color(0xFFD49A2A),size:17),
                    const SizedBox(width:5),
                    const Text('مثبّت',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900,color:Color(0xFFD49A2A))),
                    const SizedBox(width:8),
                  ],
                  Expanded(child:Align(
                    alignment:AlignmentDirectional.centerStart,
                    child:Container(
                      padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                      decoration:BoxDecoration(
                        color:colors.primaryContainer.withValues(alpha:.72),
                        borderRadius:BorderRadius.circular(20),
                      ),
                      child:Text(_categories[post.category] ?? 'مستجدات',
                        style:TextStyle(fontSize:11,color:colors.onPrimaryContainer,fontWeight:FontWeight.w800)),
                    ),
                  )),
                  Text(post.date,style:TextStyle(fontSize:11,color:colors.onSurfaceVariant)),
                ]),
                const SizedBox(height:8),
                Text(post.title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),
                const SizedBox(height:8),
                Text(post.body,style:TextStyle(height:1.7,color:colors.onSurfaceVariant)),
                Align(alignment:AlignmentDirectional.centerEnd,
                  child:TextButton.icon(onPressed:()=>_share(post),
                    icon:const Icon(Icons.share_rounded,size:17),label:const Text('مشاركة الخبر'))),
              ]))),
          ),
          const SizedBox(height:18),
          Text('المحتوى الإخباري ينشره مطوّر التطبيق فقط. راجع المصادر الرسمية للمواعيد والقرارات الدراسية.',
            style:TextStyle(fontSize:11,height:1.6,color:colors.onSurfaceVariant)),
        ])),
    ));
  }
}

class NewsAdminScreen extends StatefulWidget {
  final String adminPin;
  const NewsAdminScreen({super.key, required this.adminPin});
  @override State<NewsAdminScreen> createState() => _NewsAdminScreenState();
}
class _NewsAdminScreenState extends State<NewsAdminScreen> {
  static final Uri _workerNewsUri = Uri.parse('https://wispy-union-276e.dhwa634.workers.dev/news');
  static final Uri _workerAdminUri = Uri.parse('https://wispy-union-276e.dhwa634.workers.dev/news/admin');
  static final Uri _workerStatusUri = Uri.parse('https://wispy-union-276e.dhwa634.workers.dev/news/status');
  static final Uri _fallbackFeedUri = Uri.parse('https://raw.githubusercontent.com/dhwa634-collab/wizariyat-privacy/main/news.json');
  static const Map<String,String> _categories = {
    'updates':'المستجدات','tips':'نصائح دراسية',
    'students':'تنويهات الطلبة / الخارجي','app':'إرشادات التطبيق',
  };
  final _title=TextEditingController(), _body=TextEditingController();
  String _category='updates', _workerStatus='جارٍ الفحص...';
  bool _pinned=false, _loading=true, _working=false, _kvConnected=false;
  String? _editingId;
  List<Map<String,dynamic>> _existing=[];
  int get _pinnedCount => _existing.where((p)=>p['pinned']==true).length;
  Map<String,int> get _categoryCounts {
    final result=<String,int>{for(final key in _categories.keys) key:0};
    for(final post in _existing) {
      final key=(post['category']??'updates').toString();
      if(result.containsKey(key)) result[key]=result[key]!+1;
    }
    return result;
  }
  @override void initState(){super.initState();_loadExisting();}
  Future<Map<String,dynamic>?> _readFeed(Uri uri) async {
    final response=await http.get(uri,headers:const {'Accept':'application/json','Cache-Control':'no-cache'})
      .timeout(const Duration(seconds:12));
    if(response.statusCode!=200)return null;
    final decoded=jsonDecode(utf8.decode(response.bodyBytes));
    if(decoded is! Map || decoded['posts'] is! List)return null;
    return Map<String,dynamic>.from(decoded);
  }
  Future<void> _checkWorker() async {
    try {
      final response=await http.get(_workerStatusUri,headers:const {
        'Accept':'application/json',
        'Cache-Control':'no-cache',
      }).timeout(const Duration(seconds:10));
      Map<String,dynamic> decoded={};
      try {
        final value=jsonDecode(utf8.decode(response.bodyBytes));
        if(value is Map) decoded=Map<String,dynamic>.from(value);
      } catch (_) {}
      final connected=response.statusCode==200 &&
          decoded['success']==true && decoded['connected']==true &&
          decoded['storage']=='AI_REPORTS';
      if(!mounted)return;
      setState((){
        _kvConnected=connected;
        if(connected) {
          _workerStatus='متصل • KV يعمل';
        } else if(response.statusCode==405) {
          _workerStatus='Worker يحتاج نشر النسخة المحدّثة • 405';
        } else {
          final detail=(decoded['error']??'HTTP ${response.statusCode}').toString();
          _workerStatus='غير متصل بـ KV • $detail';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _kvConnected = false;
          _workerStatus = 'تعذر الوصول إلى Worker';
        });
      }
    }
  }
  Future<void> _loadExisting() async {
    if(mounted)setState(()=>_loading=true);
    await _checkWorker();
    try {
      var feed=await _readFeed(_workerNewsUri);
      feed??=await _readFeed(_fallbackFeedUri);
      if(feed!=null){
        _existing=(feed['posts'] as List).whereType<Map>()
          .map((e)=>Map<String,dynamic>.from(e)).toList();
        _existing.sort((x,y){
          final xp=x['pinned']==true, yp=y['pinned']==true;
          if(xp!=yp)return xp?-1:1;
          return (y['date']??'').toString().compareTo((x['date']??'').toString());
        });
      }
    } catch (_) {}
    if(mounted)setState(()=>_loading=false);
  }
  String get _adminPin => widget.adminPin.trim();
  Future<Map<String,dynamic>> _send(Map<String,dynamic> payload) async {
    final response=await http.post(_workerAdminUri,
      headers:const {'Content-Type':'application/json','Accept':'application/json'},
      body:jsonEncode({...payload,'pin':_adminPin}))
      .timeout(const Duration(seconds:18));
    Map<String,dynamic> decoded={};
    try {final value=jsonDecode(utf8.decode(response.bodyBytes));if(value is Map)decoded=Map<String,dynamic>.from(value);}catch(_){}
    if (response.statusCode != 200 || decoded['success'] != true) {
      throw Exception((decoded['error'] ?? 'تعذر تنفيذ العملية على خادم الأخبار').toString());
    }
    return decoded;
  }
  void _apply(Map<String,dynamic> result){
    final feed=result['feed'];
    if (feed is Map && feed['posts'] is List) {
      _existing = (feed['posts'] as List).whereType<Map>()
          .map((e) => Map<String,dynamic>.from(e)).toList();
    }
  }
  void _clearEditor(){_title.clear();_body.clear();_category='updates';_pinned=false;_editingId=null;}
  void _edit(Map<String,dynamic> post){
    setState((){
      _editingId=(post['id']??'').toString();
      _title.text=(post['title']??'').toString();
      _body.text=(post['body']??'').toString();
      final c=(post['category']??'updates').toString();
      _category=_categories.containsKey(c)?c:'updates';
      _pinned=post['pinned']==true;
    });
  }
  Future<void> _save() async {
    final title=_title.text.trim(), body=_body.text.trim();
    if(title.isEmpty||body.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('اكتب عنوان الخبر ونصه أولاً.')));return;
    }
    setState(()=>_working=true);
    try{
      final editing=_editingId!=null && _editingId!.isNotEmpty;
      final result=await _send({
        'action':editing?'update':'publish',
        if(editing)'id':_editingId,
        'post':{'title':title,'body':body,'category':_category,'pinned':_pinned},
      });
      _apply(result);_clearEditor();await _checkWorker();
      if(mounted){setState((){});ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(editing?'تم تعديل الخبر بنجاح.':'تم نشر الخبر بنجاح.')));}
    }catch(error){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر حفظ الخبر: $error')));
    }finally{if(mounted)setState(()=>_working=false);}
  }
  Future<void> _togglePin(Map<String,dynamic> post) async {
    final id=(post['id']??'').toString();if(id.isEmpty)return;
    setState(()=>_working=true);
    try{final result=await _send({'action':'togglePin','id':id,'pinned':post['pinned']!=true});
      _apply(result);
      if(mounted){
        setState((){});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:Text(post['pinned']==true?'تم إلغاء تثبيت الخبر.':'تم تثبيت الخبر بنجاح.')));
      }
    }catch(error){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تغيير التثبيت: $error')));}
    finally{if(mounted)setState(()=>_working=false);}
  }
  Future<void> _sharePost(Map<String,dynamic> post) async {
    final title=(post['title']??'').toString(), body=(post['body']??'').toString();
    final text='$title\n\n$body\n\nمن تطبيق دليلك للنجاح — الثالث متوسط • العراق';
    try{await Share.share(text,subject:title);}catch(_){
      await Clipboard.setData(ClipboardData(text:text));
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم نسخ الخبر للمشاركة.')));
    }
  }
  Future<void> _delete(Map<String,dynamic> post) async {
    final id=(post['id']??'').toString();if(id.isEmpty)return;
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>Directionality(
      textDirection:TextDirection.rtl,child:AlertDialog(
        title:const Text('تأكيد حذف الخبر'),
        content:Text('هل تريد حذف الخبر «${(post['title'] ?? '').toString()}» نهائياً؟'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حذف الخبر')),
        ],
      )));
    if(yes!=true||!mounted)return;
    setState(()=>_working=true);
    try{final result=await _send({'action':'delete','id':id});_apply(result);
      if(_editingId==id)_clearEditor();
      if(mounted){
        setState((){});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:Text('تم حذف الخبر بنجاح.')));
      }
    }catch(error){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر حذف الخبر: $error')));}
    finally{if(mounted)setState(()=>_working=false);}
  }
  @override void dispose(){_title.dispose();_body.dispose();super.dispose();}
  Widget _stat(String title,String value,IconData icon,Color color)=>Expanded(child:Card(
    child:Padding(padding:const EdgeInsets.symmetric(vertical:12,horizontal:8),
      child:Column(children:[Icon(icon,color:color),const SizedBox(height:5),
        Text(value,style:TextStyle(fontWeight:FontWeight.w900,fontSize:19,color:color)),
        Text(title,textAlign:TextAlign.center,style:TextStyle(fontSize:10,color:Theme.of(context).colorScheme.onSurfaceVariant)),
      ]))));
  @override Widget build(BuildContext context){
    final colors=Theme.of(context).colorScheme;
    final previewTitle=_title.text.trim(), previewBody=_body.text.trim();
    return Directionality(textDirection:TextDirection.rtl,child:Scaffold(
      appBar:AppBar(title:const Text('استوديو أخبار دليلك')),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Card(child:Padding(padding:const EdgeInsets.all(13),child:Column(children:[
          Row(children:[
            Icon(Icons.admin_panel_settings_rounded,color:colors.primary),
            const SizedBox(width:8),
            const Expanded(child:Text('إدارة الأخبار وفحص اتصال التخزين السحابي.')),
            IconButton(tooltip:'فحص Worker وKV',onPressed:_working?null:_checkWorker,icon:const Icon(Icons.cloud_sync_rounded)),
          ]),
          Row(children:[
            Icon(_kvConnected?Icons.cloud_done_rounded:Icons.cloud_off_rounded,
              color:_kvConnected?const Color(0xFF16866A):colors.error),
            const SizedBox(width:7),Expanded(child:Text(_workerStatus,
              style:TextStyle(fontWeight:FontWeight.w800,color:_kvConnected?const Color(0xFF16866A):colors.error))),
          ]),
        ]))),
        Row(children:[
          _stat('كل الأخبار',_existing.length.toString(),Icons.article_rounded,colors.primary),
          _stat('المثبّتة',_pinnedCount.toString(),Icons.push_pin_rounded,const Color(0xFFD49A2A)),
        ]),
        Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('التوزيع حسب التصنيف',style:TextStyle(fontWeight:FontWeight.w900)),
            Wrap(spacing:6,runSpacing:5,children:_categories.entries.map((e)=>Chip(
              avatar:CircleAvatar(radius:10,child:Text(_categoryCounts[e.key].toString(),style:const TextStyle(fontSize:10))),
              label:Text(e.value),visualDensity:VisualDensity.compact,
            )).toList()),
          ]))),
        TextField(controller:_title,onChanged:(_)=>setState((){}),maxLength:100,
          decoration:const InputDecoration(labelText:'عنوان الخبر',border:OutlineInputBorder())),
        const SizedBox(height:10),
        DropdownButtonFormField<String>(value:_category,
          decoration:const InputDecoration(labelText:'تصنيف الخبر',border:OutlineInputBorder()),
          items:const[
            DropdownMenuItem(value:'updates',child:Text('المستجدات')),
            DropdownMenuItem(value:'tips',child:Text('نصائح دراسية')),
            DropdownMenuItem(value:'students',child:Text('تنويهات الطلبة / الخارجي')),
            DropdownMenuItem(value:'app',child:Text('إرشادات التطبيق')),
          ],onChanged:(v)=>setState(()=>_category=v??'updates')),
        const SizedBox(height:10),
        TextField(controller:_body,onChanged:(_)=>setState((){}),minLines:4,maxLines:8,maxLength:2000,
          decoration:const InputDecoration(labelText:'نص الخبر',alignLabelWithHint:true,border:OutlineInputBorder())),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:_pinned,
          onChanged:(v)=>setState(()=>_pinned=v),title:const Text('تثبيت الخبر في أعلى القائمة')),
        if(previewTitle.isNotEmpty||previewBody.isNotEmpty)Card(child:Padding(
          padding:const EdgeInsets.all(13),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('معاينة بطاقة الخبر',style:TextStyle(fontWeight:FontWeight.w900)),
            Wrap(spacing:6,children:[
              Chip(label:Text(_categories[_category]??'المستجدات'),visualDensity:VisualDensity.compact),
              if(_pinned)const Chip(avatar:Icon(Icons.push_pin_rounded,size:14),label:Text('مثبّت'),visualDensity:VisualDensity.compact),
            ]),
            Text(previewTitle.isEmpty?'عنوان الخبر':previewTitle,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),
            const SizedBox(height:6),Text(previewBody),
          ]))),
        FilledButton.icon(onPressed:_working?null:_save,
          icon:_working?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))
            :Icon(_editingId==null?Icons.publish_rounded:Icons.save_rounded),
          label:Text(_working?'جارٍ الحفظ...':_editingId==null?'نشر الخبر':'حفظ التعديلات')),
        if(_editingId!=null)TextButton(onPressed:_working?null:()=>setState(_clearEditor),
          child:const Text('إلغاء التعديل')),
        const SizedBox(height:18),
        Row(children:[
          const Expanded(child:Text('المنشورات الحالية',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900))),
          IconButton(tooltip:'تحديث القائمة',onPressed:_working?null:_loadExisting,icon:const Icon(Icons.refresh_rounded)),
        ]),
        if(_loading)const LinearProgressIndicator(),
        if(!_loading&&_existing.isEmpty)const Padding(padding:EdgeInsets.all(18),
          child:Text('لا توجد أخبار محفوظة في المصدر الحالي.',textAlign:TextAlign.center)),
        ..._existing.map((post)=>Card(margin:const EdgeInsets.only(bottom:9),
          child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Expanded(child:Text((post['title']??'خبر بلا عنوان').toString(),maxLines:2,overflow:TextOverflow.ellipsis,
                style:const TextStyle(fontWeight:FontWeight.w900))),
              if(post['pinned']==true)const Icon(Icons.push_pin_rounded,color:Color(0xFFD49A2A)),
            ]),
            Wrap(spacing:6,crossAxisAlignment:WrapCrossAlignment.center,children:[
              Chip(label:Text(_categories[(post['category']??'updates').toString()]??'مستجدات'),visualDensity:VisualDensity.compact),
              Text((post['date']??'').toString(),style:TextStyle(fontSize:11,color:colors.onSurfaceVariant)),
            ]),
            Text((post['body']??'').toString(),maxLines:3,overflow:TextOverflow.ellipsis),
            const Divider(height:14),
            Wrap(spacing:2,children:[
              TextButton.icon(onPressed:_working?null:()=>_edit(post),icon:const Icon(Icons.edit_rounded,size:17),label:const Text('تعديل')),
              TextButton.icon(onPressed:_working?null:()=>_togglePin(post),
                icon:const Icon(Icons.push_pin_rounded,size:17),label:Text(post['pinned']==true?'إلغاء التثبيت':'تثبيت')),
              TextButton.icon(onPressed:_working?null:()=>_sharePost(post),icon:const Icon(Icons.share_rounded,size:17),label:const Text('مشاركة')),
              TextButton.icon(onPressed:_working?null:()=>_delete(post),icon:const Icon(Icons.delete_outline_rounded,size:17,color:Colors.redAccent),
                label:const Text('حذف',style:TextStyle(color:Colors.redAccent))),
            ]),
          ])))),
      ]),
    ));
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const String _appName = 'وزاريات الثالث متوسط';
  static const String _packageName = 'com.fitna.game';
  static const String _storeUrl =
      'https://play.google.com/store/apps/details?id=com.fitna.game';

  Future<void> _sendSuggestion(BuildContext context) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ملاحظة أو اقتراح'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'اكتب ملاحظتك أو اقتراحك لتحسين التطبيق...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext, controller.text.trim()),
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
    final note = message?.trim() ?? '';
    controller.dispose();
    if (note.isEmpty || !context.mounted) return;

    final emailUri = Uri(
      scheme: 'mailto',
      path: 'dhwalfqar666@gmail.com',
      queryParameters: {
        'subject': 'ملاحظة أو اقتراح - $_appName',
        'body': note,
      },
    );
    try {
      final opened = await launchUrl(emailUri);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'لم نعثر على تطبيق بريد. يمكنك مراسلتنا على '
            'dhwalfqar666@gmail.com'),
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر فتح تطبيق البريد. راسلنا على '
              'dhwalfqar666@gmail.com'),
        ));
      }
    }
  }

  Future<void> _shareApp(BuildContext context) async {
    const shareText = 'جرّب تطبيق وزاريات الثالث متوسط لمراجعة المواد '
        'والأوراق الامتحانية والاستفادة من المساعد الدراسي.\n'
        'رابط التطبيق على Google Play: $_storeUrl';
    try {
      await Share.share(shareText, subject: _appName);
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: shareText));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذرت المشاركة المباشرة؛ نُسخ رابط التطبيق لتتمكن من إرساله.'),
        ));
      }
    }
  }

  Future<void> _rateApp(BuildContext context) async {
    final marketUri = Uri.parse('market://details?id=$_packageName');
    final webUri = Uri.parse(_storeUrl);
    try {
      final opened = await launchUrl(marketUri);
      if (!opened) {
        final webOpened = await launchUrl(
          webUri, mode: LaunchMode.externalApplication);
        if (!webOpened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('سيظهر خيار التقييم بعد نشر التطبيق على Google Play.'),
          ));
        }
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر فتح صفحة Google Play حالياً.'),
          ));
        }
      }
    }
  }

  Future<void> _clearSaved(BuildContext context) async {
    final count = SavedExamsStore.items.value.length;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لا توجد محفوظات لمسحها.'),
      ));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
          title: const Text('مسح جميع المحفوظات؟'),
          content: Text(
            'سيتم حذف $count من العناصر المحفوظة من هذا الجهاز نهائياً. '
            'لا يمكن التراجع عن هذه العملية.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('مسح الكل'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await SavedExamsStore.clearAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم مسح جميع المحفوظات بنجاح.'),
      ));
    }
  }

  Widget _sectionTitle(BuildContext context, String title, IconData icon) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 9),
        child: Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 21),
          const SizedBox(width: 9),
          Text(title, style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
          )),
        ]),
      );

  Widget _actionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Widget? trailing,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      minLeadingWidth: 28,
      leading: Icon(icon, size: 25,
        color: iconColor ?? Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(
        fontWeight: FontWeight.w800, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(height: 1.4, fontSize: 12)),
      trailing: trailing ?? const Icon(Icons.chevron_left_rounded),
      onTap: onTap,
    ),
  );

  Widget _infoBlock(BuildContext context, String title, String body,
      {IconData? icon, Color? iconColor}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: iconColor ?? colors.primary),
            const SizedBox(width: 10),
          ],
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                fontWeight: FontWeight.w900, color: colors.onSurface)),
              const SizedBox(height: 5),
              Text(body, style: TextStyle(
                height: 1.65, color: colors.onSurfaceVariant, fontSize: 13)),
            ],
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        key: const PageStorageKey<String>('more_screen'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF173D78), Color(0xFF2675E8)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x29173D78),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Row(children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: Colors.white24,
                child: Icon(Icons.school_rounded, color: Colors.white, size: 30),
              ),
              SizedBox(width: 13),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_appName, style: TextStyle(
                    color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text('رفيقك في المراجعة والاستعداد للامتحانات',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              )),
            ]),
          ),

          _sectionTitle(context, 'المظهر والتخصيص', Icons.palette_outlined),
          _actionTile(
            context: context,
            icon: Icons.tune_rounded,
            title: 'تخصيص شكل التطبيق',
            subtitle: 'الألوان والخطوط وطابع بطاقات الكتب',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const PersonalizationScreen())),
          ),

          _sectionTitle(context, 'الحساب', Icons.manage_accounts_outlined),
          const MoreAccountSection(),

          _actionTile(
            context: context,
            icon: Icons.edit_note_rounded,
            title: 'إرسال ملاحظة أو اقتراح',
            subtitle: 'شاركنا رأيك وأفكارك لتطوير التطبيق',
            onTap: () => _sendSuggestion(context),
          ),
          _actionTile(
            context: context,
            icon: Icons.share_rounded,
            title: 'مشاركة التطبيق',
            subtitle: 'أرسل رابط التطبيق إلى أصدقائك',
            onTap: () => _shareApp(context),
          ),
          _actionTile(
            context: context,
            icon: Icons.star_outline_rounded,
            title: 'تقييم التطبيق ودعم التطوير',
            subtitle: 'افتح صفحة التطبيق على Google Play',
            onTap: () => _rateApp(context),
          ),

          _sectionTitle(context, 'الخصوصية والبيانات', Icons.shield_outlined),
          _actionTile(
            context: context,
            icon: Icons.privacy_tip_outlined,
            title: 'سياسة الخصوصية',
            subtitle: 'تفاصيل البيانات والمساعد الذكي والبلاغات',
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const PrivacyScreen())),
          ),
          ValueListenableBuilder<List<Map<String, String>>>(
            valueListenable: SavedExamsStore.items,
            builder: (context, saved, _) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 5),
                  leading: Icon(Icons.bookmarks_outlined,
                    color: colors.primary, size: 25),
                  title: const Text('المحفوظات',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('لديك ${saved.length} عنصر محفوظ على هذا الجهاز'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () {
                    // The bottom navigation's Saved tab remains the full manager.
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('عدد العناصر المحفوظة: ${saved.length}'),
                    ));
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 2),
                  leading: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent),
                  title: const Text('مسح جميع المحفوظات',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  trailing: const Icon(Icons.chevron_left_rounded, size: 20),
                  onTap: () => _clearSaved(context),
                ),
              ]),
            ),
          ),

          _sectionTitle(context, 'المعلومات والشفافية', Icons.info_outline_rounded),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoBlock(context, 'نبذة عن التطبيق',
                    'منصة تعليمية مستقلة تساعد طلبة الثالث متوسط في العراق '
                    'على مراجعة المواد والأوراق الامتحانية والاستفادة من '
                    'المساعد الدراسي.'),
                  _infoBlock(context, 'استقلالية التطبيق',
                    'هذا التطبيق مستقل وغير تابع لوزارة التربية العراقية '
                    'أو لأي جهة حكومية، ولا يمثلها أو يتحدث باسمها.',
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.orange),
                  _infoBlock(context, 'شروط الاستخدام وإخلاء المسؤولية التعليمية',
                    'يُقدَّم المحتوى لأغراض المراجعة والمساعدة التعليمية فقط. '
                    'قد تحدث أخطاء أو نواقص في الأرشيف أو الإجابات المولدة '
                    'آلياً؛ لذلك لا يُعد التطبيق بديلاً عن الكتاب المدرسي '
                    'أو المدرس أو التعليمات الرسمية، وعلى الطالب التحقق من '
                    'المعلومات قبل اعتمادها.'),
                  _infoBlock(context, 'ضوابط الأرشيف',
                    'تُصنّف الأوراق حسب المادة والسنة والدور استناداً إلى '
                    'المعلومات المتاحة. لا يُنسب سؤال إلى امتحان وزاري دون '
                    'قرينة مناسبة، وقد تكون بعض المواد أو السنوات قيد '
                    'التجهيز والتحقق. يُرجى مطابقة الأسئلة والحلول مع '
                    'المصادر الدراسية الموثوقة.',
                    icon: Icons.fact_check_outlined),
                ],
              ),
            ),
          ),

          const SizedBox(height: 15),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.verified_outlined, color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('إصدار التطبيق  1.1.0',
                    style: TextStyle(
                      fontWeight: FontWeight.w900, color: colors.onSurface)),
                ]),
                const SizedBox(height: 8),
                Text('صُنع لمساندة رحلتك الدراسية',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12, color: colors.onSurfaceVariant)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}


class MoreAccountSection extends StatefulWidget {
  const MoreAccountSection({super.key});

  @override
  State<MoreAccountSection> createState() => _MoreAccountSectionState();
}

class _MoreAccountSectionState extends State<MoreAccountSection> {
  bool _busy = false;
  final _client = Supabase.instance.client;

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
      ));
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await signOutStudentSession();
      _showMessage('تم تسجيل الخروج من حسابك بنجاح.');
    } catch (error) {
      _showMessage("تعذر تسجيل الخروج: ${error.toString().replaceFirst('Exception: ', '')}",
        isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_busy) return;
    final user = _client.auth.currentUser;
    if (user == null) {
      _showMessage('لا يوجد حساب مسجّل الدخول حالياً.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          title: const Text('حذف الحساب نهائياً؟'),
          content: const Text(
            'سيتم حذف حسابك وملفك الشخصي ورسائلك وملفاتك الصوتية والملصقات '
            'المرتبطة به من الخادم. لا يمكن التراجع عن هذه العملية.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف الحساب'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final response = await _client.functions.invoke(
        'delete-account',
        body: const {'confirm': true},
      );
      final data = response.data;
      if (response.status < 200 || response.status >= 300 ||
          data is! Map || data['success'] != true) {
        final detail = data is Map ? (data['error'] ?? '').toString() : '';
        throw Exception(detail.isEmpty
          ? 'لم يؤكد الخادم حذف الحساب (HTTP ${response.status}).'
          : detail);
      }

      await signOutStudentSession();
      _showMessage('تم حذف حسابك وبياناته بنجاح.');
    } catch (error) {
      _showMessage(
        "تعذر حذف الحساب: ${error.toString().replaceFirst('Exception: ', '')}",
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: _client.auth.onAuthStateChange,
    builder: (context, snapshot) {
      final user = snapshot.hasData
        ? snapshot.data!.session?.user
        : _client.auth.currentUser;
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('حالة الحساب',
              style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(user == null
              ? 'تستخدم التطبيق حالياً دون تسجيل الدخول.'
              : (user.email ?? 'حساب Google مسجّل')),
          ),
          if (user == null)
            ListTile(
              leading: const Icon(Icons.login_rounded),
              title: const Text('تسجيل الدخول بواسطة Google'),
              onTap: _busy ? null : () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StudentGoogleLoginScreen())),
            )
          else ...[
            const Divider(height: 1),
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.logout_rounded),
              title: const Text('تسجيل الخروج'),
              subtitle: const Text('إنهاء جلسة الحساب على هذا الجهاز'),
              trailing: _busy
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_left_rounded),
              onTap: _busy ? null : _signOut,
            ),
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.delete_forever_outlined,
                color: Colors.redAccent),
              title: const Text('حذف الحساب نهائياً',
                style: TextStyle(color: Colors.redAccent,
                  fontWeight: FontWeight.w800)),
              subtitle: const Text('حذف بيانات الحساب من الخادم بعد التأكيد'),
              trailing: const Icon(Icons.chevron_left_rounded,
                color: Colors.redAccent),
              onTap: _busy ? null : _deleteAccount,
            ),
          ],
          if (_busy) const LinearProgressIndicator(minHeight: 2),
        ]),
      );
    },
  );
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static final Uri _policyUri = Uri.parse(
    'https://dhwa634-collab.github.io/wizariyat-privacy/',
  );

  Future<void> _openFullPolicy(BuildContext context) async {
    try {
      final opened = await launchUrl(
        _policyUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر فتح صفحة سياسة الخصوصية. تحقق من اتصال الإنترنت.'),
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر فتح صفحة سياسة الخصوصية. حاول مرة ثانية.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF243A5B) : const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.privacy_tip_outlined, color: blue, size: 28),
                SizedBox(width: 12),
                Expanded(child: Text(
                  'يمكنك الاطلاع على سياسة الخصوصية الكاملة والمحدّثة للتطبيق، بما في ذلك البيانات التي تتم معالجتها، والمساعد الذكي، والبلاغات، ومدة الاحتفاظ بالمعلومات.',
                  style: TextStyle( height: 1.7),
                )),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.open_in_browser, color: blue),
              title: const Text('عرض سياسة الخصوصية كاملة',
                style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('فتح النسخة المنشورة والمحدّثة'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _openFullPolicy(context),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'تُفتح الصفحة الرسمية للسياسة عبر اتصال الإنترنت. عند تحديث السياسة مستقبلاً سيبقى هذا الرابط نفسه صالحاً.',
            style: TextStyle( height: 1.7, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class StageBookResourceScreen extends StatelessWidget {
  final AcademicStage stage;
  final StageSubjectInfo subject;
  const StageBookResourceScreen({
    super.key, required this.stage, required this.subject,
  });

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: Text('كتاب ${subject.name}')),
      body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.picture_as_pdf_rounded, size: 58,
            color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text('كتاب ${subject.name} — ${stage.label}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            'المصدر المدرج حالياً هو صفحة فهرس وليست وصلة PDF مباشرة. '
            'حتى لا نفتح رابطاً خارجياً أو ننزّل صفحة ويب على أنها كتاب، '
            'سيظهر هنا خيار القراءة الداخلية فور إضافة ملف PDF موثوق.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.65,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text('الطبعة المدرجة: ${subject.edition}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      )),
    ),
  );
}

class StageInternalArchiveScreen extends StatelessWidget {
  final AcademicStage stage;
  final List<StageSubjectInfo> subjects;
  final bool isReview;
  const StageInternalArchiveScreen({
    super.key, required this.stage, required this.subjects,
    required this.isReview,
  });

  @override
  Widget build(BuildContext context) {
    final title = isReview ? 'المراجعة المركزة' : 'الأرشيف الوزاري';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text('$title • ${stage.label}')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('اختر المادة', style: const TextStyle(
              fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ...subjects.map((subject) => Card(
              child: ListTile(
                leading: Icon(subject.icon, color: subject.color),
                title: Text(subject.name,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('المحتوى الداخلي المرفوع لهذه المادة'),
                trailing: const Icon(Icons.arrow_outward_rounded),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(subject.name),
                    content: const Text(
                      'لا توجد حالياً صور أو ملفات لهذه المرحلة والمادة داخل مستودع التطبيق. '
                      'ستظهر هنا مباشرة بعد رفع الملفات، بدون فتح روابط خارجية.',
                      textDirection: TextDirection.rtl,
                    ),
                    actions: [TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('حسناً'),
                    )],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class SolutionsHubScreen extends StatefulWidget {
  final List<Subject> availableSubjects;
  final String stageLabel;
  const SolutionsHubScreen({
    super.key,
    this.availableSubjects = subjects,
    this.stageLabel = 'الثالث المتوسط',
  });
  @override State<SolutionsHubScreen> createState() => _SolutionsHubScreenState();
}
class _SolutionsHubScreenState extends State<SolutionsHubScreen> {
  late Subject selected;
  @override
  void initState() {
    super.initState();
    selected = widget.availableSubjects.first;
  }
  final questionController = TextEditingController();
  @override void dispose() { questionController.dispose(); super.dispose(); }
  void _requestSolution() {
    final question = questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب السؤال أولاً حتى نقدر نشرحه.')));
      return;
    }
    final prompt = 'أريد حلاً نموذجياً تعليمياً لسؤال من مادة ${selected.name} للمرحلة ${widget.stageLabel} في العراق. '
      'اشرح الحل خطوة بخطوة، واذكر القانون أو القاعدة عند الحاجة، ثم اكتب الجواب النهائي بوضوح. '
      'إذا كانت المعطيات غير كافية فاطلب توضيحاً ولا تخمّن. السؤال: $question';
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AiAssistantScreen(initialPrompt: prompt)));
  }
  @override Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(appBar: AppBar(title: const Text('الحلول النموذجية')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18)),
          child: const Text('حدد المادة واكتب السؤال، وسيشرح لك المساعد الدراسي طريقة الحل خطوة بخطوة. الإجابات مولّدة بالذكاء الاصطناعي وليست نماذج وزارية رسمية؛ راجعها مع الكتاب والمدرس.',
            style: TextStyle(height: 1.7))),
        const SizedBox(height: 18),
        const Text('المادة الدراسية', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        DropdownButtonFormField<Subject>(value: selected,
          items: widget.availableSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
          onChanged: (value) { if (value != null) setState(() => selected = value); }),
        const SizedBox(height: 14),
        TextField(controller: questionController, minLines: 4, maxLines: 8,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(labelText: 'نص السؤال',
            hintText: 'اكتب السؤال أو المسألة هنا', alignLabelWithHint: true,
            border: OutlineInputBorder())),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _requestSolution,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('اشرح الحل خطوة بخطوة')),
      ])));
}

class SearchSaveScreen extends StatefulWidget {
  const SearchSaveScreen({super.key});
  @override State<SearchSaveScreen> createState() => _SearchSaveScreenState();
}
class _SearchSaveScreenState extends State<SearchSaveScreen> {
  final queryController = TextEditingController();
  String subjectFilter = 'كل المواد';
  List<_ArchiveSearchItem> get results {
    final query = queryController.text.trim().toLowerCase();
    return _getAvailableArchiveItems().where((item) {
      final metadata = '${item.subject.name} ${item.academicYear} ${item.round}'.toLowerCase();
      return (query.isEmpty || metadata.contains(query)) &&
        (subjectFilter == 'كل المواد' || item.subject.name == subjectFilter);
    }).toList();
  }
  @override void dispose() { queryController.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final matches = results;
    return Directionality(textDirection: TextDirection.rtl,
      child: Scaffold(appBar: AppBar(title: const Text('بحث وحفظ سريع')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: queryController, onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'ابحث باسم المادة أو السنة أو الدور',
              prefixIcon: Icon(Icons.search), border: OutlineInputBorder())),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: subjectFilter,
            decoration: const InputDecoration(labelText: 'تصفية حسب المادة'),
            items: ['كل المواد', ...subjects.map((s) => s.name)]
              .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => subjectFilter = v ?? 'كل المواد')),
          const SizedBox(height: 14),
          Text('نتائج البحث: ${matches.length}',
            style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (matches.isEmpty)
            const Padding(padding: EdgeInsets.all(22),
              child: Text('ما لقينا أوراقاً مطابقة ضمن الأرشيف المصنّف حالياً. جرّب مادة أو سنة أخرى.',
                textAlign: TextAlign.center, style: TextStyle(height: 1.7)))
          else
            ...matches.map((item) => Card(child: ListTile(
              leading: const Icon(Icons.description_outlined, color: blue),
              title: Text(item.subject.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${item.academicYear} • ${item.round}'),
              trailing: IconButton(
                tooltip: SavedExamsStore.contains(item.path) ? 'إزالة من المحفوظات' : 'حفظ للمراجعة',
                icon: Icon(SavedExamsStore.contains(item.path) ? Icons.bookmark : Icons.bookmark_border, color: blue),
                onPressed: () async {
                  await SavedExamsStore.toggle({'path': item.path, 'subject': item.subject.name,
                    'year': item.academicYear, 'round': item.round});
                  if (mounted) setState(() {});
                }),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => SubjectScreen(subject: item.subject,
                  initialYear: item.year, initialKind: item.round))),
            ))),
          const SizedBox(height: 10),
          Text('البحث يشمل بيانات الأوراق المصنّفة (المادة والسنة والدور)، ولا يقرأ النص داخل الصور تلقائياً.',
            style: TextStyle(fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6)),
        ])));
  }
}
List<_ArchiveSearchItem> _getAvailableArchiveItems() {
  final result = <_ArchiveSearchItem>[];
  for (final entry in _SubjectScreenState.arabicExams.entries) {
    for (final round in entry.value.entries) {
      for (final path in round.value) {
        result.add(_ArchiveSearchItem(subjects.firstWhere((item) => item.name == 'اللغة العربية'), entry.key, round.key, path));
      }
    }
  }
  for (final entry in chemistryExams.entries) {
    final subject = archiveSubjects.firstWhere((item) => item.name == 'الكيمياء');
    for (final round in entry.value.entries) {
      for (final path in round.value) {
        result.add(_ArchiveSearchItem(subject, entry.key, round.key, path));
      }
    }
  }
  for (final entry in unclassifiedExamImages.entries) {
    final subject = archiveSubjects.firstWhere((item) => item.name == entry.key);
    for (final path in entry.value) {
      result.add(_ArchiveSearchItem(subject, 'غير مصنف', 'كل الصور', path));
    }
  }
  return result;
}

class _HomeToolTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _HomeToolTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(color: colors.surfaceContainerHighest.withValues(alpha: .55), borderRadius: BorderRadius.circular(17), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(17), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: colors.primary, size: 25), const SizedBox(height: 8), Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, color: colors.onSurface, fontSize: 12.5)), const SizedBox(height: 3), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: colors.onSurfaceVariant))]))));
  }
}

class Feature extends StatelessWidget {
  final IconData icon; final String title, desc; final VoidCallback onTap;
  const Feature({super.key, required this.icon, required this.title,
    required this.desc, required this.onTap});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Material(color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(17),
        child: Padding(padding: const EdgeInsets.all(15),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: blue.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13)),
              child: Icon(icon, color: blue, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(desc, style: TextStyle(fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
            const Icon(Icons.chevron_left_rounded),
          ]))))); 
}


class _StudyThinkingIndicator extends StatefulWidget {
  const _StudyThinkingIndicator();

  @override
  State<_StudyThinkingIndicator> createState() => _StudyThinkingIndicatorState();
}

class _StudyThinkingIndicatorState extends State<_StudyThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ...List.generate(3, (index) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final phase = (_controller.value * 3 - index).clamp(0.0, 1.0).toDouble();
          final scale = .65 + .35 * Curves.easeInOut.transform(phase);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .45 + index * .2),
            shape: BoxShape.circle,
          ),
        ),
      )),
      const SizedBox(width: 9),
      Text('جاري التفكير...', style: TextStyle(
        color: colors.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      )),
    ]);
  }
}

class AiAssistantScreen extends StatefulWidget {
  final String? initialPrompt;
  const AiAssistantScreen({super.key, this.initialPrompt});
  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const String endpoint = 'https://wispy-union-276e.dhwa634.workers.dev/chat';
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final List<Map<String, dynamic>> messages = [
    {'role': 'assistant', 'text': 'هلا بيك! آني مساعدك الدراسي. اسألني عن مواد الثالث المتوسط، وأشرحلك الحل خطوة بخطوة. وتكدر تسأل سؤال متابعة عن نفس الموضوع.'},
  ];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    final prompt = widget.initialPrompt?.trim();
    if (prompt != null && prompt.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        controller.text = prompt;
        send();
      });
    }
  }

  String _sanitizeStudentText(String value) {
    return value
        .replaceAll(RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false), '[بريد محذوف]')
        .replaceAll(RegExp(r'(?:\+?964|0)7[0-9]{9}'), '[رقم هاتف محذوف]');
  }

  Future<void> _reportAnswer({required String reportedAnswer}) async {
    const reasons = ['إجابة غير دقيقة', 'محتوى غير مناسب', 'مشكلة تقنية'];
    String selected = reasons.first;
    final noteController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('الإبلاغ عن الإجابة',
            style: TextStyle(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اختر سبب البلاغ:'),
                const SizedBox(height: 8),
                ...reasons.map((reason) => RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(reason, style: const TextStyle(fontSize: 14)),
                  value: reason,
                  groupValue: selected,
                  onChanged: (value) => setDialogState(() => selected = value ?? reasons.first),
                )),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  maxLength: 240,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة اختيارية',
                    hintText: 'لا تكتب اسمك أو رقم هاتفك أو أي معلومات شخصية',
                    border: OutlineInputBorder(),
                  ),
                ),
                const Text('سيُرسل سبب البلاغ ونص الإجابة المبلّغ عنها وملاحظتك الاختيارية إلى المطوّر لمراجعتها. لا نرسل نص سؤال الطالب.',
                  style: TextStyle(fontSize: 11,)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, {
              'category': selected,
              'note': _sanitizeStudentText(noteController.text).trim(),
            }), child: const Text('إرسال البلاغ')),
          ],
        ),
      ),
    );
    noteController.dispose();
    if (result == null || !mounted) return;
    try {
      final response = await http.post(
        Uri.parse(endpoint).replace(path: '/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'category': result['category'] ?? reasons.first,
          'note': result['note'] ?? '',
          'reportedAnswer': _sanitizeStudentText(reportedAnswer).length > 5000
              ? _sanitizeStudentText(reportedAnswer).substring(0, 5000)
              : _sanitizeStudentText(reportedAnswer),
        }),
      ).timeout(const Duration(seconds: 15));
      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}
      if (response.statusCode != 200 || data['success'] != true) {
        final message = (data['error'] ?? '').toString();
        throw Exception(message.isNotEmpty ? message : 'تعذر إرسال البلاغ حالياً.');
      }
      await AiReportStore.save(
        category: result['category'] ?? reasons.first,
        note: result['note'] ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('وصل بلاغك إلى المطوّر بنجاح. شكراً لمساعدتنا على تحسين التطبيق.'),
      ));
    } catch (error) {
      if (!mounted) return;
      final details = error.toString().replaceFirst('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          details.isEmpty
              ? 'تعذر إرسال البلاغ. تحقق من إعدادات الخادم وحاول مرة ثانية.'
              : 'فشل إرسال البلاغ: $details',
        ),
      ));
    }
  }

  Future<void> send() async {
    final enteredQuestion = controller.text.trim();
    if (enteredQuestion.isEmpty || loading) return;
    final question = _sanitizeStudentText(enteredQuestion);
    if (question != enteredQuestion) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('حذفنا رقم هاتف أو بريداً إلكترونياً واضحاً قبل إرسال السؤال.'),
      ));
    }
    controller.clear();
    setState(() {
      messages.add({'role': 'user', 'text': question});
      loading = true;
    });
    _scrollDown();
    await _requestAnswer(question);
  }

  Future<void> _requestAnswer(String question) async {
    try {
      final previous = messages.where((item) =>
        (item['role'] == 'user' || item['role'] == 'assistant') &&
        item['failed'] != true).toList();
      if (previous.isNotEmpty && previous.first['role'] == 'assistant' &&
          previous.first['text'].toString().startsWith('هلا بيك!')) {
        previous.removeAt(0);
      }
      if (previous.isNotEmpty && previous.last['role'] == 'user' &&
          previous.last['text'] == question) {
        previous.removeLast();
      }
      final history = previous.reversed.take(10).toList().reversed
          .map((item) => {'role': item['role'], 'text': item['text']}).toList();

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': question, 'history': history}),
      ).timeout(const Duration(seconds: 55));

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      if (response.statusCode != 200) {
        final serverMessage = (data['error'] ?? '').toString();
        throw Exception(serverMessage.isNotEmpty
          ? serverMessage
          : 'الخادم لم يكمل الطلب (\${response.statusCode})');
      }
      final answer = (data['reply'] ?? '').toString().trim();
      if (answer.isEmpty) throw Exception('وصل رد فارغ. جرّب مرة ثانية.');
      if (!mounted) return;
      setState(() => messages.add({'role': 'assistant', 'text': answer}));
    } catch (error) {
      if (!mounted) return;
      final details = error.toString().replaceFirst('Exception: ', '');
      setState(() => messages.add({
        'role': 'assistant',
        'text': 'ما كدرت أجيب الإجابة هالمرة. تأكد من اتصال الإنترنت وجرب مرة ثانية.',
        'failed': true,
        'question': question,
        'details': details,
      }));
    } finally {
      if (mounted) {
        setState(() => loading = false);
        _scrollDown();
      }
    }
  }

  Future<void> _retry(String question) async {
    if (loading) return;
    setState(() {
      final index = messages.lastIndexWhere(
        (item) => item['failed'] == true && item['question'] == question);
      if (index >= 0) messages.removeAt(index);
      loading = true;
    });
    await _requestAnswer(question);
  }

  void _clearChat() {
    if (loading) return;
    setState(() {
      messages
        ..clear()
        ..add({
          'role': 'assistant',
          'text': 'بدأنا محادثة جديدة. اكتب سؤالك، وآني أساعدك بالشرح خطوة بخطوة.',
        });
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المساعد الذكي', style: TextStyle(fontWeight: FontWeight.w900)),
            Text('مساعدك لمواد الثالث المتوسط',
              style: TextStyle(fontSize: 11,)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'محادثة جديدة',
            onPressed: loading ? null : _clearChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF243A5B) : const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: blue),
                SizedBox(width: 9),
                Expanded(child: Text(
                  'اسأل وتابع بنفس المحادثة. تنبيه: الردود مولّدة بالذكاء الاصطناعي وقد تحتوي على أخطاء؛ راجع الحلول الدراسية والوزارية مع الكتاب المدرسي أو مدرسك، ولا تعتمد عليها وحدها.',
                  style: TextStyle( fontSize: 12, height: 1.55),
                )),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              itemCount: messages.length + (loading ? 1 : 0),
              itemBuilder: (context, index) {
                if (loading && index == messages.length) {
                  return const Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: _StudyThinkingIndicator(),
                    ),
                  );
                }
                final item = messages[index];
                final isUser = item['role'] == 'user';
                final failed = item['failed'] == true;
                final messageText = (item['text'] ?? '').toString();
                return Align(
                  alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * .88),
                    margin: const EdgeInsets.only(bottom: 11),
                    padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
                    decoration: BoxDecoration(
                      color: isUser ? blue : Theme.of(context).cardColor,
                      border: failed ? Border.all(color: Colors.orange.shade300) : null,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 5 : 18),
                        bottomRight: Radius.circular(isUser ? 18 : 5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(messageText, style: TextStyle(
                          color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurface,
                          height: 1.7, fontSize: 14.5)),
                        if (!isUser) ...[
                          const SizedBox(height: 5),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (failed)
                                TextButton.icon(
                                  onPressed: loading ? null : () => _retry(
                                    (item['question'] ?? '').toString()),
                                  icon: const Icon(Icons.refresh, size: 17),
                                  label: const Text('إعادة المحاولة'),
                                )
                              else ...[
                                IconButton(
                                  tooltip: 'نسخ الإجابة',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: messageText));
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(const SnackBar(
                                        content: Text('تم نسخ الإجابة'),
                                        duration: Duration(seconds: 2),
                                      ));
                                  },
                                  icon: const Icon(Icons.copy_rounded,
                                    size: 17,),
                                ),
                                TextButton.icon(
                                  onPressed: () => _reportAnswer(reportedAnswer: messageText),
                                  icon: const Icon(Icons.flag_outlined, size: 17),
                                  label: const Text('إبلاغ'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.blueGrey,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF172337)
                    : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2B3D56)
                        : const Color(0xFFE5EAF2),
                  ),
                ),
                boxShadow: [BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0x40000000)
                      : const Color(0x0D142D50),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                )],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: TextField(
                    controller: controller,
                    minLines: 1, maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => send(),
                    cursorColor: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF9FC2FF)
                        : blue,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFF5F8FF)
                          : const Color(0xFF172337),
                      fontSize: 15,
                      height: 1.45,
                    ),
                    decoration: InputDecoration(
                      hintText: 'اكتب سؤالك الدراسي هنا...',
                      hintStyle: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFB8C7DA)
                            : const Color(0xFF68778D),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1B2A40)
                          : bg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(17),
                        borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF40536D)
                              : const Color(0xFFDCE4F0),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(17),
                        borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF79A9FF)
                              : blue,
                          width: 1.6,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(17),
                        borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 13),
                    ),
                  )),
                  const SizedBox(width: 8),
                  SizedBox(width: 48, height: 48, child: IconButton.filled(
                    tooltip: 'إرسال السؤال',
                    onPressed: loading ? null : send,
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF79A9FF)
                          : blue,
                      foregroundColor: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF10213A)
                          : Colors.white,
                      disabledBackgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF34445A)
                              : const Color(0xFFB8C5D8),
                      disabledForegroundColor: Colors.white70,
                    ),
                    icon: const Icon(Icons.send_rounded),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

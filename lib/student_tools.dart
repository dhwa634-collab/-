import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// عدّل هذه التواريخ فقط عند صدور الجدول المعتمد.
class ExamDates {
  static const DateTime? preparatory = null;
  static const DateTime? ministerial = null;
}

class ExamCountdownSection extends StatefulWidget {
  const ExamCountdownSection({super.key});
  @override
  State<ExamCountdownSection> createState() => _ExamCountdownSectionState();
}
class _ExamCountdownSectionState extends State<ExamCountdownSection> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('موعد امتحاناتك القادمة',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
          color: colors.onSurface)),
      const SizedBox(height: 9),
      Row(children: [
        Expanded(child: _CountdownTile(title: 'الامتحانات التمهيدية',
          date: ExamDates.preparatory, icon: Icons.edit_calendar_rounded,
          tint: const Color(0xFF16866A))),
        const SizedBox(width: 10),
        Expanded(child: _CountdownTile(title: 'الامتحانات الوزارية',
          date: ExamDates.ministerial, icon: Icons.school_rounded,
          tint: const Color(0xFF2868D7))),
      ]),
      const SizedBox(height: 7),
      Text('المواعيد قابلة للتحديث وفق الجداول المعتمدة والإعلانات الرسمية.',
        style: TextStyle(fontSize: 11, height: 1.5,
          color: colors.onSurfaceVariant)),
    ]);
  }
}
class _CountdownTile extends StatelessWidget {
  final String title;
  final DateTime? date;
  final IconData icon;
  final Color tint;
  const _CountdownTile({required this.title, required this.date,
    required this.icon, required this.tint});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    String value;
    String detail;
    if (date == null) {
      value = 'لم يُعلن';
      detail = 'بانتظار الموعد المعتمد';
    } else {
      final difference = date!.difference(DateTime.now());
      if (difference.isNegative) {
        value = 'بدأ الموعد';
        detail = 'راجع الجدول الرسمي';
      } else {
        final days = difference.inDays;
        final hours = difference.inHours.remainder(24);
        value = days > 0 ? '$days يوم' : '${difference.inHours} ساعة';
        detail = days > 0 ? 'و $hours ساعة تقريباً' : 'متبقية';
      }
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: .25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: tint, size: 21),
        const SizedBox(height: 8),
        Text(title, maxLines: 2,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: colors.onSurfaceVariant)),
        const SizedBox(height: 5),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight,
          child: Text(value, style: TextStyle(fontSize: 19,
            fontWeight: FontWeight.w900, color: colors.onSurface))),
        Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
      ]),
    );
  }
}

class BookResource {
  final String subject;
  final String title;
  final String? url;
  const BookResource(this.subject, this.title, {this.url});
  bool get isAvailable => url != null && url!.trim().isNotEmpty;
}
/// أضف رابط HTTPS موثوقاً في url عند توفره.
const List<BookResource> studyBooks = [
  BookResource('التربية الإسلامية', 'كتاب التربية الإسلامية للثالث المتوسط'),
  BookResource('اللغة العربية', 'كتاب اللغة العربية للثالث المتوسط'),
  BookResource('اللغة الإنكليزية', 'كتاب اللغة الإنكليزية للثالث المتوسط'),
  BookResource('الرياضيات', 'كتاب الرياضيات للثالث المتوسط'),
  BookResource('الاجتماعيات', 'كتاب الاجتماعيات للثالث المتوسط'),
  BookResource('الأحياء', 'كتاب الأحياء للثالث المتوسط'),
  BookResource('الكيمياء', 'كتاب الكيمياء للثالث المتوسط'),
  BookResource('الفيزياء', 'كتاب الفيزياء للثالث المتوسط'),
];

class BooksLibraryScreen extends StatelessWidget {
  const BooksLibraryScreen({super.key});
  Future<void> _openBook(BuildContext context, BookResource book) async {
    if (!book.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('هذا الكتاب قيد التجهيز. سنضيف رابط PDF بعد التحقق من مصدره.')));
      return;
    }
    final uri = Uri.tryParse(book.url!);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('رابط الكتاب غير صالح.')));
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر فتح ملف PDF. تحقق من اتصال الإنترنت أو تطبيق قراءة PDF.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر فتح الكتاب حالياً. حاول مرة ثانية.')));
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الكتب المنهجية PDF')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(17)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.menu_book_rounded, color: colors.onPrimaryContainer, size: 27),
              const SizedBox(width: 11),
              Expanded(child: Text(
                'مكتبة كتب الثالث المتوسط. ستظهر الكتب المتاحة للفتح عند إضافة روابط PDF موثوقة.',
                style: TextStyle(height: 1.6, color: colors.onPrimaryContainer))),
            ]),
          ),
          const SizedBox(height: 12),
          ...studyBooks.map((book) {
            final ready = book.isAvailable;
            return Card(child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.picture_as_pdf_rounded)),
              title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(ready ? 'يتطلب اتصال إنترنت • PDF' : 'قيد التجهيز'),
              trailing: Icon(ready ? Icons.open_in_new_rounded : Icons.hourglass_top_rounded,
                color: ready ? colors.primary : colors.onSurfaceVariant),
              onTap: () => _openBook(context, book),
            ));
          }),
          const SizedBox(height: 8),
          Text('تنويه: لا تمثل هذه المكتبة جهة حكومية أو وزارة، ولا ننسب أي ملف إلى جهة رسمية إلا بعد التحقق من مصدره ومحتواه.',
            style: TextStyle(fontSize: 12, height: 1.65, color: colors.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});
  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}
class _PomodoroScreenState extends State<PomodoroScreen> with WidgetsBindingObserver {
  static const _prefix = 'study_pomodoro_v1_';
  Timer? _ticker;
  int _studyMinutes = 25, _breakMinutes = 5, _remainingSeconds = 1500;
  int _completedToday = 0;
  bool _isBreak = false, _isRunning = false;
  int? _deadlineMs;
  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }
  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final today = _todayKey();
    final sameDay = (prefs.getString('${_prefix}date') ?? today) == today;
    setState(() {
      _studyMinutes = prefs.getInt('${_prefix}study') ?? 25;
      _breakMinutes = prefs.getInt('${_prefix}break') ?? 5;
      _isBreak = prefs.getBool('${_prefix}breakMode') ?? false;
      _isRunning = prefs.getBool('${_prefix}running') ?? false;
      _deadlineMs = prefs.getInt('${_prefix}deadline');
      _remainingSeconds = prefs.getInt('${_prefix}remaining') ?? _studyMinutes * 60;
      _completedToday = sameDay ? (prefs.getInt('${_prefix}count') ?? 0) : 0;
    });
    if (_isRunning && _deadlineMs != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      _tick();
    } else {
      _remainingSeconds = _remainingSeconds.clamp(0, 7200).toInt();
    }
  }
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_prefix}study', _studyMinutes);
    await prefs.setInt('${_prefix}break', _breakMinutes);
    await prefs.setBool('${_prefix}breakMode', _isBreak);
    await prefs.setBool('${_prefix}running', _isRunning);
    await prefs.setInt('${_prefix}remaining', _remainingSeconds);
    await prefs.setString('${_prefix}date', _todayKey());
    await prefs.setInt('${_prefix}count', _completedToday);
    if (_deadlineMs == null) {
      await prefs.remove('${_prefix}deadline');
    } else {
      await prefs.setInt('${_prefix}deadline', _deadlineMs!);
    }
  }
  void _tick() {
    if (!_isRunning || _deadlineMs == null || !mounted) return;
    final left = ((_deadlineMs! - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    if (left > 0) {
      if (_remainingSeconds != left) setState(() => _remainingSeconds = left);
      return;
    }
    _ticker?.cancel();
    if (_isBreak) {
      setState(() {
        _isBreak = false; _isRunning = false; _deadlineMs = null;
        _remainingSeconds = _studyMinutes * 60;
      });
    } else {
      setState(() {
        _completedToday++; _isBreak = true; _isRunning = true;
        _remainingSeconds = _breakMinutes * 60;
        _deadlineMs = DateTime.now().add(Duration(minutes: _breakMinutes)).millisecondsSinceEpoch;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
    _persist();
  }
  Future<void> _startPause() async {
    if (_isRunning) {
      final left = _deadlineMs == null ? _remainingSeconds :
        ((_deadlineMs! - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
      _ticker?.cancel();
      setState(() {
        _remainingSeconds = left.clamp(0, 7200).toInt();
        _isRunning = false; _deadlineMs = null;
      });
    } else {
      setState(() {
        _isRunning = true;
        _deadlineMs = DateTime.now().add(Duration(seconds: _remainingSeconds)).millisecondsSinceEpoch;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
    await _persist();
  }
  Future<void> _reset() async {
    _ticker?.cancel();
    setState(() {
      _isRunning = false; _deadlineMs = null;
      _remainingSeconds = (_isBreak ? _breakMinutes : _studyMinutes) * 60;
    });
    await _persist();
  }
  Future<void> _switchMode() async {
    _ticker?.cancel();
    setState(() {
      _isBreak = !_isBreak; _isRunning = false; _deadlineMs = null;
      _remainingSeconds = (_isBreak ? _breakMinutes : _studyMinutes) * 60;
    });
    await _persist();
  }
  Future<void> _selectPreset(int study, int rest) async {
    _ticker?.cancel();
    setState(() {
      _studyMinutes = study; _breakMinutes = rest; _isBreak = false;
      _isRunning = false; _deadlineMs = null; _remainingSeconds = study * 60;
    });
    await _persist();
  }
  Future<void> _customDurations() async {
    final study = TextEditingController(text: '30');
    final rest = TextEditingController(text: '7');
    final values = await showDialog<List<int>>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تخصيص وقت الجلسة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: study, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الدراسة بالدقائق (5–120)')),
          const SizedBox(height: 8),
          TextField(controller: rest, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الاستراحة بالدقائق (1–30)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(onPressed: () {
            final a = int.tryParse(study.text), b = int.tryParse(rest.text);
            if (a == null || b == null || a < 5 || a > 120 || b < 1 || b > 30) return;
            Navigator.pop(dialogContext, [a, b]);
          }, child: const Text('حفظ')),
        ],
      ));
    study.dispose(); rest.dispose();
    if (values != null) await _selectPreset(values[0], values[1]);
  }
  String get _timeText {
    final minutes = _remainingSeconds ~/ 60, seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = (_isBreak ? _breakMinutes : _studyMinutes) * 60;
    final progress = total == 0 ? 0.0 : (1 - (_remainingSeconds / total)).clamp(0.0, 1.0).toDouble();
    return Directionality(textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مؤقت الدراسة والاستراحة')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '25', label: Text('25 / 5 دقيقة')),
              ButtonSegment(value: '45', label: Text('45 / 10 دقيقة')),
              ButtonSegment(value: 'custom', label: Text('تخصيص')),
            ],
            selected: {_studyMinutes == 25 && _breakMinutes == 5 ? '25' :
              _studyMinutes == 45 && _breakMinutes == 10 ? '45' : 'custom'},
            onSelectionChanged: (selection) {
              final value = selection.first;
              if (value == '25') _selectPreset(25, 5);
              if (value == '45') _selectPreset(45, 10);
              if (value == 'custom') _customDurations();
            },
          ),
          const SizedBox(height: 22),
          Card(child: Padding(padding: const EdgeInsets.all(22),
            child: Column(children: [
              Text(_isBreak ? 'وقت الاستراحة' : 'وقت الدراسة',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                  color: colors.onSurfaceVariant)),
              const SizedBox(height: 20),
              SizedBox(width: 220, height: 220,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(child: CircularProgressIndicator(
                    value: progress, strokeWidth: 12,
                    backgroundColor: colors.surfaceContainerHighest,
                    strokeCap: StrokeCap.round,
                    color: _isBreak ? const Color(0xFF16866A) : colors.primary)),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_timeText, style: const TextStyle(fontSize: 43, fontWeight: FontWeight.w900)),
                    Text(_isRunning ? 'الجلسة تعمل' : 'متوقف مؤقتاً',
                      style: TextStyle(color: colors.onSurfaceVariant)),
                  ]),
                ]),
              ),
              const SizedBox(height: 22),
              Wrap(alignment: WrapAlignment.center, spacing: 9, runSpacing: 9,
                children: [
                  FilledButton.icon(onPressed: _startPause,
                    icon: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    label: Text(_isRunning ? 'إيقاف مؤقت' : 'ابدأ')),
                  OutlinedButton.icon(onPressed: _reset,
                    icon: const Icon(Icons.restart_alt_rounded), label: const Text('إعادة ضبط')),
                  OutlinedButton.icon(onPressed: _switchMode,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: Text(_isBreak ? 'العودة للدراسة' : 'ابدأ استراحة')),
                ]),
            ]),
          )),
          const SizedBox(height: 14),
          Card(child: ListTile(
            leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF16866A)),
            title: const Text('الجلسات المكتملة اليوم', style: TextStyle(fontWeight: FontWeight.w800)),
            trailing: Text('$_completedToday', style: TextStyle(fontSize: 24,
              fontWeight: FontWeight.w900, color: colors.primary)),
          )),
          const SizedBox(height: 8),
          Text('عند انتهاء جلسة الدراسة ينتقل المؤقت تلقائياً إلى الاستراحة. عند انتهاء الاستراحة يتوقف بانتظار بدء جلسة جديدة. تُحفظ حالة المؤقت وعدد الجلسات على هذا الجهاز.',
            style: TextStyle(fontSize: 12, height: 1.65, color: colors.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

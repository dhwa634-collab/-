// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});
  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}
class _PomodoroScreenState extends State<PomodoroScreen> with WidgetsBindingObserver {
  static const _prefix = 'study_pomodoro_v1_';
  Timer? _ticker;
  Timer? _quoteTicker;
  bool _autoQuotes = true;
  int _studyMinutes = 25, _breakMinutes = 5, _remainingSeconds = 1500;
  int _completedToday = 0;
  int _completedStudyMinutesToday = 0;
  bool _isBreak = false, _isRunning = false;
  int? _deadlineMs;
  int _quoteIndex = 0;
  bool _showCompletion = false;

  static const List<String> _motivationalQuotes = [
    'كل صفحة تقرؤها اليوم تقرّبك من حلمك.',
    'لا تنتظر الحماس؛ ابدأ وسيأتي الحماس بالطريق.',
    'خطوة صغيرة كل يوم تصنع نجاحاً كبيراً.',
    'أنت أقوى من التسويف، ابدأ الآن.',
    'افهم الفكرة، ثم ستصبح المسائل أسهل.',
    'تعب اليوم هو فخر الغد.',
    'لا تقارن بدايتك بإنجاز غيرك؛ نافس نفسك.',
    'استمر، فكل محاولة تزيد خبرتك.',
    'رتّب وقتك، وامنح كل مادة حقها.',
    'النجاح ليس صدفة؛ إنه عادة يومية.',
    'إذا أخطأت في سؤال فقد تعلمت طريقاً جديداً.',
    'خذ نفساً عميقاً، ثم أكمل بثقة.',
    'ساعة تركيز أفضل من ساعات من التشتت.',
    'أحلامك تستحق أن تمنحها وقتاً وجهداً.',
    'لا تؤجل إنجاز اليوم إلى الغد.',
    'أنت تتقدم حتى لو كان تقدمك بطيئاً.',
    'اجعل هدفك الفهم لا مجرد حفظ الإجابة.',
    'كل مراجعة تثبّت معلومة في ذاكرتك.',
    'ابدأ بالأصعب، وستشعر بالإنجاز بعدها.',
    'الاستراحة الذكية جزء من الدراسة الناجحة.',
    'ثق بنفسك، فأنت قادر على تجاوز الصعب.',
    'لا تخف من كثرة المنهج؛ قسّمه إلى خطوات.',
    'التركيز مهارة تقوى بالتدريب.',
    'اليوم فرصة جديدة لتكون أفضل من الأمس.',
    'واصل، فالثبات يصنع الفرق.',
    'ضع هاتفك جانباً، فمستقبلك يستحق تركيزك.',
    'كل سؤال تحله يزيد ثقتك بنفسك.',
    'لا تبحث عن الكمال؛ ابحث عن التقدم.',
    'أنت لا تدرس للامتحان فقط، بل تبني مستقبلك.',
    'ابدأ بعشر دقائق، وقد تنجز أكثر مما تتوقع.',
    'المعلومة التي تراجعها اليوم سترافقك غداً.',
    'حين تتعب، تذكر لماذا بدأت.',
    'الإنجاز الكبير يبدأ بقرار صغير.',
    'استعن بالله، وخذ بالأسباب، ولا تستسلم.',
    'اجعل لكل جلسة هدفاً واضحاً.',
    'الهدوء والتركيز أقوى من العجلة.',
    'أنت أقرب إلى هدفك مما كنت عليه بالأمس.',
    'لا تجعل سؤالاً صعباً يوقف رحلتك.',
    'استرح قليلاً ثم عُد أقوى.',
    'كل دقيقة تركيز استثمار في مستقبلك.',
    'نظّم أفكارك، وسترى الطريق أوضح.',
    'تعلّم من الخطأ ولا تكرره.',
    'النجاح يحتاج صبراً أكثر مما يحتاج سرعة.',
    'اليوم تزرع، وغداً تحصد بإذن الله.',
    'أكمل هذه الجلسة بفخر؛ أنت تستحق النجاح.',
    "لا تحتاج أن تنهي المنهج كله الآن؛ أنجز الصفحة التي أمامك.",
    "افهم القانون أولاً، ثم درّب نفسك على تطبيقه.",
    "كل مسألة تحلها اليوم تختصر عليك وقت الامتحان.",
    "إذا تعثرت في الرياضيات، ارجع إلى الأساسيات بهدوء.",
    "اقرأ السؤال مرتين وحدد المطلوب قبل أن تبدأ الحل.",
    "في الكيمياء، اربط اسم العنصر برمزه وتدرّب على كتابته.",
    "في الفيزياء، اكتب المعطيات ثم القانون ثم التعويض.",
    "القواعد تصبح أسهل عندما تراها في أمثلة كثيرة.",
    "اقرأ النص العربي بتركيز، فالفهم نصف الإجابة.",
    "لا تحفظ الإنكليزي بلا مراجعة؛ كرر الكلمات في جمل.",
    "التاريخ والجغرافية يحتاجان فهماً وربطاً لا تكديساً للمعلومات.",
    "راجع الوزاريات لتتعرف إلى طريقة السؤال وتوزيع الأفكار.",
    "حلّ نموذجاً امتحانياً وكأنك داخل قاعة الامتحان.",
    "لا تترك السؤال الصعب يسرق وقت بقية الأسئلة.",
    "خصص آخر عشر دقائق لمراجعة إجاباتك.",
    "اكتب أخطاءك في دفتر صغير وارجع إليها كل أسبوع.",
    "قسّم الفصل إلى عناوين صغيرة، وستراه أقل صعوبة.",
    "ابدأ بمادة تحتاج تركيزك عندما يكون ذهنك صافياً.",
    "بدّل بين المواد حتى تحافظ على نشاطك.",
    "اجعل هدف جلسة اليوم واضحاً وقابلاً للإنجاز.",
    "خمس صفحات بفهم أفضل من عشرين صفحة بلا تركيز.",
    "الاستمرار الهادئ أقوى من اندفاع يوم واحد.",
    "لا تجعل درجة اختبار واحد تحكم على قدراتك.",
    "كل طالب ناجح مرّ بأيام شعر فيها بالتعب ثم أكمل.",
    "خذ وقتك في الفهم؛ السرعة تأتي مع التدريب.",
    "حين تنسى معلومة، لا تقل فشلت؛ قل أحتاج مراجعة.",
    "رتب مكانك قبل الدراسة لتوفر وقت البحث عن أغراضك.",
    "أبعد الإشعارات، وامنح نفسك وقتاً تستحقه.",
    "ضع علامة على الفقرات التي تحتاج أن تعود إليها.",
    "راجع ملخصك بعد الدرس في اليوم نفسه.",
    "النوم الكافي يساعدك على تثبيت ما تعلمته.",
    "اشرب الماء واعتنِ براحتك؛ صحتك جزء من نجاحك.",
    "لا تقارن عدد ساعاتك بغيرك، قارن جودة تركيزك.",
    "الوزاريات تدريب ذكي وليست بديلاً عن فهم الكتاب.",
    "تعلم كيف تصل إلى الإجابة، لا تحفظ شكلها فقط.",
    "كل مرة تشرح فيها الدرس لنفسك يزداد فهمك.",
    "إذا طال الحل، خذ نفساً وارجع إلى خطوات المسألة.",
    "اجعل المراجعة اليومية عادة صغيرة لا عبئاً كبيراً.",
    "ابدأ بما تستطيع، فالبداية تفتح الطريق.",
    "أنت تستحق أن ترى نتيجة تعبك؛ لا تتوقف الآن.",
    "استراحة قصيرة: أرح عينيك وابتعد عن الشاشة قليلاً.",
    "قم وتمدد واشرب ماءً، ثم عد بذهن متجدد.",
    "خذ نفساً عميقاً؛ ليس مطلوباً منك أن تنجز كل شيء دفعة واحدة.",
    "استمتع بدقائق الراحة بلا شعور بالذنب، ثم أكمل.",
    "ابتسم، لقد أنجزت خطوة إضافية اليوم.",
    "دع عينيك ترتاحان وانظر إلى مكان بعيد للحظات.",
    "استمع إلى شيء هادئ أو اجلس في صمت قصير.",
    "لا تنسَ أن تفتخر بنفسك على المحاولة قبل النتيجة.",
    "كل استراحة منظمة تعيد إليك تركيزك.",
    "أغلق الكتاب لدقائق، لكن لا تغلق باب حلمك.",
    "تعبك اليوم ليس ضائعاً؛ إنه تدريب لعقلك وثقتك.",
    "راجع التعاريف بصوت مسموع لتختبر فهمك.",
    "ارسم مخططاً صغيراً عندما تتشابك الأفكار.",
    "حل سؤالاً من كل موضوع لتعرف أين تحتاج تقوية.",
    "الخطأ في التدريب فرصة ثمينة قبل الامتحان.",
    "لا تؤجل مراجعة ما تعلمته؛ التكرار يصنع الثبات.",
    "ضع جدولاً واقعياً واترك فيه مساحة للراحة.",
    "أنت قادر على تجاوز المادة التي تخاف منها بالتدرج.",
    "خذ سؤالاً واحداً الآن، واجعله بداية إنجاز جديد.",
    "ثقتك تكبر كلما التزمت بوعد صغير قطعته لنفسك.",
    "امتحانك محطة في الطريق، وليس تعريفاً لقيمتك.",
    "استعن بالله، ثم خطط واعمل واطمئن.",
  ];

  void _nextQuote() {
    if (!mounted || _motivationalQuotes.isEmpty) return;
    setState(() {
      _quoteIndex = (_quoteIndex + 1) % _motivationalQuotes.length;
    });
  }

  void _startQuoteRotation() {
    _quoteTicker?.cancel();
    if (!_autoQuotes) return;
    _quoteTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _autoQuotes) _nextQuote();
    });
  }
  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
    _startQuoteRotation();
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _quoteTicker?.cancel();
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
      _completedStudyMinutesToday = sameDay ? (prefs.getInt('${_prefix}studyMinutesToday') ?? 0) : 0;
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
    await prefs.setInt('${_prefix}studyMinutesToday', _completedStudyMinutesToday);
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
      if (_remainingSeconds != left) {
        setState(() {
          _remainingSeconds = left;
          // بدّل العبارة بهدوء كل ثلاث دقائق أثناء استمرار الجلسة.
          if (left % 180 == 0) {
            _quoteIndex = (_quoteIndex + 1) % _motivationalQuotes.length;
          }
        });
      }
      return;
    }
    _ticker?.cancel();
    if (_isBreak) {
      setState(() {
        _isBreak = false; _isRunning = false; _deadlineMs = null;
        _remainingSeconds = _studyMinutes * 60;
        _showCompletion = false;
        _quoteIndex = (_quoteIndex + 1) % _motivationalQuotes.length;
      });
    } else {
      setState(() {
        _completedToday++;
        _completedStudyMinutesToday += _studyMinutes;
        _isBreak = true; _isRunning = true;
        _showCompletion = true;
        _quoteIndex = (_quoteIndex + 1) % _motivationalQuotes.length;
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
      _showCompletion = false;
      _remainingSeconds = (_isBreak ? _breakMinutes : _studyMinutes) * 60;
      _quoteIndex = (_quoteIndex + 1) % _motivationalQuotes.length;
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
    const dailySessionGoal = 4;
    final dailyGoalProgress =
        (_completedToday / dailySessionGoal).clamp(0.0, 1.0).toDouble();
    return Directionality(textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مؤقت الدراسة والاستراحة')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '25', label: Text('25 / 5 دقيقة')),
              ButtonSegment(value: '45', label: Text('45 / 10 دقيقة')),
              ButtonSegment(value: '60', label: Text('جلسة مركزة 60 / 15')),
              ButtonSegment(value: 'custom', label: Text('تخصيص')),
            ],
            selected: {_studyMinutes == 25 && _breakMinutes == 5 ? '25' :
              _studyMinutes == 45 && _breakMinutes == 10 ? '45' :
              _studyMinutes == 60 && _breakMinutes == 15 ? '60' : 'custom'},
            onSelectionChanged: (selection) {
              final value = selection.first;
              if (value == '25') _selectPreset(25, 5);
              if (value == '45') _selectPreset(45, 10);
              if (value == '60') _selectPreset(60, 15);
              if (value == 'custom') _customDurations();
            },
          ),
          const SizedBox(height: 22),
          Card(child: Padding(padding: const EdgeInsets.all(22),
            child: Column(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child)),
                child: Row(
                  key: ValueKey(_isBreak),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isBreak ? Icons.coffee_rounded : Icons.menu_book_rounded,
                      color: _isBreak ? const Color(0xFF16866A) : colors.primary,
                      size: 24),
                    const SizedBox(width: 9),
                    Text(_isBreak ? 'وقت الاستراحة' : 'وقت الدراسة',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                        color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _showCompletion
                ? Card(
                    key: const ValueKey('pomodoro-completed'),
                    child: const ListTile(
                      leading: Icon(Icons.emoji_events_rounded,
                        color: Color(0xFFD49A2A), size: 29),
                      title: Text('أحسنت! أكملت جلسة دراسة',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text('استمتع باستراحتك، فأنت تستحقها.'),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('pomodoro-no-completion')),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.auto_awesome_rounded, color: colors.primary),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('جرعة تحفيز',
                      style: TextStyle(fontWeight: FontWeight.w900))),
                    IconButton(
                      tooltip: _autoQuotes ? 'إيقاف التقلب التلقائي' : 'استئناف التقلب التلقائي',
                      onPressed: () {
                        setState(() => _autoQuotes = !_autoQuotes);
                        _startQuoteRotation();
                      },
                      icon: Icon(_autoQuotes ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded),
                    ),
                  ]),
                  const SizedBox(height: 7),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, .10), end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      _motivationalQuotes[_quoteIndex],
                      key: ValueKey(_quoteIndex),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(child: Column(children: [
            ListTile(
              leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF16866A)),
              title: const Text('الجلسات المكتملة اليوم', style: TextStyle(fontWeight: FontWeight.w800)),
              trailing: Text('$_completedToday', style: TextStyle(fontSize: 24,
                fontWeight: FontWeight.w900, color: colors.primary)),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: Icon(Icons.timelapse_rounded, color: colors.primary),
              title: const Text('دقائق الدراسة المنجزة اليوم', style: TextStyle(fontWeight: FontWeight.w800)),
              trailing: Text('$_completedStudyMinutesToday د', style: TextStyle(fontSize: 22,
                fontWeight: FontWeight.w900, color: colors.primary)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('هدفك اليومي • 4 جلسات',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface,
                          )),
                      ),
                      Text('$_completedToday / $dailySessionGoal',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: colors.primary,
                        )),
                    ],
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: dailyGoalProgress),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 9,
                        backgroundColor: colors.surfaceContainerHighest,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _completedToday >= dailySessionGoal
                        ? 'أحسنت! حققت هدف المراجعة اليومي.'
                        : 'باقي لك ${dailySessionGoal - _completedToday} جلسة حتى تحقق هدفك.',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ])),
          const SizedBox(height: 8),
          Text('عند انتهاء جلسة الدراسة ينتقل المؤقت تلقائياً إلى الاستراحة. عند انتهاء الاستراحة يتوقف بانتظار بدء جلسة جديدة. تُحفظ حالة المؤقت وعدد الجلسات على هذا الجهاز.',
            style: TextStyle(fontSize: 12, height: 1.65, color: colors.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// عدّل هذه التواريخ فقط عند صدور الجداول الرسمية.
class ExamDates {
  // 5 شباط 2027 يبعد 76 يوماً عن 21 تشرين الثاني 2026.
  // غيّر التاريخ هنا وحده عند اعتماد الموعد الرسمي.
  static final DateTime preparatory = DateTime(2027, 2, 5);
  // اتركه null إلى أن يُعلن الموعد الوزاري المعتمد.
  static final DateTime? ministerial = null;
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
          date: ExamDates.preparatory,
          icon: Icons.edit_calendar_rounded, tint: const Color(0xFF16866A))),
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
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final targetDay = DateTime(date!.year, date!.month, date!.day);
      final days = targetDay.difference(today).inDays;
      if (days < 0) {
        value = 'انتهى الموعد';
        detail = 'راجع الجدول الرسمي';
      } else if (days == 0) {
        value = 'اليوم';
        detail = 'موعد الامتحان';
      } else {
        value = '$days يوم';
        detail = 'متبقية';
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

/// ملف كتاب واحد؛ يدعم رابط تنزيل أو ملفاً مضمّناً داخل التطبيق.
class BookPdfPart {
  final String title;
  final String? pdfUrl;
  final String? assetPath;
  const BookPdfPart({
    required this.title,
    this.pdfUrl,
    this.assetPath,
  });

  bool get isAvailable {
    final uri = Uri.tryParse(pdfUrl ?? '');
    return (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) ||
        (assetPath != null && assetPath!.trim().isNotEmpty);
  }
}

/// مصدر موحّد للمواد والوزاريات وكتب PDF. أضف روابط الكتب هنا فقط.
class Subject {
  final String name;
  final IconData icon;
  final Color color;
  final String? pdfUrl;
  final String? assetPath;
  final List<BookPdfPart> parts;

  const Subject(
    this.name,
    this.icon,
    this.color, {
    this.pdfUrl,
    this.assetPath,
    this.parts = const [],
  });

  String get bookTitle => 'كتاب $name';
  List<BookPdfPart> get availableParts {
    if (parts.isNotEmpty) return parts;
    if (pdfUrl != null || assetPath != null) {
      return [BookPdfPart(
        title: bookTitle,
        pdfUrl: pdfUrl,
        assetPath: assetPath,
      )];
    }
    return const [];
  }
  bool get hasPdf => availableParts.any((part) => part.isAvailable);
}

const List<Subject> subjects = [
  // قائمة المواد الوزارية تبقى ست مواد فقط.
  Subject('اللغة العربية', Icons.menu_book_rounded, Color(0xFFB76E24)),
  Subject('اللغة الإنكليزية', Icons.translate_rounded, Color(0xFF5267C9)),
  Subject('الاجتماعيات', Icons.public_rounded, Color(0xFFB65C69),
    pdfUrl: 'https://bk2.shr4.com/books/bb3/2025-2026/كتاب%20الاجتماعيات%20الثالث%20متوسط.pdf'),
  Subject('الفيزياء', Icons.bolt_rounded, Color(0xFFD18A25),
    pdfUrl: 'https://bk2.shr4.com/books/bb3/2025-2026/كتاب%20الفيزياء%20الثالث%20متوسط.pdf'),
  Subject('الأحياء', Icons.biotech_rounded, Color(0xFF269B75),
    pdfUrl: 'https://derasaty.net/download.php?file=1761133290.pdf&type=application%2Fpdf'),
  Subject('الرياضيات', Icons.functions_rounded, Color(0xFF7A52C7),
    pdfUrl: 'https://bk2.shr4.com/books/bb3/2025-2026/كتاب%20الرياضيات%20الثالث%20متوسط.pdf'),
];

/// فهرس الكتب مستقل عن مواد الأسئلة الوزارية.
/// الكيمياء والإسلامية يظهران هنا ككتب دراسية فقط، ولا يدخلان قائمة الوزاريات.
const List<Subject> bookSubjects = [
  Subject('اللغة العربية', Icons.menu_book_rounded, Color(0xFFB76E24),
    parts: [
      BookPdfPart(
        title: 'الجزء الأول',
        pdfUrl: 'https://bk2.shr4.com/books/bb3/2025-2026/كتاب%20العربي%20الثالث%20متوسط%20الجزء%20الاول.pdf',
      ),
      BookPdfPart(
        title: 'الجزء الثاني',
        pdfUrl: 'https://bk2.shr4.com/books/bb3/2025-2026/كتاب%20العربي%20الثالث%20متوسط%20الجزء%20الثاني.pdf',
      ),
    ]),
  Subject('اللغة الإنكليزية', Icons.translate_rounded, Color(0xFF5267C9)),
  Subject('الاجتماعيات', Icons.public_rounded, Color(0xFFB65C69),
    pdfUrl: 'https://bk2.shr4.com/books/bb3/2025-2026/كتاب%20الاجتماعيات%20الثالث%20متوسط.pdf'),
  Subject('الفيزياء', Icons.bolt_rounded, Color(0xFFD18A25),
    pdfUrl: 'https://bk2.shr4.com/books/bb3/2025-2026/كتاب%20الفيزياء%20الثالث%20متوسط.pdf'),
  Subject('الأحياء', Icons.biotech_rounded, Color(0xFF269B75),
    pdfUrl: 'https://derasaty.net/download.php?file=1761133290.pdf&type=application%2Fpdf'),
  Subject('الرياضيات', Icons.functions_rounded, Color(0xFF7A52C7),
    pdfUrl: 'https://bk2.shr4.com/books/bb3/2025-2026/كتاب%20الرياضيات%20الثالث%20متوسط.pdf'),
  Subject('الكيمياء', Icons.science_rounded, Color(0xFF2787B8),
    pdfUrl: 'https://www.stadiraq.com/PDF/1761834142.pdf'),
  Subject('التربية الإسلامية', Icons.mosque_rounded, Color(0xFF16866A),
    pdfUrl: 'https://derasaty.net/download.php?file=1737565764.pdf&type=application%2Fpdf'),
];

class BooksLibraryScreen extends StatefulWidget {
  final Subject? subject;
  final int cardStyle;
  final Color accentColor;
  final double cardRadius;

  const BooksLibraryScreen({
    super.key,
    this.subject,
    this.cardStyle = 0,
    this.accentColor = const Color(0xFF2868D7),
    this.cardRadius = 18,
  });

  @override
  State<BooksLibraryScreen> createState() => _BooksLibraryScreenState();
}

class _BooksLibraryScreenState extends State<BooksLibraryScreen> {
  final Map<String, double> _progress = {};
  final Set<String> _downloading = {};
  final Set<String> _downloaded = {};
  final http.Client _client = http.Client();

  String _fileKey(Subject book, BookPdfPart part) =>
      Uri.encodeComponent('${book.name}_${part.title}');

  Future<File> _localFile(Subject book, BookPdfPart part) async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/books/${_fileKey(book, part)}.pdf');
  }

  @override
  void initState() {
    super.initState();
    _refreshDownloaded();
  }

  Future<void> _refreshDownloaded() async {
    for (final book in bookSubjects) {
      for (final part in book.availableParts) {
        if (!part.isAvailable) continue;
        try {
          final file = await _localFile(book, part);
          if (await file.exists() && await file.length() > 0 && mounted) {
            setState(() => _downloaded.add(_fileKey(book, part)));
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _chooseBook(Subject book) async {
    final parts = book.availableParts.where((part) => part.isAvailable).toList();
    if (parts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('كتاب ${book.name} قيد التجهيز. سنضيفه بعد توفير ملف PDF موثوق.'),
      ));
      return;
    }
    BookPdfPart? selected = parts.first;
    if (parts.length > 1) {
      selected = await showModalBottomSheet<BookPdfPart>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(book.bookTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              ...parts.map((part) => ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded),
                title: Text(part.title),
                subtitle: const Text('تنزيل وقراءة داخل التطبيق'),
                onTap: () => Navigator.pop(context, part),
              )),
            ],
          ),
        ),
      );
    }
    if (selected != null && mounted) await _downloadAndOpen(book, selected);
  }

  Future<bool> _isValidPdf(File file) async {
    try {
      if (!await file.exists() || await file.length() < 5) return false;
      final header = await file.openRead(0, 5).fold<List<int>>(
        <int>[], (all, chunk) => all..addAll(chunk));
      return header.length >= 4 &&
          String.fromCharCodes(header.take(4)) == '%PDF';
    } catch (_) {
      return false;
    }
  }

  Future<void> _downloadAndOpen(Subject book, BookPdfPart part) async {
    final key = _fileKey(book, part);
    if (_downloading.contains(key)) return;
    setState(() {
      _downloading.add(key);
      _progress[key] = 0;
    });
    try {
      final file = await _localFile(book, part);
      if (await file.exists()) {
        if (await _isValidPdf(file)) {
          if (!mounted) return;
          await _openViewer(book, part, file);
          return;
        }
        // احذف النسخة التالفة فقط ثم نزّل نسخة سليمة من المصدر.
        await file.delete();
      }

      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.part');
      if (await temporary.exists()) await temporary.delete();

      if (part.assetPath != null && part.assetPath!.isNotEmpty) {
        final data = await rootBundle.load(part.assetPath!);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes, data.lengthInBytes);
        await temporary.writeAsBytes(bytes, flush: true);
        if (mounted) setState(() => _progress[key] = 1);
      } else {
        final uri = Uri.tryParse(part.pdfUrl ?? '');
        if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
          throw Exception('رابط ملف PDF غير صالح');
        }
        final request = http.Request('GET', uri);
        final response = await _client.send(request).timeout(
          const Duration(seconds: 45));
        if (response.statusCode != 200) {
          throw Exception('تعذر تنزيل الملف (رمز ${response.statusCode})');
        }
        final total = response.contentLength ?? 0;
        var received = 0;
        final sink = temporary.openWrite();
        try {
          await for (final chunk in response.stream.timeout(
            const Duration(seconds: 35))) {
            sink.add(chunk);
            received += chunk.length;
            if (mounted && total > 0) {
              setState(() => _progress[key] = (received / total).clamp(0, 1));
            }
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
      }

      final bytes = await temporary.openRead(0, 5).fold<List<int>>(
        <int>[], (all, chunk) => all..addAll(chunk));
      if (bytes.length < 4 ||
          String.fromCharCodes(bytes.take(4)) != '%PDF') {
        await temporary.delete();
        throw Exception('الملف المستلم ليس ملف PDF صالحاً');
      }
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
      if (!mounted) return;
      setState(() => _downloaded.add(key));
      await _openViewer(book, part, file);
    } catch (error) {
      final temporary = await _localFile(book, part);
      final partial = File('${temporary.path}.part');
      if (await partial.exists()) await partial.delete();
      if (mounted) {
        final message = error is TimeoutException
            ? 'الاتصال بطيء أو انقطع. تأكد من الإنترنت وحاول مرة ثانية.'
            : error is SocketException || error is http.ClientException
                ? 'ما قدرنا نتصل بمصدر الكتاب. افحص اتصال الإنترنت وحاول مجدداً.'
                : 'ملف الكتاب غير مكتمل أو غير صالح حالياً. حاول مرة ثانية لاحقاً.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            onPressed: () => _downloadAndOpen(book, part),
          ),
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading.remove(key);
          _progress.remove(key);
        });
      }
    }
  }

  Future<void> _openViewer(
    Subject book, BookPdfPart part, File file) async {
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => PdfBookReaderScreen(
        title: part.title,
        file: file,
      ),
    ));
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visibleBooks = widget.subject == null ? bookSubjects : <Subject>[widget.subject!];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.subject == null
          ? 'الكتب الثالث متوسط' : 'كتاب ${widget.subject!.name}')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.menu_book_rounded,
                    color: colors.onPrimaryContainer, size: 27),
                  const SizedBox(width: 11),
                  Expanded(child: Text(
                    'نزّل الكتاب مرة واحدة، وبعدها تقدر تفتحه وتقرأه داخل التطبيق حتى بدون إنترنت.',
                    style: TextStyle(height: 1.6,
                      color: colors.onPrimaryContainer),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleBooks.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 11,
                mainAxisSpacing: 11,
                childAspectRatio: .88,
              ),
              itemBuilder: (context, index) {
                final book = visibleBooks[index];
                final parts = book.availableParts.where((part) => part.isAvailable);
                final available = parts.isNotEmpty;
                final part = available ? parts.first : null;
                final key = part == null ? '' : _fileKey(book, part);
                final downloading = key.isNotEmpty && _downloading.contains(key);
                final downloaded = key.isNotEmpty && _downloaded.contains(key);
                final progress = key.isNotEmpty ? (_progress[key] ?? 0) : 0.0;
                final status = downloading
                    ? 'جاري التنزيل'
                    : downloaded ? 'تم التنزيل • جاهز للفتح'
                    : available ? 'اضغط للتنزيل' : 'قيد التجهيز';

                return Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  color: widget.cardStyle == 1
                      ? Color.alphaBlend(book.color.withValues(alpha: .10), colors.surface)
                      : widget.cardStyle == 2
                          ? Color.alphaBlend(widget.accentColor.withValues(alpha: .13), colors.surface)
                          : colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(widget.cardRadius),
                    side: BorderSide(
                      color: book.color.withValues(alpha: .35)),
                  ),
                  child: InkWell(
                    onTap: downloading ? null : () => _chooseBook(book),
                    borderRadius: BorderRadius.circular(widget.cardRadius),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 49,
                              height: 49,
                              decoration: BoxDecoration(
                                color: book.color.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(book.icon,
                                color: book.color, size: 28),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            book.bookTitle,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            softWrap: true,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              height: 1.3,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('للثالث المتوسط',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10,
                              color: colors.onSurfaceVariant)),
                          const Spacer(),
                          if (downloading) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress > 0 ? progress : null,
                                minHeight: 5,
                                backgroundColor: colors.surfaceContainerHighest,
                                color: book.color,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 7),
                            decoration: BoxDecoration(
                              color: downloaded
                                  ? colors.primaryContainer
                                  : colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: downloaded
                                    ? colors.onPrimaryContainer
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            available
                                ? (downloaded ? 'اضغط للقراءة داخل التطبيق' : 'اضغط للتنزيل')
                                : 'سيُضاف قريباً',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 9.5,
                              color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'تنويه: لا تمثل هذه المكتبة جهة حكومية أو وزارة، ولا ننسب أي ملف إلى جهة رسمية إلا بعد التحقق من مصدره ومحتواه.',
              style: TextStyle(fontSize: 12, height: 1.65,
                color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class PdfBookReaderScreen extends StatelessWidget {
  final String title;
  final File file;
  const PdfBookReaderScreen({
    super.key,
    required this.title,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: PdfViewer.file(file.path),
      ),
    );
  }
}

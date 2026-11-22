// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

class ReviewQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  const ReviewQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class ReviewSubject {
  final String name;
  final IconData icon;
  final Color color;
  final Map<String, List<ReviewQuestion>> chapters;
  const ReviewSubject(this.name, this.icon, this.color, this.chapters);
}

const List<ReviewSubject> reviewSubjects = [
  ReviewSubject('اللغة العربية', Icons.menu_book_rounded, Color(0xFFB76E24), {
    'النحو: الجملة الفعلية': [
      ReviewQuestion(question: 'ما إعراب كلمة «الطالبُ» في جملة: كتبَ الطالبُ الدرسَ؟', options: ['مفعول به منصوب', 'فاعل مرفوع', 'مبتدأ مرفوع', 'خبر منصوب'], correctIndex: 1, explanation: 'الطالبُ هو من قام بالفعل «كتب»، لذلك يُعرب فاعلاً مرفوعاً بالضمة.'),
      ReviewQuestion(question: 'ما علامة نصب المفعول به المفرد؟', options: ['الضمة', 'الكسرة دائماً', 'الفتحة', 'السكون'], correctIndex: 2, explanation: 'الأصل في نصب المفعول به المفرد أن تكون علامة نصبه الفتحة الظاهرة.'),
      ReviewQuestion(question: 'في جملة «قرأَ التلميذُ القصةَ»، ما المفعول به؟', options: ['قرأَ', 'التلميذُ', 'القصةَ', 'لا يوجد'], correctIndex: 2, explanation: 'القصةَ هي التي وقع عليها فعل القراءة، فهي المفعول به.'),
    ],
    'الأدب والنصوص': [
      ReviewQuestion(question: 'أيّ مما يأتي يُعدّ من عناصر التشبيه؟', options: ['أداة التشبيه', 'الفاصلة فقط', 'حرف الجر فقط', 'علامة الاستفهام'], correctIndex: 0, explanation: 'من أركان التشبيه: المشبّه، والمشبّه به، وأداة التشبيه، ووجه الشبه.'),
      ReviewQuestion(question: 'ما الغرض الأساسي من الفكرة الرئيسة للنص؟', options: ['ذكر كل كلمة', 'تلخيص المعنى العام', 'تغيير موضوع النص', 'حذف الأدلة'], correctIndex: 1, explanation: 'الفكرة الرئيسة تعبّر باختصار عن المعنى أو الموضوع الذي يدور حوله النص.'),
      ReviewQuestion(question: 'أيّ جملة تحتوي أسلوب استفهام؟', options: ['العلم نور', 'ما أجملَ الربيع!', 'متى يبدأ الدرس؟', 'اكتب واجبك'], correctIndex: 2, explanation: '«متى» اسم استفهام يُستخدم للسؤال عن الزمان.'),
    ],
  }),
  ReviewSubject('التربية الإسلامية', Icons.mosque_rounded, Color(0xFF16866A), {
    'القرآن الكريم': [
      ReviewQuestion(question: 'ما المقصود بالتدبّر عند قراءة القرآن الكريم؟', options: ['سرعة القراءة فقط', 'التفكّر في المعاني والعمل بالهداية', 'ترك فهم الآيات', 'قراءة دون انتباه'], correctIndex: 1, explanation: 'التدبّر هو التفكّر في معاني الآيات واستخلاص الهداية والعمل بها.'),
      ReviewQuestion(question: 'أيّ سلوك يعبّر عن برّ الوالدين؟', options: ['رفع الصوت عليهما', 'إهمال حاجتهما', 'الإحسان إليهما واحترامهما', 'مقاطعتهما'], correctIndex: 2, explanation: 'من البرّ طاعة الوالدين في المعروف، والإحسان إليهما وخفض الجناح لهما.'),
      ReviewQuestion(question: 'ما أثر الصدق في المجتمع؟', options: ['نشر الثقة بين الناس', 'زيادة الخصومات', 'ضياع الحقوق', 'نشر الخوف'], correctIndex: 0, explanation: 'الصدق يعزّز الثقة والأمانة ويحفظ الحقوق بين أفراد المجتمع.'),
    ],
    'الأخلاق والعبادات': [
      ReviewQuestion(question: 'ما معنى الأمانة؟', options: ['حفظ الحقوق وأداء ما اؤتمن عليه الإنسان', 'إخفاء حقوق الآخرين', 'نقض العهد', 'التهاون بالواجب'], correctIndex: 0, explanation: 'الأمانة تشمل حفظ الودائع وأداء الحقوق والوفاء بالمسؤوليات.'),
      ReviewQuestion(question: 'أيّ مما يأتي من آداب الحوار؟', options: ['السخرية', 'مقاطعة المتحدث', 'احترام الرأي والاستماع', 'رفع الصوت'], correctIndex: 2, explanation: 'الحوار النافع يقوم على الاحترام وحسن الاستماع وترك الإساءة.'),
      ReviewQuestion(question: 'ما المقصد من الزكاة؟', options: ['التفاخر بالمال', 'تطهير المال ومساعدة المستحقين', 'منع التكافل', 'إيذاء الفقير'], correctIndex: 1, explanation: 'الزكاة عبادة تحقق التكافل وتطهّر المال والنفس وفق أحكامها.'),
    ],
  }),
  ReviewSubject('اللغة الإنكليزية', Icons.translate_rounded, Color(0xFF5267C9), {
    'Unit 1: Grammar': [
      ReviewQuestion(question: 'Choose the correct sentence.', options: ['She go to school every day.', 'She goes to school every day.', 'She going to school every day.', 'She gone to school every day.'], correctIndex: 1, explanation: 'في المضارع البسيط نضيف s إلى الفعل مع he / she / it.'),
      ReviewQuestion(question: 'What is the past form of “go”?', options: ['goed', 'goes', 'went', 'going'], correctIndex: 2, explanation: 'الفعل go غير منتظم، وصيغة الماضي منه went.'),
      ReviewQuestion(question: 'Choose the correct question word: “___ is your birthday?”', options: ['Where', 'When', 'Who', 'Why'], correctIndex: 1, explanation: 'نستخدم When للسؤال عن الوقت أو التاريخ.'),
    ],
    'Unit 2: Vocabulary': [
      ReviewQuestion(question: 'The opposite of “expensive” is:', options: ['cheap', 'large', 'difficult', 'early'], correctIndex: 0, explanation: 'Expensive تعني غالي الثمن، وعكسها cheap أي رخيص.'),
      ReviewQuestion(question: 'A person who treats sick people is a:', options: ['pilot', 'doctor', 'farmer', 'driver'], correctIndex: 1, explanation: 'Doctor تعني طبيب، وهو الشخص الذي يعالج المرضى.'),
      ReviewQuestion(question: 'Choose the correct plural of “child”.', options: ['childs', 'childes', 'children', 'childrens'], correctIndex: 2, explanation: 'جمع child غير منتظم، وصيغته الصحيحة children.'),
    ],
  }),
  ReviewSubject('الاجتماعيات', Icons.public_rounded, Color(0xFFB65C69), {
    'التاريخ': [
      ReviewQuestion(question: 'ما المقصود بالمصدر التاريخي؟', options: ['دليل يساعد على معرفة أحداث الماضي', 'توقعات الطقس', 'خريطة الطرق الحديثة فقط', 'رأي بلا دليل'], correctIndex: 0, explanation: 'المصدر التاريخي وثيقة أو أثر أو رواية يُستفاد منها في دراسة الماضي والتحقق من أحداثه.'),
      ReviewQuestion(question: 'لماذا تُقارن الروايات التاريخية بمصادر متعددة؟', options: ['لإهمال الأدلة', 'للتحقق من دقة المعلومات', 'لزيادة الأخطاء', 'لتغيير التواريخ'], correctIndex: 1, explanation: 'مقارنة المصادر تساعد الباحث على التثبت والتمييز بين المعلومة والرواية غير الدقيقة.'),
      ReviewQuestion(question: 'أيّ مما يأتي مثال على أثر مادي؟', options: ['قلعة تاريخية', 'توقع شخصي', 'إشاعة', 'حلم'], correctIndex: 0, explanation: 'القلعة أثر مادي باقٍ يمكن دراسته بوصفه شاهداً على الماضي.'),
    ],
    'الجغرافية': [
      ReviewQuestion(question: 'ما الأداة التي تُستخدم لتمثيل سطح الأرض أو جزء منه؟', options: ['الخريطة', 'الساعة', 'المسطرة فقط', 'الميزان'], correctIndex: 0, explanation: 'الخريطة تمثيل مصغّر لسطح الأرض أو جزء منه باستخدام رموز ومقياس رسم.'),
      ReviewQuestion(question: 'ماذا يوضح مقياس الرسم؟', options: ['اتجاه الرياح فقط', 'العلاقة بين المسافة على الخريطة والمسافة الحقيقية', 'عدد السكان فقط', 'درجة الحرارة'], correctIndex: 1, explanation: 'مقياس الرسم يبيّن مقدار تصغير المسافات الحقيقية عند تمثيلها على الخريطة.'),
      ReviewQuestion(question: 'ما الجهات الأصلية؟', options: ['الشمال والجنوب والشرق والغرب', 'أعلى وأسفل فقط', 'يمين ويسار فقط', 'الشمال الشرقي فقط'], correctIndex: 0, explanation: 'الجهات الأصلية أربع: الشمال والجنوب والشرق والغرب.'),
    ],
  }),
  ReviewSubject('الفيزياء', Icons.bolt_rounded, Color(0xFFD18A25), {
    'الكهربائية': [
      ReviewQuestion(question: 'ما وحدة قياس شدة التيار الكهربائي؟', options: ['الفولت', 'الأمبير', 'الأوم', 'الواط'], correctIndex: 1, explanation: 'تقاس شدة التيار الكهربائي بوحدة الأمبير (A).'),
      ReviewQuestion(question: 'ما وظيفة المفتاح في الدائرة الكهربائية؟', options: ['قياس الكتلة', 'فتح الدائرة وغلقها', 'زيادة طول السلك', 'تحويل الضوء إلى صوت'], correctIndex: 1, explanation: 'المفتاح يتحكم بمرور التيار عبر فتح الدائرة أو إغلاقها.'),
      ReviewQuestion(question: 'ما وحدة قياس المقاومة الكهربائية؟', options: ['الأوم', 'الأمبير', 'الكولوم', 'الفولت'], correctIndex: 0, explanation: 'وحدة قياس المقاومة الكهربائية هي الأوم ويرمز لها Ω.'),
    ],
    'المغناطيسية': [
      ReviewQuestion(question: 'أيّ الأجسام الآتية ينجذب عادةً إلى المغناطيس؟', options: ['قطعة حديد', 'قطعة خشب', 'ورقة', 'قطعة زجاج'], correctIndex: 0, explanation: 'الحديد من المواد الحديدومغناطيسية التي تنجذب إلى المغناطيس.'),
      ReviewQuestion(question: 'ماذا يحدث بين قطبين مغناطيسيين متماثلين؟', options: ['يتجاذبان', 'يتنافران', 'يختفي المجال', 'لا يتأثران مطلقاً'], correctIndex: 1, explanation: 'الأقطاب المتشابهة تتنافر، والأقطاب المختلفة تتجاذب.'),
      ReviewQuestion(question: 'أين تكون قوة المغناطيس أكبر غالباً؟', options: ['عند قطبيه', 'في منتصفه فقط', 'بعيداً عنه جداً', 'لا توجد قوة عند الأقطاب'], correctIndex: 0, explanation: 'تتركز شدة المجال المغناطيسي بصورة أكبر قرب القطبين.'),
    ],
  }),
  ReviewSubject('الكيمياء', Icons.science_rounded, Color(0xFF2787B8), {
    'الذرة والعناصر': [
      ReviewQuestion(question: 'ما الجسيم الذي يحمل شحنة كهربائية موجبة في الذرة؟', options: ['الإلكترون', 'النيوترون', 'البروتون', 'الجزيء'], correctIndex: 2, explanation: 'البروتون جسيم موجب الشحنة يوجد في نواة الذرة.'),
      ReviewQuestion(question: 'أين توجد الإلكترونات في نموذج الذرة؟', options: ['في النواة', 'حول النواة في مستويات طاقة', 'داخل البروتون', 'خارج الذرة تماماً'], correctIndex: 1, explanation: 'توجد الإلكترونات حول النواة ضمن مستويات أو أغلفة طاقة.'),
      ReviewQuestion(question: 'العدد الذري للعنصر يساوي عدد:', options: ['النيوترونات فقط', 'البروتونات', 'مستويات الطاقة', 'الجزيئات'], correctIndex: 1, explanation: 'العدد الذري يساوي عدد البروتونات في نواة الذرة.'),
    ],
    'الروابط والتفاعلات': [
      ReviewQuestion(question: 'ما الذي يحدث في الرابطة الأيونية؟', options: ['انتقال إلكترونات وتكوّن أيونات', 'اختفاء النواة', 'تحول البروتونات إلى نيوترونات', 'عدم حدوث أي تجاذب'], correctIndex: 0, explanation: 'تنشأ الرابطة الأيونية غالباً بعد انتقال إلكترونات وتكوّن أيونات متعاكسة الشحنة تتجاذب.'),
      ReviewQuestion(question: 'ما الرمز الكيميائي للماء؟', options: ['CO₂', 'O₂', 'H₂O', 'NaCl'], correctIndex: 2, explanation: 'يتكون جزيء الماء من ذرتي هيدروجين وذرة أكسجين، وصيغته H₂O.'),
      ReviewQuestion(question: 'ماذا تعبّر المعادلة الكيميائية الموزونة؟', options: ['تساوي عدد ذرات كل عنصر في الطرفين', 'اختلاف عدد الذرات دائماً', 'لون المواد فقط', 'سرعة التفاعل فقط'], correctIndex: 0, explanation: 'يجب أن يتساوى عدد ذرات كل عنصر في طرفي المعادلة وفق قانون حفظ الكتلة.'),
    ],
  }),
  ReviewSubject('الأحياء', Icons.biotech_rounded, Color(0xFF269B75), {
    'الخلية': [
      ReviewQuestion(question: 'ما الوحدة الأساسية في بناء أجسام الكائنات الحية؟', options: ['الخلية', 'النسيج فقط', 'العضو', 'الجهاز'], correctIndex: 0, explanation: 'الخلية هي الوحدة التركيبية والوظيفية الأساسية للكائن الحي.'),
      ReviewQuestion(question: 'ما الجزء الذي ينظم معظم فعاليات الخلية ويحتوي المادة الوراثية؟', options: ['الغشاء', 'النواة', 'الفجوة', 'الجدار الخلوي فقط'], correctIndex: 1, explanation: 'النواة تحتوي المادة الوراثية وتؤدي دوراً رئيسياً في تنظيم أنشطة الخلية.'),
      ReviewQuestion(question: 'ما وظيفة الغشاء البلازمي؟', options: ['تنظيم مرور المواد من الخلية وإليها', 'صنع العظام', 'ضخ الدم', 'هضم الطعام خارج الجسم'], correctIndex: 0, explanation: 'الغشاء البلازمي حاجز اختياري النفاذية ينظم تبادل المواد بين الخلية وبيئتها.'),
    ],
    'أجهزة جسم الإنسان': [
      ReviewQuestion(question: 'ما العضو الرئيس المسؤول عن ضخ الدم؟', options: ['الرئة', 'القلب', 'المعدة', 'الكبد'], correctIndex: 1, explanation: 'القلب عضلة تضخ الدم عبر الأوعية الدموية إلى أنحاء الجسم.'),
      ReviewQuestion(question: 'أين يحدث معظم امتصاص الغذاء المهضوم؟', options: ['الأمعاء الدقيقة', 'المريء', 'الفم', 'القصبة الهوائية'], correctIndex: 0, explanation: 'تتم معظم عملية امتصاص نواتج الهضم في الأمعاء الدقيقة عبر الزغابات.'),
      ReviewQuestion(question: 'ما الوظيفة الأساسية للرئتين؟', options: ['تنقية الدم من الفضلات الصلبة', 'تبادل الغازات التنفسية', 'هضم البروتين', 'إنتاج العصارة الصفراوية'], correctIndex: 1, explanation: 'تقوم الرئتان بتبادل الأوكسجين وثاني أوكسيد الكربون بين الهواء والدم.'),
    ],
  }),
  ReviewSubject('الرياضيات', Icons.functions_rounded, Color(0xFF7A52C7), {
    'الأعداد الحقيقية': [
      ReviewQuestion(question: 'ما قيمة الجذر التربيعي الرئيسي للعدد 81؟', options: ['8', '9', '−9', '18'], correctIndex: 1, explanation: 'لأن 9 × 9 = 81، فإن الجذر التربيعي الرئيسي يساوي 9.'),
      ReviewQuestion(question: 'أيّ الأعداد الآتية غير نسبي؟', options: ['1/2', '0.25', '√2', '3'], correctIndex: 2, explanation: '√2 لا يمكن كتابته على صورة كسر من عددين صحيحين، لذلك هو عدد غير نسبي.'),
      ReviewQuestion(question: 'ما ناتج 2³؟', options: ['6', '8', '9', '12'], correctIndex: 1, explanation: '2³ تعني 2 × 2 × 2 ويساوي 8.'),
    ],
    'كثيرات الحدود': [
      ReviewQuestion(question: 'ما درجة كثيرة الحدود 4x³ + 2x − 7؟', options: ['1', '2', '3', '4'], correctIndex: 2, explanation: 'درجة كثيرة الحدود هي أكبر أس للمتغير، وهنا أكبر أس هو 3.'),
      ReviewQuestion(question: 'ما ناتج جمع 3x + 2x؟', options: ['5x', '5x²', '6x', 'x'], correctIndex: 0, explanation: 'نجمع معاملات الحدود المتشابهة: 3x + 2x = 5x.'),
      ReviewQuestion(question: 'إذا كان x = 2، فما قيمة x² + 1؟', options: ['3', '4', '5', '6'], correctIndex: 2, explanation: 'نعوّض x = 2 فنحصل على 2² + 1 = 4 + 1 = 5.'),
    ],
  }),
];

class ReviewQuizScreen extends StatefulWidget {
  const ReviewQuizScreen({super.key});
  @override
  State<ReviewQuizScreen> createState() => _ReviewQuizScreenState();
}

class _ReviewQuizScreenState extends State<ReviewQuizScreen> {
  ReviewSubject? _subject;
  String? _chapter;
  int _questionIndex = 0;
  int? _selected;
  int _score = 0;
  bool _finished = false;

  List<ReviewQuestion> get _questions =>
      _subject == null || _chapter == null
          ? const []
          : _subject!.chapters[_chapter!] ?? const [];

  void _startChapter(ReviewSubject subject, String chapter) {
    setState(() {
      _subject = subject;
      _chapter = chapter;
      _questionIndex = 0;
      _selected = null;
      _score = 0;
      _finished = false;
    });
  }

  void _choose(int index) {
    if (_selected != null) return;
    setState(() {
      _selected = index;
      if (index == _questions[_questionIndex].correctIndex) _score++;
    });
  }

  void _next() {
    if (_questionIndex + 1 >= _questions.length) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _questionIndex++;
        _selected = null;
      });
    }
  }

  void _backToSubjects() {
    setState(() {
      _subject = null;
      _chapter = null;
      _selected = null;
      _finished = false;
      _score = 0;
      _questionIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مراجعة وتحدّي'),
          actions: [
            if (_subject != null)
              IconButton(
                tooltip: 'اختيار مادة أخرى',
                onPressed: _backToSubjects,
                icon: const Icon(Icons.restart_alt_rounded),
              ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _subject == null
              ? _buildSubjects(colors)
              : _chapter == null
                  ? _buildChapters(colors)
                  : _buildQuiz(colors),
        ),
      ),
    );
  }

  Widget _buildSubjects(ColorScheme colors) => ListView(
    key: const ValueKey('review-subjects'),
    padding: const EdgeInsets.all(16),
    children: [
      Text('اختَر المادة', style: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w900, color: colors.onSurface)),
      const SizedBox(height: 6),
      Text('ابدأ تحدّياً قصيراً، وتعلّم من الإجابة حتى لو أخطأت.',
        style: TextStyle(color: colors.onSurfaceVariant, height: 1.6)),
      const SizedBox(height: 16),
      ...reviewSubjects.map((subject) => Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: subject.color.withValues(alpha: .13),
            child: Icon(subject.icon, color: subject.color)),
          title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${subject.chapters.length} فصول / موضوعات تدريبية'),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () => setState(() => _subject = subject),
        ),
      )),
      const SizedBox(height: 8),
      Text('الأسئلة تدريبية للمراجعة وليست أسئلة وزارية رسمية.',
        style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
    ],
  );

  Widget _buildChapters(ColorScheme colors) => ListView(
    key: const ValueKey('review-chapters'),
    padding: const EdgeInsets.all(16),
    children: [
      Text(_subject!.name, style: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w900, color: colors.onSurface)),
      const SizedBox(height: 8),
      Text('اختَر الفصل أو الموضوع الذي تريد مراجعته.'),
      const SizedBox(height: 16),
      ..._subject!.chapters.entries.map((entry) => Card(
        child: ListTile(
          leading: Icon(Icons.auto_stories_rounded, color: _subject!.color),
          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${entry.value.length} أسئلة اختيار من متعدد'),
          trailing: const Icon(Icons.play_circle_outline_rounded),
          onTap: () => _startChapter(_subject!, entry.key),
        ),
      )),
      TextButton.icon(
        onPressed: _backToSubjects,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('العودة للمواد'),
      ),
    ],
  );

  Widget _buildQuiz(ColorScheme colors) {
    if (_finished) {
      final total = _questions.length;
      return Center(
        key: const ValueKey('review-finished'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_rounded, size: 64, color: colors.primary),
              const SizedBox(height: 12),
              const Text('أحسنت! أكملت التحدّي',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('نتيجتك: $_score من $total',
                style: TextStyle(fontSize: 18, color: colors.primary,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _startChapter(_subject!, _chapter!),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة الفصل'),
              ),
              TextButton(onPressed: _backToSubjects,
                child: const Text('اختيار مادة أخرى')),
            ],
          ),
        ),
      );
    }

    final question = _questions[_questionIndex];
    final answered = _selected != null;
    return ListView(
      key: ValueKey('review-question-$_questionIndex'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: Text('${_subject!.name} • $_chapter',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700))),
          Text('${_questionIndex + 1}/${_questions.length}',
            style: TextStyle(color: colors.primary, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: LinearProgressIndicator(
            value: (_questionIndex + (answered ? 1 : 0)) / _questions.length,
            minHeight: 7,
          ),
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(question.question, style: const TextStyle(
              fontSize: 18, height: 1.6, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(question.options.length, (index) {
          final isCorrect = index == question.correctIndex;
          final isWrongChoice = answered && index == _selected && !isCorrect;
          Color? background;
          Color? foreground;
          if (answered && isCorrect) {
            background = const Color(0xFF16866A).withValues(alpha: .13);
            foreground = const Color(0xFF16866A);
          } else if (isWrongChoice) {
            background = colors.errorContainer;
            foreground = colors.onErrorContainer;
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Material(
              color: background ?? colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: answered ? null : () => _choose(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: foreground?.withValues(alpha: .14) ??
                          colors.surfaceContainerHighest,
                      child: Text(String.fromCharCode(65 + index),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                          color: foreground ?? colors.onSurfaceVariant)),
                    ),
                    const SizedBox(width: 11),
                    Expanded(child: Text(question.options[index],
                      style: TextStyle(fontWeight: FontWeight.w700,
                        color: foreground ?? colors.onSurface))),
                    if (answered && isCorrect)
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF16866A))
                    else if (isWrongChoice)
                      Icon(Icons.cancel_rounded, color: colors.error),
                  ]),
                ),
              ),
            ),
          );
        }),
        if (answered) ...[
          const SizedBox(height: 8),
          Card(
            color: _selected == question.correctIndex
                ? const Color(0xFF16866A).withValues(alpha: .10)
                : colors.errorContainer.withValues(alpha: .55),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(_selected == question.correctIndex
                      ? Icons.verified_rounded : Icons.lightbulb_outline_rounded,
                    color: _selected == question.correctIndex
                        ? const Color(0xFF16866A) : colors.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    _selected == question.correctIndex ? 'إجابة صحيحة، أحسنت!' : 'مو مشكلة، نتعلّم من الخطأ',
                    style: const TextStyle(fontWeight: FontWeight.w900))),
                ]),
                const SizedBox(height: 8),
                Text('الإجابة الصحيحة: ${question.options[question.correctIndex]}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(question.explanation, style: const TextStyle(height: 1.6)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _next,
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(_questionIndex + 1 == _questions.length
                ? 'عرض النتيجة' : 'السؤال التالي'),
          ),
          if (_selected != question.correctIndex)
            TextButton.icon(
              onPressed: () => setState(() => _selected = null),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
        ],
      ],
    );
  }
}

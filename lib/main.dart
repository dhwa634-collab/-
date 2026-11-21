// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); await SavedExamsStore.load(); runApp(const StudyApp()); }
const navy=Color(0xFF142D50), blue=Color(0xFF2868D7), bg=Color(0xFFF3F6FB);
const subjects=<Subject>[
 Subject('التربية الإسلامية',Icons.mosque_rounded,Color(0xFF16866A)),
 Subject('اللغة العربية',Icons.menu_book_rounded,Color(0xFFB76E24)),
 Subject('اللغة الإنكليزية',Icons.translate_rounded,Color(0xFF5267C9)),
 Subject('الرياضيات',Icons.functions_rounded,Color(0xFF7A52C7)),
 Subject('الاجتماعيات',Icons.public_rounded,Color(0xFFB65C69)),
 Subject('الأحياء',Icons.biotech_rounded,Color(0xFF269B75)),
 Subject('الكيمياء',Icons.science_rounded,Color(0xFF2787B8)),
 Subject('الفيزياء',Icons.bolt_rounded,Color(0xFFD18A25)),
];
class Subject {final String name; final IconData icon; final Color color; const Subject(this.name,this.icon,this.color);}

class SavedExamsStore {
  static const String _storageKey = 'saved_exam_sheets_v1';
  static final ValueNotifier<List<Map<String, String>>> items =
      ValueNotifier<List<Map<String, String>>>([]);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        items.value = decoded.whereType<Map>()
            .map((entry) => Map<String, String>.from(entry)).toList();
      }
    } catch (_) {
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

class StudyApp extends StatelessWidget {const StudyApp({super.key}); @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'وزاريات الثالث متوسط',theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:blue),cardTheme:CardThemeData(color:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)))),home:const Shell());}
class Shell extends StatefulWidget {const Shell({super.key}); @override State<Shell> createState()=>_ShellState();}
class _ShellState extends State<Shell>{int tab=0; void open(Subject s)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>SubjectScreen(subject:s))); @override Widget build(BuildContext context){final pages=[Home(onOpen:open,onAll:()=>setState(()=>tab=1)),Catalog(onOpen:open),const Saved(),const About()];return Directionality(textDirection:TextDirection.rtl,child:Scaffold(body:SafeArea(child:IndexedStack(index:tab,children:pages)),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),backgroundColor:Colors.white,destinations:const [NavigationDestination(icon:Icon(Icons.home_rounded),label:'الرئيسية'),NavigationDestination(icon:Icon(Icons.grid_view_rounded),label:'المواد'),NavigationDestination(icon:Icon(Icons.bookmark_rounded),label:'المحفوظات'),NavigationDestination(icon:Icon(Icons.info_outline),label:'حول')])));}}
class Home extends StatelessWidget{final ValueChanged<Subject> onOpen;final VoidCallback onAll;const Home({super.key,required this.onOpen,required this.onAll});@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
 Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:blue,borderRadius:BorderRadius.circular(15)),child:const Icon(Icons.school,color:Colors.white,size:28)),const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('دليلك للنجاح',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),Text('الثالث متوسط • العراق',style:TextStyle(color:Colors.blueGrey))])),IconButton(tooltip:'البحث في الأرشيف',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ArchiveSearchScreen())),icon:const Icon(Icons.search,color:navy))]),
 const SizedBox(height:22),
 Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF173D78),Color(0xFF2675E8)]),borderRadius:BorderRadius.circular(25)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('منصة المراجعة الشاملة',style:TextStyle(color:Colors.white70)),const SizedBox(height:12),const Text('استعد للوزاري\nبخطوات واثقة',style:TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.w900,height:1.35)),const SizedBox(height:8),const Text('الأسئلة الوزارية والتمهيدية مع الحلول النموذجية',style:TextStyle(color:Colors.white70,height:1.6)),const SizedBox(height:15),FilledButton.icon(onPressed:onAll,style:FilledButton.styleFrom(backgroundColor:Colors.white,foregroundColor:navy),icon:const Icon(Icons.arrow_back),label:const Text('تصفح المواد'))])),
 const SizedBox(height:18),
 Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),child:Row(children:[Container(width:46,height:46,decoration:BoxDecoration(color:blue.withValues(alpha:.10),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.auto_awesome,color:blue)),const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('المساعد الذكي',style:TextStyle(fontWeight:FontWeight.w900,color:navy,fontSize:16)),Text('اسأل عن أي مادة واحصل على شرح خطوة بخطوة',style:TextStyle(color:Colors.blueGrey,fontSize:12))])),FilledButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AiAssistantScreen())),child:const Text('افتح'))])),
 const SizedBox(height:24),Row(children:[const Expanded(child:Text('المواد الدراسية',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:navy))),TextButton(onPressed:onAll,child:const Text('عرض الكل'))]),const SizedBox(height:8),
 GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:subjects.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:11,mainAxisSpacing:11,childAspectRatio:1.65),itemBuilder:(_,i)=>SubjectTile(subject:subjects[i],onTap:()=>onOpen(subjects[i]))),
 const SizedBox(height:24),const Text('مميزات التطبيق',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:12),
 const Feature(icon:Icons.history_edu,title:'أرشيف حسب السنة والدور',desc:'وزاري وتمهيدي بترتيب واضح'),const Feature(icon:Icons.fact_check_outlined,title:'حلول نموذجية مفصلة',desc:'خطوات الحل وشرح الإجابات'),const Feature(icon:Icons.search,title:'بحث وحفظ سريع',desc:'اعثر على الأسئلة وراجعها لاحقاً'),
 const SizedBox(height:12),Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFFFFF5DF),borderRadius:BorderRadius.circular(15)),child:const Text('تنبيه: الأرشيف يجري تجهيزه والتحقق من مصادره. لن ننسب أسئلة تجريبية إلى الامتحانات الوزارية.',style:TextStyle(color:Color(0xFF76551B),height:1.6,fontSize:12)))
 ]);}
class SubjectTile extends StatelessWidget{final Subject subject;final VoidCallback onTap;const SubjectTile({super.key,required this.subject,required this.onTap});@override Widget build(BuildContext context)=>Material(color:Colors.white,borderRadius:BorderRadius.circular(18),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[Container(width:42,height:42,decoration:BoxDecoration(color:subject.color.withValues(alpha:.12),borderRadius:BorderRadius.circular(13)),child:Icon(subject.icon,color:subject.color)),const SizedBox(width:9),Expanded(child:Text(subject.name,style:const TextStyle(fontWeight:FontWeight.w800,color:navy,fontSize:13))),const Icon(Icons.chevron_left,color:Colors.blueGrey)]))));}
class Catalog extends StatelessWidget{final ValueChanged<Subject> onOpen;const Catalog({super.key,required this.onOpen});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const SizedBox(height:12),const Text('المواد الدراسية',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:6),const Text('اختر المادة للوصول إلى أرشيفها'),const SizedBox(height:18),Expanded(child:GridView.builder(itemCount:subjects.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:11,mainAxisSpacing:11,childAspectRatio:1.55),itemBuilder:(_,i)=>SubjectTile(subject:subjects[i],onTap:()=>onOpen(subjects[i]))))]));}

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

  List<_ArchiveSearchItem> get allItems {
    final result = <_ArchiveSearchItem>[];
    for (final entry in _SubjectScreenState.arabicExams.entries) {
      for (final round in entry.value.entries) {
        for (final path in round.value) {
          result.add(_ArchiveSearchItem(subjects[1], entry.key, round.key, path));
        }
      }
    }
    for (final entry in _SubjectScreenState.chemistryExams.entries) {
      for (final round in entry.value.entries) {
        for (final path in round.value) {
          result.add(_ArchiveSearchItem(subjects[6], entry.key, round.key, path));
        }
      }
    }
    return result;
  }

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
    const rounds = ['التمهيدي', 'الدور الأول', 'الدور الثاني', 'الدور الثالث'];
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
                fillColor: Colors.white,
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
              items: ['كل المواد', ...subjects.map((s) => s.name)]
                .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => subjectFilter = v ?? 'كل المواد'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: yearFilter,
              decoration: const InputDecoration(labelText: 'السنة'),
              items: ['كل السنوات', ...years]
                .map((v) => DropdownMenuItem(value: v, child: Text(v == 'كل السنوات' ? v : '${int.parse(v)-1}–$v'))).toList(),
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
              style: const TextStyle(fontWeight: FontWeight.w900, color: navy)),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Text('ماكو أوراق مطابقة حالياً. الأرشيف يُحدّث تدريجياً.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueGrey, height: 1.7)),
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
  String get academicYear => '${int.parse(year)-1}–$year';
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

  @override
  void initState() {
    super.initState();
    year = years.contains(widget.initialYear) ? widget.initialYear : '2025';
    kind = rounds.contains(widget.initialKind) ? widget.initialKind : 'الدور الأول';
  }
  static const years = <String>[
    '2025','2024','2023','2022','2021','2020','2019','2018',
    '2017','2016','2015','2014','2013','2012'
  ];
  static const rounds = <String>[
    'التمهيدي','الدور الأول','الدور الثاني','الدور الثالث'
  ];

  // All chemistry exam images, classified by the year and round printed on each paper.
  static const Map<String, Map<String, List<String>>> chemistryExams = {
    '2025': {
      'التمهيدي': ['assets/exams/chemistry/FB_IMG_1795016739318.jpg'],
      'الدور الأول': ['assets/exams/chemistry/2024_2025_first.jpg', 'assets/exams/chemistry/FB_IMG_1795016765951.jpg'],
      'الدور الثاني': ['assets/exams/chemistry/2024_2025_second_1.jpg', 'assets/exams/chemistry/2024_2025_second_2.jpg', 'assets/exams/chemistry/FB_IMG_1795016764120.jpg'],
      'الدور الثالث': ['assets/exams/chemistry/FB_IMG_1795016750316.jpg'],
    },
    '2024': {
      'التمهيدي': ['assets/exams/chemistry/FB_IMG_1795016734474.jpg'],
      'الدور الأول': ['assets/exams/chemistry/2023_2024_first.jpg'],
      'الدور الثاني': ['assets/exams/chemistry/FB_IMG_1795016771316.jpg'],
      'الدور الثالث': ['assets/exams/chemistry/2023_2024_third.jpg', 'assets/exams/chemistry/FB_IMG_1795016768326.jpg'],
    },
    '2023': {
      'التمهيدي': ['assets/exams/chemistry/2022_2023_preparatory.jpg', 'assets/exams/chemistry/FB_IMG_1795016741729.jpg'],
      'الدور الأول': ['assets/exams/chemistry/FB_IMG_1795016744285.jpg', 'assets/exams/chemistry/FB_IMG_1795016770035.jpg'],
      'الدور الثاني': ['assets/exams/chemistry/2022_2023_second.jpg', 'assets/exams/chemistry/FB_IMG_1795016746673.jpg', 'assets/exams/chemistry/FB_IMG_1795016762267.jpg'],
      'الدور الثالث': ['assets/exams/chemistry/FB_IMG_1795016752643.jpg'],
    },
    '2022': {
      'التمهيدي': ['assets/exams/chemistry/2021_2022_preparatory.jpg', 'assets/exams/chemistry/FB_IMG_1795016758333.jpg'],
      'الدور الأول': ['assets/exams/chemistry/FB_IMG_1795016748472.jpg'],
      'الدور الثاني': ['assets/exams/chemistry/FB_IMG_1795016754509.jpg'],
      'الدور الثالث': ['assets/exams/chemistry/2021_2022_third.jpg', 'assets/exams/chemistry/FB_IMG_1795016760064.jpg'],
    },
    '2021': {
      'التمهيدي': ['assets/exams/chemistry/FB_IMG_1795016756344.jpg'],
      'الدور الأول': ['assets/exams/chemistry/FB_IMG_1795016737295.jpg'],
    },
  };

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

  List<String> get selectedImages {
    if (widget.subject.name == 'الكيمياء') {
      return chemistryExams[year]?[kind] ?? const <String>[];
    }
    if (widget.subject.name == 'اللغة العربية') {
      return arabicExams[year]?[kind] ?? const <String>[];
    }
    return const <String>[];
  }

  String get academicYear {
    final endYear = int.tryParse(year);
    if (endYear == null) return year;
    return '${endYear - 1}–$endYear';
  }

  void openImage(String path) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('صورة الامتحان'),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Image.asset(path, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'تعذر تحميل الصورة', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final images = selectedImages;
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
                Expanded(child: Text('أرشيف ${widget.subject.name}',
                  style: const TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w900, color: navy))),
              ]),
            ),
            const SizedBox(height: 22),
            const Text('السنة الدراسية',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: year,
              decoration: InputDecoration(
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
              ),
              items: years.map((y) => DropdownMenuItem(
                value: y, child: Text(
                  y == '2025' || y == '2024' || y == '2023' || y == '2022'
                    ? '${int.parse(y)-1}–$y' : y),
              )).toList(),
              onChanged: (v) => setState(() => year = v ?? '2025'),
            ),
            const SizedBox(height: 18),
            const Text('الدور الامتحاني',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: rounds.map((v) => ChoiceChip(
                label: Text(v), selected: kind == v,
                onSelected: (_) => setState(() => kind = v),
              )).toList(),
            ),
            const SizedBox(height: 22),
            if ((widget.subject.name == 'الكيمياء' || widget.subject.name == 'اللغة العربية') && images.isNotEmpty) ...[
              Text('أسئلة ${widget.subject.name} • $academicYear • $kind',
                style: const TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w900, color: navy)),
              const SizedBox(height: 12),
              ...images.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => openImage(entry.value),
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
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(saved
                                      ? 'انحفظت الورقة بالمحفوظات'
                                      : 'انحذفت الورقة من المحفوظات'),
                                      duration: const Duration(seconds: 2)),
                                  );
                                } catch (_) {
                                  if (!messenger.mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(content:
                                      Text('تعذر حفظ الورقة على الجهاز')),
                                  );
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
                        Image.asset(entry.value, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('تعذر تحميل الصورة من ملفات التطبيق'),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('اضغط على الصورة للتكبير',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
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
                  color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Column(children: [
                  Icon(Icons.photo_library_outlined, size: 48,
                      color: widget.subject.color),
                  const SizedBox(height: 12),
                  const Text('لا توجد صورة مصنفة لهذا الاختيار حالياً',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17,
                      fontWeight: FontWeight.w900, color: navy)),
                  const SizedBox(height: 8),
                  Text(
                    (widget.subject.name == 'الكيمياء' || widget.subject.name == 'اللغة العربية')
                      ? 'الصور التي لم يُتحقق بعد من سنتها ودورها لم نضعها في تصنيف عشوائي.'
                      : 'سيُضاف أرشيف هذه المادة عند توفر أوراقها الأصلية.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.blueGrey, height: 1.8),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class Saved extends StatelessWidget {
  const Saved({super.key});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ValueListenableBuilder<List<Map<String, String>>>(
      valueListenable: SavedExamsStore.items,
      builder: (context, saved, _) {
        if (saved.isEmpty) {
          return const Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border, size: 55, color: Colors.blueGrey),
              SizedBox(height: 12),
              Text('المحفوظات', style: TextStyle(
                fontSize: 21, fontWeight: FontWeight.w900, color: navy)),
              SizedBox(height: 5),
              Text('احفظ أوراق الامتحانات لتصل إليها بسرعة هنا',
                style: TextStyle(color: Colors.blueGrey)),
            ],
          ));
        }
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('أوراقي المحفوظة', style: TextStyle(
              fontSize: 23, fontWeight: FontWeight.w900, color: navy)),
            const SizedBox(height: 5),
            Text('${saved.length} ورقة محفوظة للمراجعة',
              style: const TextStyle(color: Colors.blueGrey)),
            const SizedBox(height: 14),
            ...saved.map((exam) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(exam['path'] ?? '',
                    width: 52, height: 62, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      width: 52, height: 62,
                      child: Icon(Icons.image_not_supported_outlined)),
                  ),
                ),
                title: Text(exam['subject'] ?? 'مادة دراسية',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text("${exam['year'] ?? ''} • ${exam['round'] ?? ''}"),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: Scaffold(
                      backgroundColor: Colors.black,
                      appBar: AppBar(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        title: Text(exam['subject'] ?? 'صورة الامتحان'),
                      ),
                      body: Center(child: InteractiveViewer(
                        minScale: 0.8, maxScale: 5,
                        child: Image.asset(exam['path'] ?? '',
                          fit: BoxFit.contain),
                      )),
                    ),
                  ),
                )),
                trailing: IconButton(
                  tooltip: 'إزالة من المحفوظات',
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    await SavedExamsStore.remove(exam['path'] ?? '');
                  },
                ),
              ),
            )),
          ],
        );
      },
    ),
  );
}
class About extends StatelessWidget {
  const About({super.key});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 12),
        const Text('حول التطبيق', style: TextStyle(
          fontSize: 25, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 16),
        const Text(
          'منصة تعليمية مستقلة لمساعدة طلبة الثالث متوسط في العراق على مراجعة أوراق الامتحانات والاستفادة من المساعد الذكي.',
          style: TextStyle(fontSize: 15, height: 1.8)),
        const SizedBox(height: 12),
        const Text(
          'الأرشيف المتاح يُصنّف حسب المادة والسنة والدور بعد التحقق من بيانات الورقة. لا ننسب أي سؤال إلى امتحان وزاري دون دليل.',
          style: TextStyle(color: Colors.blueGrey, height: 1.8)),
        const SizedBox(height: 12),
        const Text('هذا التطبيق غير تابع لوزارة التربية العراقية.',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.blueGrey)),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: blue),
            title: const Text('سياسة الخصوصية',
              style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('كيف يتعامل التطبيق مع الأسئلة والمحفوظات'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const PrivacyScreen())),
          ),
        ),
        const SizedBox(height: 8),
        const Text('الإصدار 1.0.1',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
      ],
    ),
  );
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Text('البيانات التي يعالجها التطبيق',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: navy)),
          SizedBox(height: 8),
          Text('لا يتطلب التطبيق إنشاء حساب ولا يطلب الاسم أو رقم الهاتف أو البريد الإلكتروني أو الموقع أو كلمة المرور. قائمة أوراق الامتحانات المحفوظة تُخزّن محلياً على جهازك.'),
          SizedBox(height: 18),
          Text('المساعد الذكي ومزودو الخدمة',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: navy)),
          SizedBox(height: 8),
          Text('عند إرسال سؤال، يُرسل نص السؤال وجزءاً من سياق المحادثة إلى Cloudflare Worker ثم إلى Google Gemini لتوليد الإجابة. لا نرفق مع الطلب اسمك أو رقم هاتفك أو موقعك أو معرّف جهازك. قد تعالج Cloudflare وGoogle بيانات الطلب وفق سياساتهما.'),
          SizedBox(height: 18),
          Text('تقليل البيانات والاحتفاظ',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: navy)),
          SizedBox(height: 8),
          Text('يحاول التطبيق إزالة عناوين البريد الإلكتروني وأرقام الهاتف العراقية الواضحة قبل إرسال السؤال. لا يمكن ضمان اكتشاف كل المعلومات الشخصية؛ لذلك لا تكتب أسماءك أو عناوينك أو أي معلومات سرية. سجل المحادثة يبقى في الذاكرة أثناء الجلسة ولا يُحفظ كسجل دائم.'),
          SizedBox(height: 18),
          Text('بلاغات الإجابات',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: navy)),
          SizedBox(height: 8),
          Text('عند إرسال بلاغ عن إجابة، يُرسل سبب البلاغ والملاحظة الاختيارية فقط إلى خادم Cloudflare ليتمكن المطوّر من مراجعتها. لا نرسل نص السؤال أو الإجابة أو اسم الطالب أو معرّف جهازه ضمن البلاغ. تُحفظ نسخة محلية من البلاغ بعد نجاح الإرسال.'),
          SizedBox(height: 18),
          Text('حقوقك والتنويه',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: navy)),
          SizedBox(height: 8),
          Text('يمكنك حذف بيانات التطبيق من إعدادات جهازك. التطبيق مستقل وغير تابع لوزارة التربية العراقية. قد يخطئ الذكاء الاصطناعي؛ راجع الحلول مع الكتاب المدرسي أو مدرسك.'),
        ],
      ),
    ),
  );
}

class Feature extends StatelessWidget{final IconData icon;final String title,desc;const Feature({super.key,required this.icon,required this.title,required this.desc});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:9),child:Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),child:Row(children:[Icon(icon,color:blue,size:25),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),Text(desc,style:const TextStyle(fontSize:12,color:Colors.blueGrey))]))])));}


class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});
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
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ما وصل البلاغ إلى المطوّر. تحقق من اتصال الإنترنت وحاول مرة ثانية.'),
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
              style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
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
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: blue),
                SizedBox(width: 9),
                Expanded(child: Text(
                  'اسأل وتابع بنفس المحادثة. تنبيه: الردود مولّدة بالذكاء الاصطناعي وقد تحتوي على أخطاء؛ راجع الحلول الدراسية والوزارية مع الكتاب المدرسي أو مدرسك، ولا تعتمد عليها وحدها.',
                  style: TextStyle(color: navy, fontSize: 12, height: 1.55),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 17, height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 9),
                          Text('جاري التفكير...',
                            style: TextStyle(color: Colors.blueGrey)),
                        ],
                      ),
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
                      color: isUser ? blue : Colors.white,
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
                          color: isUser ? Colors.white : navy,
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
                                    size: 17, color: Colors.blueGrey),
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
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(
                  color: Color(0x0D142D50), blurRadius: 12,
                  offset: Offset(0, -3))],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: TextField(
                    controller: controller,
                    minLines: 1, maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => send(),
                    decoration: InputDecoration(
                      hintText: 'اكتب سؤالك الدراسي هنا...',
                      filled: true, fillColor: bg,
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

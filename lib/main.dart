// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
void main()=>runApp(const StudyApp());
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
class StudyApp extends StatelessWidget {const StudyApp({super.key}); @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'وزاريات الثالث متوسط',theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:blue),cardTheme:CardThemeData(color:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)))),home:const Shell());}
class Shell extends StatefulWidget {const Shell({super.key}); @override State<Shell> createState()=>_ShellState();}
class _ShellState extends State<Shell>{int tab=0; void open(Subject s)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>SubjectScreen(subject:s))); @override Widget build(BuildContext context){final pages=[Home(onOpen:open,onAll:()=>setState(()=>tab=1)),Catalog(onOpen:open),const Saved(),const About()];return Directionality(textDirection:TextDirection.rtl,child:Scaffold(body:SafeArea(child:IndexedStack(index:tab,children:pages)),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),backgroundColor:Colors.white,destinations:const [NavigationDestination(icon:Icon(Icons.home_rounded),label:'الرئيسية'),NavigationDestination(icon:Icon(Icons.grid_view_rounded),label:'المواد'),NavigationDestination(icon:Icon(Icons.bookmark_rounded),label:'المحفوظات'),NavigationDestination(icon:Icon(Icons.info_outline),label:'حول')])));}}
class Home extends StatelessWidget{final ValueChanged<Subject> onOpen;final VoidCallback onAll;const Home({super.key,required this.onOpen,required this.onAll});@override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
 Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:blue,borderRadius:BorderRadius.circular(15)),child:const Icon(Icons.school,color:Colors.white,size:28)),const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('دليلك للنجاح',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),Text('الثالث متوسط • العراق',style:TextStyle(color:Colors.blueGrey))])),const Icon(Icons.notifications_none,color:navy)]),
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
class SubjectScreen extends StatefulWidget {
  final Subject subject;
  const SubjectScreen({super.key, required this.subject});
  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  String kind = 'الدور الأول';
  String year = '2025';
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
                            const Icon(Icons.zoom_in, color: Colors.blueGrey),
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

class Saved extends StatelessWidget{const Saved({super.key});@override Widget build(BuildContext context)=>const Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.bookmark_border,size:55,color:Colors.blueGrey),SizedBox(height:12),Text('المحفوظات',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:navy)),Text('ستظهر هنا الأسئلة التي تحفظها للمراجعة',style:TextStyle(color:Colors.blueGrey))]));}
class About extends StatelessWidget{const About({super.key});@override Widget build(BuildContext context)=>const Padding(padding:EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(height:20),Text('حول التطبيق',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900,color:navy)),SizedBox(height:16),Text('منصة تعليمية مستقلة لمساعدة طلبة الثالث متوسط في العراق على مراجعة الأسئلة الوزارية والتمهيدية.',style:TextStyle(fontSize:15,height:1.8)),SizedBox(height:12),Text('سيُنسب المحتوى إلى مصدره مع التمييز بين نسخة السؤال الأصلية والحل النموذجي والشرح الإضافي.',style:TextStyle(color:Colors.blueGrey,height:1.8)),SizedBox(height:12),Text('هذا التطبيق غير تابع لوزارة التربية العراقية.',style:TextStyle(fontWeight:FontWeight.w800,color:Colors.blueGrey))]));}
class Feature extends StatelessWidget{final IconData icon;final String title,desc;const Feature({super.key,required this.icon,required this.title,required this.desc});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:9),child:Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),child:Row(children:[Icon(icon,color:blue,size:25),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w800,color:navy)),Text(desc,style:const TextStyle(fontSize:12,color:Colors.blueGrey))]))])));}


class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});
  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}
class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const String endpoint = 'https://YOUR-WORKER-NAME.workers.dev/chat';
  final controller = TextEditingController();
  final scrollController = ScrollController();
  final messages = <Map<String, String>>[
    {'role':'assistant','text':'هلا بيك! آني مساعدك الدراسي. اسألني عن مواد الثالث المتوسط، وأشرحلك الحل خطوة بخطوة.'}
  ];
  bool loading = false;
  Future<void> send() async {
    final question = controller.text.trim();
    if (question.isEmpty || loading) return;
    controller.clear();
    setState(() { messages.add({'role':'user','text':question}); loading = true; });
    _scrollDown();
    try {
      final response = await http.post(Uri.parse(endpoint),
        headers: {'Content-Type':'application/json'},
        body: jsonEncode({'message':question})).timeout(const Duration(seconds:60));
      if (response.statusCode != 200) throw Exception('تعذر إكمال الطلب (${response.statusCode})');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final answer = (data['reply'] ?? '').toString();
      if (answer.isEmpty) throw Exception('وصل رد فارغ من المساعد');
      setState(() => messages.add({'role':'assistant','text':answer}));
    } catch (e) {
      setState(() => messages.add({'role':'assistant','text':'ما كدرت أتصل بالمساعد حالياً. تأكد من نشر الخادم ووضع رابطه داخل التطبيق.\nالتفاصيل: ' + e.toString()}));
    } finally {
      if (mounted) { setState(() => loading = false); _scrollDown(); }
    }
  }
  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds:250), curve: Curves.easeOut);
      }
    });
  }
  @override
  void dispose() { controller.dispose(); scrollController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Directionality(textDirection:TextDirection.rtl,
    child:Scaffold(appBar:AppBar(title:const Text('المساعد الذكي',style:TextStyle(fontWeight:FontWeight.w900))),
      body:Column(children:[
        Expanded(child:ListView.builder(controller:scrollController,padding:const EdgeInsets.all(16),
          itemCount:messages.length+(loading?1:0),itemBuilder:(context,index){
            if(loading&&index==messages.length) return const Align(alignment:Alignment.centerRight,child:Padding(padding:EdgeInsets.all(12),child:CircularProgressIndicator()));
            final item=messages[index]; final isUser=item['role']=='user';
            return Align(alignment:isUser?Alignment.centerLeft:Alignment.centerRight,
              child:Container(constraints:BoxConstraints(maxWidth:MediaQuery.of(context).size.width*.84),
                margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(14),
                decoration:BoxDecoration(color:isUser?blue:Colors.white,borderRadius:BorderRadius.circular(17)),
                child:SelectableText(item['text']??'',style:TextStyle(color:isUser?Colors.white:navy,height:1.65,fontSize:15))));
          })),
        SafeArea(top:false,child:Padding(padding:const EdgeInsets.fromLTRB(12,8,12,12),
          child:Row(children:[
            Expanded(child:TextField(controller:controller,minLines:1,maxLines:5,
              textInputAction:TextInputAction.send,onSubmitted:(_)=>send(),
              decoration:InputDecoration(hintText:'اكتب سؤالك هنا...',filled:true,fillColor:Colors.white,
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none),
                contentPadding:const EdgeInsets.symmetric(horizontal:15,vertical:13)))),
            const SizedBox(width:8),IconButton.filled(onPressed:loading?null:send,icon:const Icon(Icons.send_rounded))
          ])))
      ])));
}

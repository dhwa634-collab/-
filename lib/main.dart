// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
 const SizedBox(height:24),Row(children:[const Expanded(child:Text('المواد الدراسية',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:navy))),TextButton(onPressed:onAll,child:const Text('عرض الكل'))]),const SizedBox(height:8),
 GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:subjects.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:11,mainAxisSpacing:11,childAspectRatio:1.65),itemBuilder:(_,i)=>SubjectTile(subject:subjects[i],onTap:()=>onOpen(subjects[i]))),
 const SizedBox(height:24),const Text('مميزات التطبيق',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:12),
 const Feature(icon:Icons.history_edu,title:'أرشيف حسب السنة والدور',desc:'وزاري وتمهيدي بترتيب واضح'),const Feature(icon:Icons.fact_check_outlined,title:'حلول نموذجية مفصلة',desc:'خطوات الحل وشرح الإجابات'),const Feature(icon:Icons.search,title:'بحث وحفظ سريع',desc:'اعثر على الأسئلة وراجعها لاحقاً'),
 const SizedBox(height:12),Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFFFFF5DF),borderRadius:BorderRadius.circular(15)),child:const Text('تنبيه: الأرشيف يجري تجهيزه والتحقق من مصادره. لن ننسب أسئلة تجريبية إلى الامتحانات الوزارية.',style:TextStyle(color:Color(0xFF76551B),height:1.6,fontSize:12)))
 ]);}
class SubjectTile extends StatelessWidget{final Subject subject;final VoidCallback onTap;const SubjectTile({super.key,required this.subject,required this.onTap});@override Widget build(BuildContext context)=>Material(color:Colors.white,borderRadius:BorderRadius.circular(18),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),child:Padding(padding:const EdgeInsets.all(12),child:Row(children:[Container(width:42,height:42,decoration:BoxDecoration(color:subject.color.withValues(alpha:.12),borderRadius:BorderRadius.circular(13)),child:Icon(subject.icon,color:subject.color)),const SizedBox(width:9),Expanded(child:Text(subject.name,style:const TextStyle(fontWeight:FontWeight.w800,color:navy,fontSize:13))),const Icon(Icons.chevron_left,color:Colors.blueGrey)]))));}
class Catalog extends StatelessWidget{final ValueChanged<Subject> onOpen;const Catalog({super.key,required this.onOpen});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const SizedBox(height:12),const Text('المواد الدراسية',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900,color:navy)),const SizedBox(height:6),const Text('اختر المادة للوصول إلى أرشيفها'),const SizedBox(height:18),Expanded(child:GridView.builder(itemCount:subjects.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:11,mainAxisSpacing:11,childAspectRatio:1.55),itemBuilder:(_,i)=>SubjectTile(subject:subjects[i],onTap:()=>onOpen(subjects[i]))))]));}
const questionSources = <String, Map<String, String>>{
  'التربية الإسلامية': {
    'الوزاري': 'https://mlazemna.com/sa25is3/',
    'التمهيدي': 'https://mlazemna.com/tm25is3/',
  },
  'اللغة العربية': {
    'الوزاري': 'https://mlazemna.com/sa25ar3/',
    'التمهيدي': 'https://mlazemna.com/tm25ar3/',
  },
  'اللغة الإنكليزية': {
    'الوزاري': 'https://mlazemna.com/sa25en/',
    'التمهيدي': 'https://mlazemna.com/tm25en3/',
  },
  'الرياضيات': {
    'الوزاري': 'https://mlazemna.com/sa25mt/',
    'التمهيدي': 'https://mlazemna.com/tm25mt3/',
  },
  'الاجتماعيات': {
    'الوزاري': 'https://mlazemna.com/sa25ga/',
    'التمهيدي': 'https://mlazemna.com/tm25gt3/',
  },
  'الأحياء': {
    'الوزاري': 'https://mlazemna.com/sa25bi/',
    'التمهيدي': 'https://mlazemna.com/tm25bi3/',
  },
  'الكيمياء': {
    'الوزاري': 'https://mlazemna.com/sa25km/',
    'التمهيدي': 'https://mlazemna.com/tm25km3/',
  },
  'الفيزياء': {
    'الوزاري': 'https://mlazemna.com/sa25ph/',
    'التمهيدي': 'https://mlazemna.com/tm25ph3/',
  },
};

class SubjectScreen extends StatefulWidget {
  final Subject subject;
  const SubjectScreen({super.key, required this.subject});
  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  String kind = 'الوزاري';
  String year = '2025';

  @override
  Widget build(BuildContext context) {
    final source = questionSources[widget.subject.name]?[kind];
    final available = year == '2025' && source != null;
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
              child: Row(
                children: [
                  Icon(widget.subject.icon,
                      color: widget.subject.color, size: 35),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('أرشيف ${widget.subject.name}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: navy)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text('نوع الامتحان',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['الوزاري', 'التمهيدي']
                  .map((v) => ChoiceChip(
                        label: Text(v),
                        selected: kind == v,
                        onSelected: (_) => setState(() => kind = v),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 18),
            const Text('السنة',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: year,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
              ),
              items: const [
                DropdownMenuItem(value: '2025', child: Text('2025')),
              ],
              onChanged: (v) => setState(() => year = v ?? '2025'),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18)),
              child: Column(
                children: [
                  Icon(
                    available ? Icons.menu_book_rounded : Icons.inventory_2_outlined,
                    size: 42,
                    color: widget.subject.color,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    available ? 'أسئلة سنة 2025 متوفرة' : 'هذه السنة قيد الإضافة',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: navy),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    available
                        ? 'اضغط لفتح صور ورقة الأسئلة والحلول المنشورة في المصدر. ستفتح الصفحة الأصلية حتى تبقى نسبة الأسئلة ومصدرها واضحين.'
                        : 'نعمل على إضافة أسئلة هذه السنة بعد التحقق من توفر نسخة موثوقة.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.blueGrey, height: 1.7),
                  ),
                  if (available) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(source),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('عرض صور الأسئلة والحلول'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text('المصدر: ملازمنا',
                      style: TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
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

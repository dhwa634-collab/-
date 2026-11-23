import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'academic_stages.dart';
import 'supabase_config.dart';

final _db = Supabase.instance.client;

class StudentCommunityScreen extends StatelessWidget {
  const StudentCommunityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final user = _db.auth.currentUser;
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('مجتمع الطلاب')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [Color(0xFF173D78), Color(0xFF2675E8)])),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.groups_rounded, color: Colors.white, size: 36),
            SizedBox(height: 12),
            Text('نتعاون حتى ننجح', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
            SizedBox(height: 6),
            Text('تواصل مع زملائك وشارك الفائدة ضمن بيئة دراسية آمنة.', style: TextStyle(color: Colors.white70)),
          ])),
        const SizedBox(height: 16),
        Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(user == null ? 'لم تسجل الدخول' : 'الملف الشخصي'),
          subtitle: Text(user?.email ?? 'التصفح متاح دون حساب'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentProfileScreen())))),
        Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.forum_rounded)),
          title: const Text('غرفة الدردشة العامة', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('رسائل نصية وملصقات دراسية مباشرة'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentChatScreen())))),
        if (user == null) ...[
          const SizedBox(height: 12),
          const Text('سجّل الدخول بحساب Google لإنشاء ملفك والمشاركة بالدردشة.', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const StudentGoogleLoginScreen())),
            icon: const Icon(Icons.login_rounded), label: const Text('تسجيل الدخول بواسطة Google')),
        ] else
          OutlinedButton.icon(onPressed: () async {
            await _db.auth.signOut();
            if (context.mounted) Navigator.pop(context);
          }, icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج')),
      ]),
    ));
  }
}

class StudentGoogleLoginScreen extends StatefulWidget {
  const StudentGoogleLoginScreen({super.key});
  @override
  State<StudentGoogleLoginScreen> createState() => _StudentGoogleLoginScreenState();
}
class _StudentGoogleLoginScreenState extends State<StudentGoogleLoginScreen> {
  bool busy = false;
  Future<void> signIn() async {
    if (SupabaseConfig.googleWebClientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('أكمل إعداد Google OAuth ثم أضف Web Client ID في supabase_config.dart.')));
      return;
    }
    setState(() => busy = true);
    try {
      final google = GoogleSignIn(serverClientId: SupabaseConfig.googleWebClientId);
      final account = await google.signIn();
      if (account == null) return;
      final tokens = await account.authentication;
      if (tokens.idToken == null || tokens.accessToken == null) {
        throw const AuthException('لم نستلم رموز Google المطلوبة.');
      }
      await _db.auth.signInWithIdToken(provider: OAuthProvider.google,
        idToken: tokens.idToken!, accessToken: tokens.accessToken!);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentProfileScreen()));
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تسجيل الدخول: ' + e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تعذر تسجيل الدخول. تحقق من إعداد Google OAuth والاتصال.')));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl,
    child: Scaffold(appBar: AppBar(title: const Text('تسجيل دخول الطلاب')),
      body: Center(child: Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircleAvatar(radius: 42, child: Icon(Icons.school_rounded, size: 42)),
          const SizedBox(height: 18),
          const Text('أهلاً بك في مجتمع الطلاب', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('استخدم حساب Google لحفظ ملفك والمشاركة في غرفة الدردشة.', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: busy ? null : signIn,
            icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.g_mobiledata_rounded, size: 28),
            label: Text(busy ? 'جارٍ تسجيل الدخول...' : 'المتابعة باستخدام Google'))),
        ])))));
}

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});
  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}
class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final name = TextEditingController();
  String age = '13_15', stage = AcademicStage.intermediateThird.label;
  String? gender;
  bool loading = true, saving = false;
  @override
  void initState() { super.initState(); loadProfile(); }
  Future<void> loadProfile() async {
    final user = _db.auth.currentUser;
    if (user == null) { if (mounted) setState(() => loading = false); return; }
    try {
      final row = await _db.from('profiles').select().eq('user_id', user.id).maybeSingle();
      if (row != null) {
        name.text = (row['display_name'] ?? '').toString();
        age = (row['age_band'] ?? '13_15').toString();
        stage = (row['stage'] ?? stage).toString();
        gender = row['gender']?.toString();
      } else {
        name.text = (user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? '').toString();
      }
    } catch (_) { toast('تعذر تحميل الملف الشخصي.'); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> saveProfile() async {
    final user = _db.auth.currentUser;
    final displayName = name.text.trim();
    if (user == null) { toast('سجّل الدخول أولاً.'); return; }
    if (displayName.isEmpty || displayName.length > 40) { toast('اكتب اسماً من 1 إلى 40 حرفاً.'); return; }
    setState(() => saving = true);
    try {
      await _db.from('profiles').upsert({
        'user_id': user.id, 'display_name': displayName, 'age_band': age,
        'gender': gender, 'stage': stage, 'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      toast('تم حفظ الملف الشخصي.');
    } catch (_) { toast('تعذر حفظ الملف. تحقق من الاتصال وحاول مجدداً.'); }
    finally { if (mounted) setState(() => saving = false); }
  }
  void toast(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
  @override
  void dispose() { name.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl,
    child: Scaffold(appBar: AppBar(title: const Text('الملف الشخصي')),
      body: loading ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.all(18), children: [
        const Center(child: CircleAvatar(radius: 38, child: Icon(Icons.person, size: 40))),
        const SizedBox(height: 18),
        TextField(controller: name, maxLength: 40, decoration: const InputDecoration(labelText: 'اسم الطالب')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: age, decoration: const InputDecoration(labelText: 'الفئة العمرية'),
          items: const [
            DropdownMenuItem(value: 'under_13', child: Text('أقل من 13 سنة')),
            DropdownMenuItem(value: '13_15', child: Text('13–15 سنة')),
            DropdownMenuItem(value: '16_17', child: Text('16–17 سنة')),
            DropdownMenuItem(value: '18_plus', child: Text('18 سنة فأكثر')),
          ], onChanged: (v) => setState(() => age = v ?? age)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: stage, decoration: const InputDecoration(labelText: 'المرحلة الدراسية'),
          items: AcademicStage.values.map((s) => DropdownMenuItem(value: s.label, child: Text(s.label))).toList(),
          onChanged: (v) => setState(() => stage = v ?? stage)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(value: gender, decoration: const InputDecoration(labelText: 'الجنس (اختياري)'),
          items: const [
            DropdownMenuItem<String?>(value: null, child: Text('عدم التحديد')),
            DropdownMenuItem<String?>(value: 'male', child: Text('ذكر')),
            DropdownMenuItem<String?>(value: 'female', child: Text('أنثى')),
          ], onChanged: (v) => setState(() => gender = v)),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: saving ? null : saveProfile, icon: const Icon(Icons.save_rounded),
          label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ البيانات')),
      ])));
}

class StudentChatScreen extends StatefulWidget {
  const StudentChatScreen({super.key});
  @override
  State<StudentChatScreen> createState() => _StudentChatScreenState();
}
class _StudentChatScreenState extends State<StudentChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  late final Stream<List<Map<String, dynamic>>> messages;
  bool sending = false;
  static const stickers = {'book': '📚', 'great': '👏', 'success': '🌟',
    'focus': '🎯', 'thanks': '💙', 'motivation': '💪'};
  @override
  void initState() {
    super.initState();
    messages = _db.from('chat_messages').stream(primaryKey: ['id']).order('created_at', ascending: true);
  }
  bool unsafe(String value) {
    final lower = value.toLowerCase();
    return RegExp(r'(?:\+?964|0)7[0-9٠-٩]{9}').hasMatch(lower) ||
      RegExp(r'[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}').hasMatch(lower) ||
      RegExp(r'(https?://|www\.)').hasMatch(lower) ||
      ['كس', 'قحبة', 'شرموطة', 'متخلف'].any(lower.contains);
  }
  Future<void> send({String? sticker}) async {
    final user = _db.auth.currentUser;
    if (user == null) { toast('سجّل الدخول بحساب Google للمشاركة.'); return; }
    final text = input.text.trim();
    if (sticker == null && text.isEmpty) return;
    if (sticker == null && (text.length > 500 || unsafe(text))) {
      toast('لم تُرسل الرسالة: تجنب الإساءة أو أرقام الهواتف أو البريد أو الروابط.'); return;
    }
    setState(() => sending = true);
    try {
      await _db.from('chat_messages').insert({
        'user_id': user.id, 'message_type': sticker == null ? 'text' : 'builtin_sticker',
        'body': sticker == null ? text : stickers[sticker], 'sticker_id': sticker,
      });
      input.clear();
      if (scroll.hasClients) await scroll.animateTo(scroll.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } on PostgrestException catch (e) {
      toast(e.message.contains('rate') || e.message.contains('duplicate')
        ? 'تم إيقاف الإرسال مؤقتاً لتجنب التكرار.' : 'تعذر إرسال الرسالة. تحقق من الاتصال أو الحساب.');
    } catch (_) { toast('تعذر إرسال الرسالة حالياً.'); }
    finally { if (mounted) setState(() => sending = false); }
  }
  Future<Map<String, Map<String, dynamic>>> getProfiles(List<Map<String, dynamic>> rows) async {
    final ids = rows.map((r) => r['user_id'].toString()).toSet().toList();
    if (ids.isEmpty) return {};
    try {
      final result = await _db.rpc('get_chat_profiles', params: {'user_ids': ids});
      return {for (final p in (result as List)) p['user_id'].toString(): Map<String, dynamic>.from(p)};
    } catch (_) { return {}; }
  }
  Future<void> report(Map<String, dynamic> row) async {
    final user = _db.auth.currentUser;
    if (user == null) { toast('سجّل الدخول أولاً حتى ترسل بلاغاً.'); return; }
    final reason = await showModalBottomSheet<String>(context: context,
      builder: (ctx) => Directionality(textDirection: TextDirection.rtl,
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('سبب الإبلاغ', style: TextStyle(fontWeight: FontWeight.bold))),
          for (final item in const {
            'abuse': 'إساءة أو ألفاظ غير لائقة', 'bullying': 'تنمر أو مضايقة',
            'inappropriate': 'محتوى غير مناسب', 'personal_info': 'معلومات شخصية',
            'spam': 'رسائل مزعجة', 'other': 'سبب آخر',
          }.entries)
            ListTile(title: Text(item.value), onTap: () => Navigator.pop(ctx, item.key)),
        ]))));
    if (reason == null) return;
    try {
      await _db.from('chat_reports').insert({'reporter_id': user.id, 'message_id': row['id'], 'reason': reason});
      toast('وصل بلاغك إلى فريق الإشراف. شكراً لك.');
    } catch (_) { toast('تعذر إرسال البلاغ أو سبق الإبلاغ عن الرسالة.'); }
  }
  void toast(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
  String timeOf(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    return date.hour.toString().padLeft(2, '0') + ':' + date.minute.toString().padLeft(2, '0');
  }
  @override
  void dispose() { input.dispose(); scroll.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl,
    child: Scaffold(appBar: AppBar(title: const Text('غرفة الدردشة')),
      body: Column(children: [
        Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(stream: messages,
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('تعذر تحميل المحادثة حالياً.'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final rows = snapshot.data!.where((r) => r['deleted_at'] == null && r['hidden_at'] == null).toList();
            if (rows.isEmpty) return const Center(child: Text('ابدأ المحادثة برسالة مفيدة 🌟'));
            return FutureBuilder<Map<String, Map<String, dynamic>>>(future: getProfiles(rows),
              builder: (context, profiles) => ListView.builder(controller: scroll,
                padding: const EdgeInsets.all(12), itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final mine = row['user_id'] == _db.auth.currentUser?.id;
                  final profile = profiles.data?[row['user_id'].toString()];
                  final name = mine ? 'أنت' : (profile?['display_name'] ?? 'طالب').toString();
                  final sticker = row['message_type'] == 'builtin_sticker';
                  return Align(alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
                    child: GestureDetector(onLongPress: mine ? null : () => report(row),
                      child: Container(constraints: const BoxConstraints(maxWidth: 310),
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                        decoration: BoxDecoration(
                          color: mine ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary)),
                          const SizedBox(height: 4),
                          Text((row['body'] ?? '').toString(), style: TextStyle(fontSize: sticker ? 30 : 15)),
                          const SizedBox(height: 3),
                          Text(timeOf(row['created_at']), style: TextStyle(fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ]))));
                }));
          })),
        if (_db.auth.currentUser == null)
          Padding(padding: const EdgeInsets.all(12),
            child: FilledButton(onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const StudentGoogleLoginScreen())),
              child: const Text('سجّل الدخول للمشاركة في الدردشة')))
        else
          SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Column(children: [
              SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal,
                children: stickers.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ActionChip(label: Text(e.value, style: const TextStyle(fontSize: 20)),
                    onPressed: sending ? null : () => send(sticker: e.key)),
                )).toList())),
              Row(children: [
                Expanded(child: TextField(controller: input, minLines: 1, maxLines: 4, maxLength: 500,
                  decoration: const InputDecoration(hintText: 'اكتب رسالة دراسية...', counterText: '',
                    border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: sending ? null : () => send(),
                  icon: sending ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded)),
              ]),
              const Text('اضغط مطولاً على رسالة للإبلاغ عنها.', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ]))),
      ])));
}

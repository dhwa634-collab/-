import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    if (user == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        name.text = prefs.getString('dalilak_guest_display_name_v1') ?? 'طالب';
        age = prefs.getString('dalilak_student_age_band_v1') ?? age;
        gender = prefs.getString('dalilak_student_gender_v1');
        final savedStage = prefs.getString('dalilak_student_stage_v1');
        stage = AcademicStage.values
          .firstWhere((s) => s.name == savedStage,
            orElse: () => AcademicStage.intermediateThird).label;
      } catch (_) {}
      if (mounted) setState(() => loading = false);
      return;
    }
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
    if (displayName.isEmpty || displayName.length > 40) { toast('اكتب اسماً من 1 إلى 40 حرفاً.'); return; }
    setState(() => saving = true);
    try {
      if (user == null) {
        final prefs = await SharedPreferences.getInstance();
        final selected = AcademicStage.values.firstWhere(
          (s) => s.label == stage,
          orElse: () => AcademicStage.intermediateThird,
        );
        await prefs.setString('dalilak_guest_display_name_v1', displayName);
        await prefs.setString('dalilak_student_age_band_v1', age);
        if (gender == null) {
          await prefs.remove('dalilak_student_gender_v1');
        } else {
          await prefs.setString('dalilak_student_gender_v1', gender!);
        }
        await prefs.setString('dalilak_student_stage_v1', selected.name);
        await AcademicStageController.select(selected);
        toast('تم حفظ الملف الشخصي على هذا الجهاز.');
        return;
      }
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
        DropdownButtonFormField<String>(initialValue: age, decoration: const InputDecoration(labelText: 'الفئة العمرية'),
          items: const [
            DropdownMenuItem(value: 'under_13', child: Text('أقل من 13 سنة')),
            DropdownMenuItem(value: '13_15', child: Text('13–15 سنة')),
            DropdownMenuItem(value: '16_17', child: Text('16–17 سنة')),
            DropdownMenuItem(value: '18_plus', child: Text('18 سنة فأكثر')),
          ], onChanged: (v) => setState(() => age = v ?? age)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: stage, decoration: const InputDecoration(labelText: 'المرحلة الدراسية'),
          items: AcademicStage.values.map((s) => DropdownMenuItem(value: s.label, child: Text(s.label))).toList(),
          onChanged: (v) => setState(() => stage = v ?? stage)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(initialValue: gender, decoration: const InputDecoration(labelText: 'الجنس (اختياري)'),
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
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<String> _blockedUserIds = {};
  bool _recording = false;
  DateTime? _recordStartedAt;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  String? _playingMessageId;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;
  static const stickers = {'book': '📚', 'great': '👏', 'success': '🌟',
    'focus': '🎯', 'thanks': '💙', 'motivation': '💪'};
  @override
  void initState() {
    super.initState();
    messages = _db.from('chat_messages').stream(primaryKey: ['id']).order('created_at', ascending: true);
    _loadBlockedUsers();
    _positionSub = _audioPlayer.onPositionChanged.listen((value) {
      if (mounted) setState(() => _audioPosition = value);
    });
    _durationSub = _audioPlayer.onDurationChanged.listen((value) {
      if (mounted) setState(() => _audioDuration = value);
    });
    _completeSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingMessageId = null);
    });
  }
  bool unsafe(String value) {
    final normalized = value.toLowerCase()
      .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي').replaceAll('ـ', '');
    final compact = normalized.replaceAll(RegExp(r'[\\s().-]'), '');
    final phone = RegExp(r'(?:\\+?964|00964|0)7[0-9٠-٩]{9}');
    final email = RegExp(r'[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}');
    final link = RegExp(r'(https?://|www\\.|t\\.me/|wa\\.me/)', caseSensitive: false);
    const blockedWords = [
      'قحبة', 'شرموطة', 'كس', 'كلب', 'حيوان', 'متخلف', 'منيوك',
      'خول', 'طيز', 'زاني', 'عرص', 'يلعن', 'fuck', 'shit', 'bitch',
    ];
    return phone.hasMatch(compact) || email.hasMatch(normalized) ||
      link.hasMatch(normalized) || blockedWords.any(normalized.contains);
  }

  Future<void> _loadBlockedUsers() async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    try {
      final rows = await _db.from('user_blocks').select('blocked_id')
        .eq('blocker_id', user.id);
      if (!mounted) return;
      setState(() => _blockedUserIds.addAll(
        (rows as List).map((row) => row['blocked_id'].toString())));
    } catch (_) {}
  }

  Future<void> _pickCustomSticker() async {
    final user = _db.auth.currentUser;
    if (user == null) { toast('سجّل الدخول أولاً.'); return; }
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512,
        imageQuality: 78, requestFullMetadata: false,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty || bytes.length > 512 * 1024) {
        toast('حجم الملصق يجب ألا يتجاوز 512 كيلوبايت.'); return;
      }
      final extension = image.name.split('.').last.toLowerCase();
      const allowed = ['png', 'jpg', 'jpeg', 'webp'];
      if (!allowed.contains(extension)) {
        toast('نوع الصورة غير مدعوم. استخدم PNG أو JPG أو WEBP.'); return;
      }
      final mime = extension == 'png' ? 'image/png'
        : extension == 'webp' ? 'image/webp' : 'image/jpeg';
      final path = '${user.id}/sticker_${DateTime.now().millisecondsSinceEpoch}.$extension';
      setState(() => sending = true);
      await _db.storage.from('chat-stickers').uploadBinary(
        path, bytes, fileOptions: FileOptions(contentType: mime, upsert: false),
      );
      await _db.from('chat_messages').insert({
        'user_id': user.id, 'message_type': 'custom_sticker',
        'body': 'ملصق خاص', 'storage_path': path,
      });
      toast('تم إرسال الملصق.');
    } catch (_) { toast('تعذر إضافة الملصق. تحقق من الاتصال والصلاحيات.'); }
    finally { if (mounted) setState(() => sending = false); }
  }

  Future<void> _startVoiceRecording() async {
    if (_recording || sending) return;
    try {
      if (!await _recorder.hasPermission()) {
        toast('اسمح للتطبيق باستخدام المايكروفون لتسجيل رسالة صوتية.'); return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/dalilak_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordStartedAt = DateTime.now();
        _recordSeconds = 0;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _recordStartedAt == null) return;
        setState(() => _recordSeconds = DateTime.now().difference(_recordStartedAt!).inSeconds);
        if (_recordSeconds >= 120) unawaited(_stopVoiceRecording(send: true));
      });
    } catch (_) { toast('تعذر بدء التسجيل. تحقق من إذن المايكروفون.'); }
  }

  Future<void> _stopVoiceRecording({required bool send}) async {
    _recordTimer?.cancel();
    final seconds = _recordSeconds;
    String? path;
    try { path = await _recorder.stop(); } catch (_) {}
    if (mounted) setState(() { _recording = false; _recordStartedAt = null; });
    if (path == null) return;
    if (!send) {
      try { await File(path).delete(); } catch (_) {}
      toast('تم إلغاء التسجيل.');
      return;
    }
    final user = _db.auth.currentUser;
    if (user == null || seconds < 1 || seconds > 120) {
      try { await File(path).delete(); } catch (_) {}
      toast('التسجيل يجب أن يكون بين ثانية واحدة ودقيقتين.'); return;
    }
    setState(() => sending = true);
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty || bytes.length > 3 * 1024 * 1024) {
        throw Exception('حجم التسجيل أكبر من الحد المسموح.');
      }
      final storagePath = '${user.id}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _db.storage.from('chat-voice').uploadBinary(
        storagePath, bytes,
        fileOptions: const FileOptions(contentType: 'audio/mp4', upsert: false),
      );
      await _db.from('chat_messages').insert({
        'user_id': user.id, 'message_type': 'voice',
        'body': 'رسالة صوتية', 'storage_path': storagePath,
      });
      toast('تم إرسال الرسالة الصوتية.');
    } catch (_) { toast('تعذر إرسال التسجيل. حاول مرة ثانية.'); }
    finally {
      try { await File(path).delete(); } catch (_) {}
      if (mounted) setState(() => sending = false);
    }
  }

  Future<String?> _signedMediaUrl(String bucket, String? path) async {
    if (path == null || path.isEmpty) return null;
    try { return await _db.storage.from(bucket).createSignedUrl(path, 3600); }
    catch (_) { return null; }
  }

  Future<void> _playVoice(Map<String, dynamic> row) async {
    final id = row['id'].toString();
    if (_playingMessageId == id) {
      await _audioPlayer.pause();
      if (mounted) setState(() => _playingMessageId = null);
      return;
    }
    final url = await _signedMediaUrl('chat-voice', row['storage_path']?.toString());
    if (url == null) { toast('تعذر فتح التسجيل الصوتي.'); return; }
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      if (mounted) setState(() {
        _playingMessageId = id;
        _audioPosition = Duration.zero;
        _audioDuration = Duration.zero;
      });
    } catch (_) { toast('تعذر تشغيل الرسالة الصوتية.'); }
  }

  Future<void> _blockUser(Map<String, dynamic> row) async {
    final current = _db.auth.currentUser;
    final blockedId = row['user_id']?.toString();
    if (current == null || blockedId == null || blockedId == current.id) return;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) =>
      AlertDialog(
        title: const Text('حظر هذا المستخدم؟'),
        content: const Text('لن تظهر لك رسائله بعد الآن على هذا الجهاز والحساب.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حظر')),
        ],
      ));
    if (confirm != true) return;
    try {
      await _db.from('user_blocks').insert({
        'blocker_id': current.id, 'blocked_id': blockedId,
      });
      if (mounted) setState(() => _blockedUserIds.add(blockedId));
      toast('تم حظر المستخدم.');
    } catch (_) { toast('تعذر حظر المستخدم حالياً.'); }
  }

  Future<void> _messageActions(Map<String, dynamic> row) async {
    final action = await showModalBottomSheet<String>(context: context,
      builder: (ctx) => Directionality(textDirection: TextDirection.rtl,
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.flag_outlined),
            title: const Text('الإبلاغ عن الرسالة'),
            onTap: () => Navigator.pop(ctx, 'report')),
          if (row['user_id'] != _db.auth.currentUser?.id)
            ListTile(leading: const Icon(Icons.block_outlined),
              title: const Text('حظر المستخدم'),
              onTap: () => Navigator.pop(ctx, 'block')),
        ]))));
    if (action == 'report') await report(row);
    if (action == 'block') await _blockUser(row);
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
  void dispose() {
    _recordTimer?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    unawaited(_recorder.dispose());
    unawaited(_audioPlayer.dispose());
    input.dispose();
    scroll.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl,
    child: Scaffold(appBar: AppBar(title: const Text('غرفة الدردشة')),
      body: Column(children: [
        Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(stream: messages,
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('تعذر تحميل المحادثة حالياً.'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final rows = snapshot.data!.where((r) => r['deleted_at'] == null && r['hidden_at'] == null && !_blockedUserIds.contains(r['user_id'].toString())).toList();
            if (rows.isEmpty) return const Center(child: Text('ابدأ المحادثة برسالة مفيدة 🌟'));
            return FutureBuilder<Map<String, Map<String, dynamic>>>(future: getProfiles(rows),
              builder: (context, profiles) => ListView.builder(controller: scroll,
                padding: const EdgeInsets.all(12), itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final mine = row['user_id'] == _db.auth.currentUser?.id;
                  final profile = profiles.data?[row['user_id'].toString()];
                  final name = mine ? 'أنت' : (profile?['display_name'] ?? 'طالب').toString();
                  final sticker = row['message_type'] == 'builtin_sticker' || row['message_type'] == 'custom_sticker';
                  return Align(alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
                    child: GestureDetector(onLongPress: () => _messageActions(row),
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
                          if (row['message_type'] == 'custom_sticker')
                            FutureBuilder<String?>(
                              future: _signedMediaUrl('chat-stickers', row['storage_path']?.toString()),
                              builder: (context, media) => media.data == null
                                ? const Text('ملصق خاص')
                                : Image.network(media.data!, width: 150, height: 150, fit: BoxFit.contain),
                            )
                          else if (row['message_type'] == 'voice')
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                onPressed: () => _playVoice(row),
                                icon: Icon(_playingMessageId == row['id'].toString()
                                  ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                              ),
                              SizedBox(width: 120, child: LinearProgressIndicator(
                                value: _playingMessageId == row['id'].toString() &&
                                  _audioDuration.inMilliseconds > 0
                                  ? (_audioPosition.inMilliseconds / _audioDuration.inMilliseconds).clamp(0.0, 1.0).toDouble()
                                  : 0,
                              )),
                            ])
                          else
                            Text(unsafe((row['body'] ?? '').toString()) ? 'تم إخفاء رسالة لمخالفتها إرشادات الأمان.' : (row['body'] ?? '').toString(),
                              style: TextStyle(fontSize: sticker ? 30 : 15)),
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
                IconButton(
                  tooltip: 'إضافة ملصق من الجهاز',
                  onPressed: sending || _recording ? null : _pickCustomSticker,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                ),
                Expanded(child: TextField(controller: input, minLines: 1, maxLines: 4, maxLength: 500,
                  decoration: const InputDecoration(hintText: 'اكتب رسالة دراسية...', counterText: '',
                    border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                if (_recording)
                  IconButton(
                    tooltip: 'إلغاء التسجيل',
                    onPressed: () => _stopVoiceRecording(send: false),
                    icon: const Icon(Icons.close_rounded),
                  )
                else
                  IconButton(
                    tooltip: 'تسجيل رسالة صوتية',
                    onPressed: sending ? null : _startVoiceRecording,
                    icon: const Icon(Icons.mic_none_rounded),
                  ),
                IconButton.filled(
                  onPressed: sending ? null : (_recording
                    ? () => _stopVoiceRecording(send: true) : () => send()),
                  icon: sending ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_recording ? Icons.stop_rounded : Icons.send_rounded)),
              ]),
              if (_recording)
                Text('جارٍ التسجيل • $_recordSeconds ثانية',
                  style: const TextStyle(fontSize: 11, color: Colors.red)),
              const Text('اضغط مطولاً على رسالة للإبلاغ أو حظر المستخدم.',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
            ]))),
      ])));
}

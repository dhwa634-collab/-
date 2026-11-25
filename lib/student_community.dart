// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'academic_stages.dart';
import 'supabase_config.dart';
import 'student_private_chat.dart';

final _db = Supabase.instance.client;

Future<void> signOutStudentSession() async {
  // Clear the Google account chooser state and the Supabase session locally.
  try {
    await GoogleSignIn().signOut();
  } catch (_) {}
  await _db.auth.signOut();
}

class StudentCommunityScreen extends StatelessWidget {
  const StudentCommunityScreen({super.key});

  Future<void> _openChat(BuildContext context) async {
    if (_db.auth.currentUser != null) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => const StudentChatScreen(),
      ));
      return;
    }
    final goToLogin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الدردشة للطلاب المسجلين'),
        content: const Text('حتى نحافظ على أمان الطلاب ونمنع الرسائل المجهولة، تحتاج تسجّل الدخول بحساب Google قبل دخول الغرفة الجماعية. تقدر تواصل تصفح الكتب والأدوات كضيف.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لاحقاً')),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.login_rounded),
            label: const Text('تسجيل الدخول')),
        ],
      ),
    );
    if (goToLogin == true && context.mounted) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => const StudentGoogleLoginScreen(),
      ));
    }
  }
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
        Center(
          child: FutureBuilder<Map<String, dynamic>?>(
            future: user == null
                ? Future<Map<String, dynamic>?>.value(null)
                : _db.from('profiles').select('avatar_url')
                    .eq('user_id', user.id).maybeSingle(),
            builder: (context, snapshot) {
              final url = (snapshot.data?['avatar_url'] ??
                  user?.userMetadata?['picture'])?.toString();
              return InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const StudentProfileScreen())),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 31,
                      backgroundImage: url != null && url.startsWith('http')
                          ? NetworkImage(url) : null,
                      child: url == null || !url.startsWith('http')
                          ? const Icon(Icons.person_outline, size: 32) : null,
                    ),
                    Positioned(
                      bottom: -2, right: -3,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2),
                        ),
                        child: const Icon(Icons.edit_rounded,
                          size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.forum_rounded)),
          title: const Text('غرفة الدردشة العامة', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('رسائل نصية وملصقات دراسية مباشرة'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _openChat(context))),
        if (user == null) ...[
          const SizedBox(height: 12),
          const Text('سجّل الدخول بحساب Google لإنشاء ملفك والمشاركة بالدردشة.', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const StudentGoogleLoginScreen())),
            icon: const Icon(Icons.login_rounded), label: const Text('تسجيل الدخول بواسطة Google')),
        ] else
          OutlinedButton.icon(onPressed: () async {
            await signOutStudentSession();
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
      // Android ID-token flow: serverClientId must be the Web OAuth client ID.
      // Do not pass the iOS client ID as clientId on Android.
      final google = GoogleSignIn(
        serverClientId: SupabaseConfig.googleWebClientId.trim(),
      );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تسجيل الدخول: ${e.message}')),
        );
      }
    } catch (error, stackTrace) {
      // Keep the native error code visible (for example ApiException: 10)
      // so Release OAuth/SHA-1 configuration problems can be diagnosed.
      debugPrint('Google sign-in failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        final detail = error.toString();
        final message = detail.length > 420 ? detail.substring(0, 420) : detail;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 12),
          content: Text('فشل تسجيل الدخول (${error.runtimeType}): $message'),
        ));
      }
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: const Color(0xFFF2F6FC),
      appBar: AppBar(
        title: const Text('تسجيل دخول الطلاب'),
        backgroundColor: const Color(0xFFF2F6FC),
        elevation: 0,
      ),
      body: Stack(children: [
        Positioned(
          top: 0, left: 0, right: 0, height: 230,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight, end: Alignment.bottomLeft,
                colors: [Color(0xFF163B70), Color(0xFF2868D7)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
            ),
          ),
        ),
        SafeArea(child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 10,
              shadowColor: const Color(0x33142D50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 82, height: 82,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2868D7), Color(0xFF163B70)],
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 20),
                  const Text('أهلاً بك في مجتمع الطلاب',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Color(0xFF142D50))),
                  const SizedBox(height: 10),
                  Text('سجّل الدخول بحساب Google حتى تحفظ ملفك الشخصي وتتواصل مع زملائك في غرفة الدردشة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.7, color: Colors.blueGrey.shade700)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F7FE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(children: [
                      Icon(Icons.verified_user_outlined, color: Color(0xFF2868D7)),
                      SizedBox(width: 10),
                      Expanded(child: Text('دخول آمن لحسابك مع الاحتفاظ ببياناتك الدراسية.',
                        style: TextStyle(fontSize: 12, height: 1.5))),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(width: double.infinity, height: 54,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2868D7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: busy ? null : signIn,
                      icon: busy
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.g_mobiledata_rounded, size: 30),
                      label: Text(busy ? 'جارٍ تسجيل الدخول...' : 'المتابعة باستخدام Google',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('لن نطلب منك كلمة مرور Google داخل التطبيق.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade500)),
                ]),
              ),
            ),
          ),
        ))),
      ]),
    ),
  );
}

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});
  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final name = TextEditingController();
  final bio = TextEditingController();
  String age = '13_15', stage = AcademicStage.intermediateThird.label;
  String? gender;
  String? avatarUrl;
  XFile? selectedAvatar;
  bool loading = true, saving = false, uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = _db.auth.currentUser;
    if (user == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        name.text = prefs.getString('dalilak_guest_display_name_v1') ?? 'طالب';
        bio.text = prefs.getString('dalilak_guest_bio_v1') ?? '';
        age = prefs.getString('dalilak_student_age_band_v1') ?? age;
        gender = prefs.getString('dalilak_student_gender_v1');
        final savedStage = prefs.getString('dalilak_student_stage_v1');
        stage = AcademicStage.values
            .firstWhere((s) => s.name == savedStage,
                orElse: () => AcademicStage.intermediateThird)
            .label;
      } catch (_) {}
      if (mounted) setState(() => loading = false);
      return;
    }

    try {
      final row = await _db.from('profiles')
          .select('display_name,age_band,gender,stage,avatar_url,bio')
          .eq('user_id', user.id)
          .maybeSingle();
      if (row != null) {
        name.text = (row['display_name'] ?? '').toString();
        bio.text = (row['bio'] ?? '').toString();
        avatarUrl = row['avatar_url']?.toString()
            ?? user.userMetadata?['picture']?.toString();
        age = (row['age_band'] ?? '13_15').toString();
        stage = (row['stage'] ?? stage).toString();
        gender = row['gender']?.toString();
      } else {
        name.text = (user.userMetadata?['full_name']
            ?? user.userMetadata?['name'] ?? 'طالب').toString();
        avatarUrl = user.userMetadata?['picture']?.toString();
        final prefs = await SharedPreferences.getInstance();
        age = prefs.getString('dalilak_student_age_band_v1') ?? age;
        gender = prefs.getString('dalilak_student_gender_v1');
        final savedStage = prefs.getString('dalilak_student_stage_v1');
        stage = AcademicStage.values
            .firstWhere((s) => s.name == savedStage,
                orElse: () => AcademicStage.intermediateThird)
            .label;
      }
    } on PostgrestException catch (e) {
      toast('تعذر تحميل الملف (رمز ${e.code ?? 'DB'}): ${e.message}');
    } catch (e) {
      toast('تعذر تحميل الملف: ${e.toString()}');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickAvatar() async {
    final user = _db.auth.currentUser;
    if (user == null) {
      toast('سجّل الدخول أولاً حتى تحفظ صورة الحساب.');
      return;
    }
    if (uploadingAvatar || saving) return;

    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 82,
        requestFullMetadata: false,
      );
      if (image == null) return;

      final extension = image.name.split('.').last.toLowerCase();
      const mimeTypes = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
      };
      final mime = mimeTypes[extension];
      if (mime == null) {
        toast('الصورة لازم تكون JPG أو PNG أو WEBP.');
        return;
      }
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
        toast('حجم الصورة يجب ألا يتجاوز 2 ميغابايت.');
        return;
      }

      setState(() => uploadingAvatar = true);
      final path = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';
      var uploaded = false;
      try {
        await _db.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );
        uploaded = true;
        final publicUrl = _db.storage.from('avatars').getPublicUrl(path);
        final displayName = name.text.trim().isEmpty
            ? (user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? 'طالب').toString()
            : name.text.trim();
        await _db.from('profiles').upsert({
          'user_id': user.id,
          'display_name': displayName,
          'age_band': age,
          'gender': gender,
          'stage': stage,
          'avatar_url': publicUrl,
          'bio': bio.text.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        if (!mounted) return;
        setState(() {
          avatarUrl = publicUrl;
          selectedAvatar = image;
          name.text = displayName;
        });
        toast('تم تحديث صورة الحساب.');
      } catch (_) {
        if (uploaded) {
          try { await _db.storage.from('avatars').remove([path]); } catch (_) {}
        }
        rethrow;
      }
    } on PostgrestException catch (e) {
      toast('فشل حفظ الصورة في الملف (رمز ${e.code ?? 'DB'}): ${e.message}');
    } on StorageException catch (e) {
      toast('فشل رفع الصورة (HTTP ${e.statusCode ?? 'Storage'}): ${e.message}');
    } catch (e) {
      toast('تعذر تغيير الصورة: ${e.toString()}');
    } finally {
      if (mounted) setState(() => uploadingAvatar = false);
    }
  }

  Future<void> saveProfile() async {
    final user = _db.auth.currentUser;
    final displayName = name.text.trim();
    final bioText = bio.text.trim();
    if (displayName.isEmpty || displayName.length > 40) {
      toast('اكتب اسماً من 1 إلى 40 حرفاً.');
      return;
    }
    if (bioText.length > 180) {
      toast('النبذة يجب ألا تتجاوز 180 حرفاً.');
      return;
    }

    setState(() => saving = true);
    try {
      if (user == null) {
        final prefs = await SharedPreferences.getInstance();
        final selected = AcademicStage.values.firstWhere(
          (s) => s.label == stage,
          orElse: () => AcademicStage.intermediateThird,
        );
        await prefs.setString('dalilak_guest_display_name_v1', displayName);
        await prefs.setString('dalilak_guest_bio_v1', bioText);
        await prefs.setString('dalilak_student_age_band_v1', age);
        if (gender == null) {
          await prefs.remove('dalilak_student_gender_v1');
        } else {
          await prefs.setString('dalilak_student_gender_v1', gender!);
        }
        await prefs.setString('dalilak_student_stage_v1', selected.name);
        await AcademicStageController.select(selected);
        toast('تم حفظ الملف الشخصي على هذا الجهاز.');
        if (mounted) Navigator.of(context).pop();
        return;
      }

      await _db.from('profiles').upsert({
        'user_id': user.id,
        'display_name': displayName,
        'age_band': age,
        'gender': gender,
        'stage': stage,
        'avatar_url': avatarUrl ?? user.userMetadata?['picture']?.toString(),
        'bio': bioText,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      toast('تم حفظ الملف الشخصي والنبذة.');
      if (mounted) Navigator.of(context).pop();
    } on PostgrestException catch (e) {
      toast('فشل حفظ الملف (رمز ${e.code ?? 'DB'}): ${e.message}');
    } catch (e) {
      toast('تعذر حفظ الملف: ${e.toString()}');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void toast(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value)),
      );
    }
  }

  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: selectedAvatar != null
                            ? FileImage(File(selectedAvatar!.path)) as ImageProvider<Object>
                            : avatarUrl != null && avatarUrl!.startsWith('http')
                                ? NetworkImage(avatarUrl!) as ImageProvider<Object>
                                : null,
                        child: selectedAvatar == null &&
                                (avatarUrl == null || !avatarUrl!.startsWith('http'))
                            ? const Icon(Icons.person, size: 48)
                            : null,
                      ),
                      Material(
                        color: Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'تغيير صورة الحساب',
                          onPressed: uploadingAvatar ? null : pickAvatar,
                          icon: uploadingAvatar
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.camera_alt_rounded,
                                  color: Colors.white, size: 19),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: name,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: 'اسم الطالب'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bio,
                  maxLength: 180,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'نبذة عنك (اختياري)',
                    hintText: 'اكتب نبذة دراسية قصيرة عنك',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: age,
                  decoration: const InputDecoration(labelText: 'الفئة العمرية'),
                  items: const [
                    DropdownMenuItem(value: 'under_13', child: Text('أقل من 13 سنة')),
                    DropdownMenuItem(value: '13_15', child: Text('13–15 سنة')),
                    DropdownMenuItem(value: '16_17', child: Text('16–17 سنة')),
                    DropdownMenuItem(value: '18_plus', child: Text('18 سنة فأكثر')),
                  ],
                  onChanged: (v) => setState(() => age = v ?? age),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: stage,
                  decoration: const InputDecoration(labelText: 'المرحلة الدراسية'),
                  items: AcademicStage.values
                      .map((s) => DropdownMenuItem(value: s.label, child: Text(s.label)))
                      .toList(),
                  onChanged: (v) => setState(() => stage = v ?? stage),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: gender,
                  decoration: const InputDecoration(labelText: 'الجنس (اختياري)'),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('عدم التحديد')),
                    DropdownMenuItem<String?>(value: 'male', child: Text('ذكر')),
                    DropdownMenuItem<String?>(value: 'female', child: Text('أنثى')),
                  ],
                  onChanged: (v) => setState(() => gender = v),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: saving || uploadingAvatar ? null : saveProfile,
                  icon: saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ البيانات'),
                ),
              ],
            ),
    ),
  );
}


class _ChatDoodlePainter extends CustomPainter {
  const _ChatDoodlePainter();

  static const _symbols = <String>[
    '▱', '⚛', '⌂', '✎', '☆', '÷', '＋', '♧', '▤', '☆',
    '✎', '☼', '＋', '☆', '▱', '⚛', '÷', '✎', '⌂', '☆',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7185A6).withValues(alpha: .17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const cellW = 178.0;
    const cellH = 205.0;
    for (var i = 0; i < _symbols.length; i++) {
      final col = i % 4;
      final row = i ~/ 4;
      final x = (col * cellW + (row.isOdd ? 48 : 0) + 18) % (size.width + 30);
      final y = row * cellH + 20;
      final symbol = _symbols[i];
      final painter = TextPainter(
        text: TextSpan(text: symbol, style: TextStyle(
          fontSize: symbol == '▱' || symbol == '⚛' ? 49 : 39,
          fontWeight: FontWeight.w300,
          color: const Color(0xFF7185A6).withValues(alpha: .19),
        )),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(((i % 5) - 2) * .09);
      painter.paint(canvas, Offset.zero);
      canvas.restore();
    }
    // Small chalk stars and mathematical marks fill the spaces between icons.
    for (var i = 0; i < 12; i++) {
      final x = (i * 83.0 + 37) % size.width;
      final y = (i * 137.0 + 91) % size.height;
      final path = Path();
      for (var p = 0; p < 10; p++) {
        final angle = -1.5708 + p * 3.14159 / 5;
        final radius = p.isEven ? 11.0 : 4.8;
        final point = Offset(x + radius * math.cos(angle), y + radius * math.sin(angle));
        if (p == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StudentChatScreen extends StatefulWidget {
  const StudentChatScreen({super.key});
  @override
  State<StudentChatScreen> createState() => _StudentChatScreenState();
}
class _StudentChatScreenState extends State<StudentChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  late Stream<List<Map<String, dynamic>>> messages;
  String _profileCacheKey = '';
  Future<Map<String, Map<String, dynamic>>>? _profilesFuture;
  bool sending = false;
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<String> _blockedUserIds = {};
  List<Map<String, dynamic>> _latestChatRows = [];
  bool _recording = false;
  DateTime? _recordStartedAt;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  int _lastMessageCount = 0;
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
    messages = _messageStream();
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
  Stream<List<Map<String, dynamic>>> _messageStream() =>
      _db.from('chat_messages').stream(primaryKey: ['id']).order('created_at', ascending: false);

  void _retryMessages() {
    setState(() => messages = _messageStream());
  }

  Future<void> _showMembers() async {
    final ids = _latestChatRows
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    if (ids.isEmpty) {
      toast('لا يوجد أعضاء ظاهرون حالياً.');
      return;
    }
    try {
      final result = await _db.rpc('get_chat_profiles_v2',
        params: {'user_ids': ids});
      final profiles = (result as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList()
        ..sort((a, b) => (a['display_name'] ?? '').toString()
            .compareTo((b['display_name'] ?? '').toString()));
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF101F31),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .72,
            child: Column(children: [
              const SizedBox(height: 12),
              Container(width: 42, height: 4,
                decoration: BoxDecoration(color: Colors.white30,
                  borderRadius: BorderRadius.circular(8))),
              const Padding(
                padding: EdgeInsets.all(18),
                child: Row(children: [
                  Icon(Icons.groups_rounded, color: Color(0xFF70B6F8)),
                  SizedBox(width: 10),
                  Text('أعضاء الدردشة',
                    style: TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w800)),
                ]),
              ),
              Expanded(child: profiles.isEmpty
                ? const Center(child: Text('لا توجد ملفات أعضاء متاحة.',
                    style: TextStyle(color: Colors.white70)))
                : ListView.separated(
                    itemCount: profiles.length,
                    separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Colors.white10),
                    itemBuilder: (_, index) {
                      final p = profiles[index];
                      final id = p['user_id'].toString();
                      final avatar = p['avatar_url']?.toString();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF203B59),
                          backgroundImage: avatar != null && avatar.startsWith('http')
                            ? NetworkImage(avatar) : null,
                          child: avatar == null || !avatar.startsWith('http')
                            ? const Icon(Icons.person_rounded, color: Colors.white70) : null),
                        title: Row(children: [
                          Flexible(child: Text((p['display_name'] ?? 'طالب').toString(),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700))),
                          if (p['badge'] != null &&
                              p['badge'].toString().trim().isNotEmpty) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.verified_rounded,
                              color: Color(0xFF55A9F5), size: 16),
                          ],
                        ]),
                        subtitle: Text((p['stage'] ?? 'طالب').toString(),
                          style: const TextStyle(color: Colors.white60, fontSize: 12)),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          if (id == _db.auth.currentUser?.id) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => const StudentProfileScreen()));
                          } else {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => StudentPublicProfileScreen(userId: id)));
                          }
                        },
                      );
                    },
                  )),
            ]),
          )),
        ),
      );
    } catch (_) {
      toast('تعذر تحميل قائمة الأعضاء. حاول مجدداً.');
    }
  }

  bool unsafe(String value) {
    final normalized = value.toLowerCase()
      .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي').replaceAll('ـ', '')
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u200B-\u200F]'), '');
    final compact = normalized.replaceAll(RegExp(r'[\s().-]'), '');
    final phone = RegExp(r'(?:\+?964|00964|0)7[0-9٠-٩]{9}');
    final email = RegExp(r'[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}');
    final link = RegExp(
      r'(https?://|www\.|t\.me/|wa\.me/|(?:[a-z0-9-]+\.)+(?:com|net|org|io|me|info|site|xyz|ly|co|app)(?:/|$))',
      caseSensitive: false,
    );
    final shortInsult = RegExp(r'(^|[\s،,.!?؛:()])كس($|[\s،,.!?؛:()])');
    const blockedWords = [
      'قحبة', 'شرموطة', 'متخلف', 'منيوك', 'خول', 'طيز',
      'زاني', 'عرص', 'يلعن', 'fuck', 'shit', 'bitch',
    ];
    return phone.hasMatch(compact) || email.hasMatch(normalized) ||
      link.hasMatch(normalized) || shortInsult.hasMatch(normalized) ||
      blockedWords.any(normalized.contains);
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

  Future<void> _pickAndSendImage() async {
    final user = _db.auth.currentUser;
    if (user == null) { toast('سجّل الدخول أولاً.'); return; }
    if (sending || _recording) return;
    String? uploadedPath;
    bool messageSaved = false;
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 4096,
        maxHeight: 4096,
        imageQuality: 100,
        requestFullMetadata: false,
      );
      if (image == null) return;
      final sourceLength = await File(image.path).length();
      if (sourceLength == 0 || sourceLength > 25 * 1024 * 1024) {
        toast('حجم الصورة الأصلية يجب ألا يتجاوز 25 ميغابايت.');
        return;
      }
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        image.path,
        minWidth: 1600,
        minHeight: 1600,
        quality: 82,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true,
      );
      if (compressedBytes == null || compressedBytes.isEmpty) {
        toast('تعذر تجهيز الصورة قبل الإرسال.');
        return;
      }
      if (compressedBytes.lengthInBytes > 5 * 1024 * 1024) {
        toast('الصورة بعد الضغط أكبر من 5 ميغابايت. اختر صورة أصغر.');
        return;
      }
      if (!mounted) return;
      setState(() => sending = true);
      uploadedPath = '${user.id}/image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _db.storage.from('chat-media').uploadBinary(
        uploadedPath,
        compressedBytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          cacheControl: '31536000',
          upsert: false,
        ),
      );
      await _db.from('chat_messages').insert({
        'user_id': user.id,
        'message_type': 'image',
        'body': null,
        'sticker_id': null,
        'storage_path': uploadedPath,
      });
      messageSaved = true;
      toast('تم إرسال الصورة.');
    } on StorageException catch (e) {
      toast('فشل رفع الصورة (HTTP ${e.statusCode ?? 'Storage'}): ${e.message}');
    } on PostgrestException catch (e) {
      toast('فشل حفظ الصورة في الدردشة (رمز ${e.code ?? 'DB'}): ${e.message}');
    } on AuthException catch (e) {
      toast('انتهت جلسة الدخول أثناء إرسال الصورة: ${e.message}');
    } on SocketException catch (e) {
      toast('تعذر الاتصال أثناء إرسال الصورة: ${e.message}');
    } catch (e) {
      toast('تعذر إرسال الصورة (${e.runtimeType}): ${e.toString()}');
    } finally {
      if (uploadedPath != null && !messageSaved) {
        try { await _db.storage.from('chat-media').remove([uploadedPath]); } catch (_) {}
      }
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _pickCustomSticker() async {
    final user = _db.auth.currentUser;
    if (user == null) { toast('سجّل الدخول أولاً.'); return; }
    String? uploadedPath;
    bool messageSaved = false;
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
      uploadedPath = '${user.id}/sticker_${DateTime.now().millisecondsSinceEpoch}.$extension';
      setState(() => sending = true);
      await _db.storage.from('chat-stickers').uploadBinary(
        uploadedPath, bytes, fileOptions: FileOptions(contentType: mime, upsert: false),
      );
      await _db.from('chat_messages').insert({
        'user_id': user.id, 'message_type': 'custom_sticker',
        'body': null, 'sticker_id': null, 'storage_path': uploadedPath,
      });
      messageSaved = true;
      toast('تم إرسال الملصق.');
    } on StorageException catch (e) {
      toast('فشل رفع الملصق (HTTP ${e.statusCode ?? 'Storage'}): ${e.message}');
    } on PostgrestException catch (e) {
      toast('فشل حفظ الملصق في الدردشة (رمز ${e.code ?? 'DB'}): ${e.message}');
    } on AuthException catch (e) {
      toast('انتهت جلسة الدخول أثناء إرسال الملصق: ${e.message}');
    } on SocketException catch (e) {
      toast('تعذر الاتصال أثناء إرسال الملصق: ${e.message}');
    } catch (e) {
      toast('تعذر إرسال الملصق (${e.runtimeType}): ${e.toString()}');
    }
    finally {
      if (uploadedPath != null && !messageSaved) {
        try { await _db.storage.from('chat-stickers').remove([uploadedPath]); } catch (_) {}
      }
      if (mounted) setState(() => sending = false);
    }
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
    } catch (e) { toast('تعذر بدء التسجيل: $e'); }
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
    String? uploadedPath;
    bool messageSaved = false;
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty || bytes.length > 3 * 1024 * 1024) {
        throw Exception('حجم التسجيل أكبر من الحد المسموح.');
      }
      uploadedPath = '${user.id}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _db.storage.from('chat-voice').uploadBinary(
        uploadedPath, bytes,
        fileOptions: const FileOptions(contentType: 'audio/mp4', upsert: false),
      );
      await _db.from('chat_messages').insert({
        'user_id': user.id, 'message_type': 'voice',
        'body': null, 'sticker_id': null, 'storage_path': uploadedPath,
      });
      messageSaved = true;
      toast('تم إرسال الرسالة الصوتية.');
    } on StorageException catch (e) {
      toast('فشل رفع التسجيل الصوتي (HTTP ${e.statusCode ?? 'Storage'}): ${e.message}');
    } on PostgrestException catch (e) {
      toast('فشل حفظ التسجيل في الدردشة (رمز ${e.code ?? 'DB'}): ${e.message}');
    } on AuthException catch (e) {
      toast('انتهت جلسة الدخول أثناء إرسال التسجيل: ${e.message}');
    } on SocketException catch (e) {
      toast('تعذر الاتصال أثناء إرسال التسجيل: ${e.message}');
    } catch (e) {
      toast('تعذر إرسال التسجيل (${e.runtimeType}): ${e.toString()}');
    }
    finally {
      if (uploadedPath != null && !messageSaved) {
        try { await _db.storage.from('chat-voice').remove([uploadedPath]); } catch (_) {}
      }
      try { await File(path).delete(); } catch (_) {}
      if (mounted) setState(() => sending = false);
    }
  }

  final Map<String, Future<String?>> _mediaUrlCache = {};

  Future<String?> _signedMediaUrl(String bucket, String? path) {
    if (path == null || path.isEmpty) return Future.value(null);
    final key = '$bucket/$path';
    return _mediaUrlCache.putIfAbsent(key, () async {
      try {
        return await _db.storage.from(bucket).createSignedUrl(path, 86400);
      } catch (_) {
        _mediaUrlCache.remove(key);
        return null;
      }
    });
  }

  Widget _mediaPlaceholder({
    double width = 224,
    double height = 190,
    bool failed = false,
    VoidCallback? onRetry,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: failed
          ? TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة تحميل الصورة'),
            )
          : const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
    );
  }

  Widget _buildChatMedia(String bucket, String path, {bool sticker = false}) {
    final cacheKey = '$bucket/$path';
    final width = sticker ? 156.0 : 224.0;
    final height = sticker ? 156.0 : 190.0;
    return FutureBuilder<String?>(
      future: _signedMediaUrl(bucket, path),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null) {
          return _mediaPlaceholder(
            width: width,
            height: height,
            failed: snapshot.connectionState == ConnectionState.done,
            onRetry: () => setState(() => _mediaUrlCache.remove(cacheKey)),
          );
        }
        return GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            barrierColor: Colors.black87,
            builder: (dialogContext) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton.filledTonal(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              fit: sticker ? BoxFit.contain : BoxFit.cover,
              memCacheWidth: sticker ? 420 : 672,
              maxWidthDiskCache: sticker ? 480 : 800,
              fadeInDuration: const Duration(milliseconds: 120),
              placeholder: (_, __) => _mediaPlaceholder(width: width, height: height),
              errorWidget: (_, __, ___) => _mediaPlaceholder(
                width: width,
                height: height,
                failed: true,
                onRetry: () => setState(() => _mediaUrlCache.remove(cacheKey)),
              ),
            ),
          ),
        );
      },
    );
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
      if (mounted) {
        setState(() {
        _playingMessageId = id;
        _audioPosition = Duration.zero;
        _audioDuration = Duration.zero;
        });
      }
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
            ListTile(leading: const Icon(Icons.person_off_outlined),
              title: const Text('الإبلاغ عن المستخدم'),
              onTap: () => Navigator.pop(ctx, 'report_user')),
          if (row['user_id'] != _db.auth.currentUser?.id)
            ListTile(leading: const Icon(Icons.block_outlined),
              title: const Text('حظر المستخدم'),
              onTap: () => Navigator.pop(ctx, 'block')),
        ]))));
    if (action == 'report') await report(row);
    if (action == 'report_user') await report(row, reportUser: true);
    if (action == 'block') await _blockUser(row);
  }

  Future<void> _showEmojiPicker() async {
    const emojis = ['😀','😃','😄','😁','😆','😅','😂','🤣','😊','😉','😍','🥰',
      '😘','😎','🤩','🥳','😭','😢','😡','👍','👎','👏','🙌','🙏','💪','❤️',
      '🧡','💛','💚','💙','💜','✨','🌟','🔥','🎉','📚','✏️','📝','🎯','🌹',
      '🤍','🖤','🥲','🙂','🙃','😇','🤝','👋'];
    await showModalBottomSheet<void>(
      context: context, backgroundColor: const Color(0xFF17232E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Directionality(textDirection: TextDirection.ltr,
        child: SafeArea(child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .43,
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 38, height: 4, decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(4))),
            Expanded(child: GridView.builder(
              padding: const EdgeInsets.all(14),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, mainAxisSpacing: 7, crossAxisSpacing: 7),
              itemCount: emojis.length,
              itemBuilder: (_, index) => InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  final value = input.value;
                  final start = value.selection.isValid ? value.selection.start : value.text.length;
                  final end = value.selection.isValid ? value.selection.end : value.text.length;
                  final text = value.text.replaceRange(start, end, emojis[index]);
                  input.value = TextEditingValue(text: text,
                    selection: TextSelection.collapsed(offset: start + emojis[index].length));
                  Navigator.pop(ctx);
                  if (mounted) setState(() {});
                },
                child: Center(child: Text(emojis[index], style: const TextStyle(fontSize: 25))),
              ),
            )),
            TextButton.icon(onPressed: () {
              Navigator.pop(ctx);
              _showStickerPicker();
            }, icon: const Icon(Icons.collections_rounded),
              label: const Text('فتح الملصقات')),
            const SizedBox(height: 5),
          ]),
        )),
      ),
    );
  }

  Future<void> _showStickerPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF17232E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            for (final entry in stickers.entries)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.pop(ctx);
                  if (!sending) send(sticker: entry.key);
                },
                child: Container(
                  width: 62, height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFF263746),
                    borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: Text(entry.value, style: const TextStyle(fontSize: 29)),
                ),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.pop(ctx);
                if (!sending && !_recording) _pickCustomSticker();
              },
              child: Container(
                width: 62, height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFF263746),
                  borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: const Icon(Icons.add_photo_alternate_outlined,
                  color: Colors.white70, size: 27),
              ),
            ),
          ]),
        )),
      ),
    );
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
      FocusManager.instance.primaryFocus?.unfocus();
      await _db.from('chat_messages').insert({
        'user_id': user.id, 'message_type': sticker == null ? 'text' : 'builtin_sticker',
        'body': sticker == null ? text : null, 'sticker_id': sticker,
      });
      input.clear();
      if (scroll.hasClients) {
        await scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    } on PostgrestException catch (e) {
      if (e.message.toLowerCase().contains('rate') ||
          e.message.toLowerCase().contains('duplicate')) {
        toast('تم إيقاف الإرسال مؤقتاً لتجنب التكرار.');
      } else {
        final detail = [
          if ((e.code ?? '').isNotEmpty) 'الرمز ${e.code}',
          e.message,
          if ((e.details ?? '').toString().isNotEmpty) e.details.toString(),
          if ((e.hint ?? '').toString().isNotEmpty) 'اقتراح الخادم: ${e.hint}',
        ].join(' — ');
        toast('فشل إرسال الرسالة: $detail');
      }
    } on AuthException catch (e) {
      toast('مشكلة بجلسة تسجيل الدخول: ${e.message}');
    } on SocketException catch (e) {
      toast('تعذر الاتصال بالإنترنت: ${e.message}');
    } on TimeoutException {
      toast('انتهت مهلة الاتصال أثناء إرسال الرسالة. حاول مجدداً.');
    } catch (e) {
      toast('فشل إرسال الرسالة (${e.runtimeType}): ${e.toString()}');
    }
    finally { if (mounted) setState(() => sending = false); }
  }
  Future<Map<String, Map<String, dynamic>>> getProfiles(List<Map<String, dynamic>> rows) async {
    final ids = rows.map((r) => r['user_id'].toString()).toSet().toList();
    if (ids.isEmpty) return {};
    try {
      final result = await _db.rpc('get_chat_profiles_v2', params: {'user_ids': ids});
      return {for (final p in (result as List)) p['user_id'].toString(): Map<String, dynamic>.from(p)};
    } catch (_) { return {}; }
  }
  Future<void> report(Map<String, dynamic> row, {bool reportUser = false}) async {
    final user = _db.auth.currentUser;
    if (user == null) { toast('سجّل الدخول أولاً حتى ترسل بلاغاً.'); return; }
    final reason = await showModalBottomSheet<String>(context: context,
      builder: (ctx) => Directionality(textDirection: TextDirection.rtl,
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(reportUser ? 'سبب الإبلاغ عن المستخدم' : 'سبب الإبلاغ عن الرسالة', style: const TextStyle(fontWeight: FontWeight.bold))),
          for (final item in const {
            'abuse': 'إساءة أو ألفاظ غير لائقة', 'bullying': 'تنمر أو مضايقة',
            'inappropriate': 'محتوى غير مناسب', 'personal_info': 'معلومات شخصية',
            'spam': 'رسائل مزعجة', 'other': 'سبب آخر',
          }.entries)
            ListTile(title: Text(item.value), onTap: () => Navigator.pop(ctx, item.key)),
        ]))));
    if (reason == null) return;
    try {
      await _db.from('chat_reports').insert({'reporter_id': user.id, 'message_id': row['id'], 'reason': reason, 'details': reportUser ? 'بلاغ على صاحب الرسالة' : null});
      toast('وصل بلاغك إلى فريق الإشراف. شكراً لك.');
    } catch (_) { toast('تعذر إرسال البلاغ أو سبق الإبلاغ عن الرسالة.'); }
  }
  void toast(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
  String timeOf(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
    child: Scaffold(
      backgroundColor: const Color(0xFF091426),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17232E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _showMembers,
              child: const CircleAvatar(
                radius: 19,
                backgroundColor: Color(0xFF0B1B2D),
                child: Icon(Icons.groups_rounded,
                  color: Color(0xFF70B6F8), size: 22),
              ),
            ),
          ),
        ],
        title: Row(children: [
          const Icon(Icons.lock_rounded, color: Color(0xFF55A9F5), size: 19),
          const SizedBox(width: 9),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الدردشة الجماعية', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800)),
              Text('مجتمع الطلاب', style: TextStyle(
                fontSize: 11, color: Colors.white54)),
            ],
          )),
        ]),
      ),
      body: Stack(fit: StackFit.expand, children: [
        const CustomPaint(painter: _ChatDoodlePainter()),
        Column(children: [
        Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(stream: messages,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded, size: 42),
                  const SizedBox(height: 10),
                  const Text('تعذر تحميل المحادثة. تحقق من الإنترنت وحاول مجدداً.'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: _retryMessages,
                    icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
                ]),
              ));
            }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final rows = snapshot.data!.where((r) => r['deleted_at'] == null &&
              r['hidden_at'] == null &&
              !_blockedUserIds.contains(r['user_id'].toString())).toList();
            _latestChatRows = rows;
            if (rows.length != _lastMessageCount) {
              final hadPreviousMessages = _lastMessageCount > 0;
              _lastMessageCount = rows.length;
              if (hadPreviousMessages) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (scroll.hasClients && scroll.offset <= 120) {
                    scroll.animateTo(0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut);
                  }
                });
              }
            }
            if (rows.isEmpty) return const Center(child: Text('ابدأ المحادثة برسالة مفيدة 🌟'));
            final profileIds = rows.map((r) => r['user_id'].toString()).toSet().toList()..sort();
            final nextProfileKey = profileIds.join('|');
            if (nextProfileKey != _profileCacheKey) {
              _profileCacheKey = nextProfileKey;
              _profilesFuture = getProfiles(rows);
            }
            return FutureBuilder<Map<String, Map<String, dynamic>>>(future: _profilesFuture,
              builder: (context, profiles) => ListView.builder(
                controller: scroll,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final mine = row['user_id'] == _db.auth.currentUser?.id;
                  final profile = profiles.data?[row['user_id'].toString()];
                  final currentUser = _db.auth.currentUser;
                  final name = (profile?['display_name'] ??
                    (mine ? (currentUser?.userMetadata?['full_name'] ??
                      currentUser?.userMetadata?['name'] ??
                      currentUser?.email?.split('@').first) : null) ??
                    'طالب').toString();
                  final type = row['message_type']?.toString() ?? 'text';
                  final sticker = type == 'builtin_sticker' || type == 'custom_sticker';
                  final mediaPath = row['storage_path']?.toString() ?? '';
                  final avatar = (profile?['avatar_url'] ??
                      (mine
                          ? (currentUser?.userMetadata ?? const <String, dynamic>{})['picture']
                          : null))
                      ?.toString();
                  final badge = profile?['badge']?.toString();

                  return Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onLongPress: () => _messageActions(row),
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: mine ? const Color(0xFF23486B) : const Color(0xFF203B59),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(15),
                            topRight: const Radius.circular(15),
                            bottomLeft: Radius.circular(mine ? 15 : 5),
                            bottomRight: Radius.circular(mine ? 5 : 15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () {
                                  final memberId = row['user_id'].toString();
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => memberId == _db.auth.currentUser?.id
                                        ? const StudentProfileScreen()
                                        : StudentPublicProfileScreen(userId: memberId),
                                  ));
                                },
                                child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFF0B1B2D),
                                    backgroundImage: avatar != null &&
                                            avatar.startsWith('http')
                                        ? NetworkImage(avatar) : null,
                                    child: avatar == null || !avatar.startsWith('http')
                                        ? const Icon(Icons.person, size: 13)
                                        : null,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF69A9F5),
                                      ),
                                    ),
                                  ),
                                  if (badge != null && badge.trim().isNotEmpty) ...[
                                    const SizedBox(width: 3),
                                    const Icon(Icons.verified_rounded,
                                      color: Color(0xFF55A9F5), size: 14),
                                  ],
                                ],
                              ),
                              ),
                            ),
                            if (type == 'image' || type == 'custom_sticker')
                              _buildChatMedia(
                                type == 'image' ? 'chat-media' : 'chat-stickers',
                                mediaPath,
                                sticker: type == 'custom_sticker',
                              )
                            else if (type == 'voice')
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _playVoice(row),
                                    icon: Icon(
                                      _playingMessageId == row['id'].toString()
                                          ? Icons.pause_circle_filled_rounded
                                          : Icons.play_circle_fill_rounded,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  SizedBox(
                                    width: 104,
                                    child: LinearProgressIndicator(
                                      value: _playingMessageId == row['id'].toString() &&
                                              _audioDuration.inMilliseconds > 0
                                          ? (_audioPosition.inMilliseconds /
                                                  _audioDuration.inMilliseconds)
                                              .clamp(0.0, 1.0)
                                              .toDouble()
                                          : 0,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                type == 'builtin_sticker'
                                    ? (stickers[row['sticker_id']?.toString()] ?? '🌟')
                                    : (unsafe((row['body'] ?? '').toString())
                                        ? 'تم إخفاء رسالة لمخالفتها إرشادات الأمان.'
                                        : (row['body'] ?? '').toString()),
                                style: TextStyle(fontSize: sticker ? 28 : 15, height: 1.4, color: Colors.white),
                              ),
                            const SizedBox(height: 2),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    timeOf(row['created_at']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1,
                                      color: Colors.white.withValues(alpha: 0.62),
                                    ),
                                  ),
                                  if (mine) ...[
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.done_rounded,
                                      size: 12,
                                      color: Colors.white.withValues(alpha: 0.62),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }));
          })),
        if (_db.auth.currentUser == null)
          Padding(padding: const EdgeInsets.all(12),
            child: FilledButton(onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const StudentGoogleLoginScreen())),
              child: const Text('سجّل الدخول للمشاركة في الدردشة')))
        else
          SafeArea(top: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_recording)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text('جارٍ التسجيل • $_recordSeconds ثانية',
                    style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                ),
              Container(
                constraints: const BoxConstraints(minHeight: 62),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x1A171717),
                  borderRadius: BorderRadius.circular(38),
                  border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
                  boxShadow: const [BoxShadow(
                    color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: Row(
                  textDirection: TextDirection.ltr,
                  children: [
                  SizedBox(
                    width: 54, height: 54,
                    child: IconButton(
                      tooltip: 'الملصقات',
                      onPressed: _showEmojiPicker,
                      icon: const Icon(Icons.emoji_emotions_outlined,
                        color: Colors.white70, size: 31),
                    ),
                  ),
                  Expanded(child: TextField(
                    controller: input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    onChanged: (_) { if (mounted) setState(() {}); },
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    cursorColor: const Color(0xFF6489F5),
                    decoration: const InputDecoration(
                      hintText: 'الرسالة',
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 15),
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  )),
                  IconButton(
                    tooltip: 'إرسال صورة',
                    onPressed: sending || _recording ? null : _pickAndSendImage,
                    icon: const Icon(Icons.attach_file_rounded,
                      color: Colors.white70, size: 29),
                  ),
                  Container(
                    width: 54, height: 54,
                    decoration: const BoxDecoration(
                      color: Color(0xFF5278EE), shape: BoxShape.circle),
                    child: IconButton(
                      tooltip: _recording ? 'إيقاف وإرسال التسجيل' :
                        (input.text.trim().isEmpty ? 'تسجيل رسالة صوتية' : 'إرسال'),
                      onPressed: sending ? null : (_recording
                        ? () => _stopVoiceRecording(send: true)
                        : () => input.text.trim().isEmpty ? _startVoiceRecording() : send()),
                      icon: sending
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                        : Icon(_recording ? Icons.stop_rounded :
                            (input.text.trim().isEmpty
                              ? Icons.mic_rounded : Icons.send_rounded),
                            color: Colors.white, size: 31),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 5),
              const Text('اضغط مطولاً على رسالة للإبلاغ أو حظر المستخدم.',
                style: TextStyle(fontSize: 10, color: Colors.white38)),
            ]))),
      ]),
      ]),
    ));
}

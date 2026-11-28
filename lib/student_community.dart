// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
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

const String _developerEmail = 'dhwa44430@gmail.com';

bool _isVerifiedDeveloper(User? user) =>
    user != null &&
    user.email?.trim().toLowerCase() == _developerEmail &&
    user.emailConfirmedAt != null;

class _DeveloperBadge extends StatelessWidget {
  final bool compact;
  final bool onPrimary;
  const _DeveloperBadge({this.compact = false, this.onPrimary = false});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF258BFF);
    return Tooltip(
      message: 'حساب المطوّر الرسمي',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 9,
          vertical: compact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF39A8FF), Color(0xFF1769E8), Color(0xFF0647B8)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: blue.withValues(alpha: onPrimary ? 0.42 : 0.24),
              blurRadius: compact ? 5 : 9,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified_rounded,
            size: compact ? 14 : 16, color: Colors.white),
          if (!compact) ...[
            const SizedBox(width: 4),
            const Text('المطوّر', style: TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900,
            )),
          ],
        ]),
      ),
    );
  }
}

final _db = Supabase.instance.client;

Future<void> signOutStudentSession() async {
  // Clear the Google account chooser state and the Supabase session locally.
  try {
    await GoogleSignIn().signOut();
  } catch (_) {}
  await _db.auth.signOut();
}

String _googleSignInFailureMessage(Object error, String detail) {
  final isNetworkError = error is PlatformException &&
          error.code == 'network_error' ||
      error.toString().toLowerCase().contains('network_error');
  if (isNetworkError) {
    return 'تعذر الاتصال بخدمات Google بسبب عدم توفر الإنترنت. '
        'تسجيل الدخول لأول مرة يحتاج إلى إنترنت. إذا سبق أن سجلت الدخول '
        'على هذا الجهاز، ارجع إلى التطبيق دون تسجيل الخروج لاستخدام جلستك '
        'المحفوظة والبيانات المحلية.';
  }
  return 'فشل تسجيل الدخول (${error.runtimeType}): $detail';
}

/// Runs the existing native Google ID-token flow without showing an intermediate login screen.
Future<bool> signInWithGoogleAccount(BuildContext context) async {
  if (SupabaseConfig.googleWebClientId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('إعداد Google OAuth غير مكتمل.'),
    ));
    return false;
  }
  try {
    final google = GoogleSignIn(
      serverClientId: SupabaseConfig.googleWebClientId.trim(),
    );
    final account = await google.signIn();
    if (account == null) return false;
    final tokens = await account.authentication;
    if (tokens.idToken == null || tokens.accessToken == null) {
      throw const AuthException('لم نستلم رموز Google المطلوبة.');
    }
    await _db.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: tokens.idToken!,
      accessToken: tokens.accessToken!,
    );
    return true;
  } on AuthException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تسجيل الدخول: ${e.message}')),
      );
    }
    return false;
  } catch (error, stackTrace) {
    debugPrint('Google sign-in failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    if (context.mounted) {
      final detail = error.toString();
      final message = detail.length > 420 ? detail.substring(0, 420) : detail;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 12),
        content: Text(_googleSignInFailureMessage(error, message)),
      ));
    }
    return false;
  }
}

/// Asks before ending the current account session.
Future<bool> confirmStudentSignOut(BuildContext context) async {
  final theme = Theme.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.logout_rounded),
      title: const Text('تسجيل الخروج'),
      content: const Text(
        'هل أنت متأكد من تسجيل الخروج من حسابك؟ بياناتك الدراسية محفوظة ولن تُحذف عند تسجيل الخروج.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('رفض'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('موافق'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  try {
    await signOutStudentSession();
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تعذر تسجيل الخروج: $error'),
      ));
    }
    return false;
  }
}

/// Opens the public room directly while preserving the existing Google sign-in gate.
Future<void> openStudentChat(BuildContext context) async {
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
      content: const Text('حتى نحافظ على أمان الطلاب ونمنع الرسائل المجهولة، تحتاج تسجّل الدخول بحساب Google قبل دخول الغرفة الجماعية.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('لاحقاً')),
        FilledButton.icon(onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.login_rounded),
          label: const Text('تسجيل الدخول')),
      ],
    ),
  );
  if (goToLogin != true || !context.mounted) return;
  final signedIn = await Navigator.push<bool>(context, MaterialPageRoute(
    builder: (_) => const StudentGoogleLoginScreen(returnToCaller: true),
  ));
  if (signedIn == true && context.mounted && _db.auth.currentUser != null) {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => const StudentChatScreen(),
    ));
  }
}

class StudentCommunityScreen extends StatelessWidget {
  const StudentCommunityScreen({super.key});

  Future<void> _openChat(BuildContext context) => openStudentChat(context);
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
            final signedOut = await confirmStudentSignOut(context);
            if (signedOut && context.mounted) Navigator.pop(context);
          }, icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج')),
      ]),
    ));
  }
}

class StudentGoogleLoginScreen extends StatefulWidget {
  final bool returnToCaller;
  const StudentGoogleLoginScreen({super.key, this.returnToCaller = false});
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
      if (widget.returnToCaller) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentProfileScreen()));
      }
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
          content: Text(_googleSignInFailureMessage(error, message)),
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
                    child: ClipRRect(borderRadius: BorderRadius.circular(25), child: SvgPicture.asset('assets/brand/app_icon.svg', fit: BoxFit.contain)),
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
  @override State<StudentProfileScreen> createState()=>_StudentProfileScreenState();
}
class _StudentProfileScreenState extends State<StudentProfileScreen>{
  final name=TextEditingController(),username=TextEditingController(),bio=TextEditingController(),age=TextEditingController();
  final ScrollController profileScroll=ScrollController();
  String stage=AcademicStage.intermediateThird.label,badge='طالب',usernameHint='';
  String? gender,avatarUrl; XFile? selectedAvatar; Timer? usernameTimer;
  bool loading=true,saving=false,uploading=false,checking=false,available=false;
  bool get developer=>_isVerifiedDeveloper(_db.auth.currentUser);
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    final user=_db.auth.currentUser;
    try{
      if(user==null){
        final p=await SharedPreferences.getInstance();
        name.text=p.getString('dalilak_guest_display_name_v1')??'طالب';
        bio.text=p.getString('dalilak_guest_bio_v1')??'';
        age.text=p.getString('dalilak_student_age_band_v1')??'';
        gender=p.getString('dalilak_student_gender_v1');
        final s=p.getString('dalilak_student_stage_v1');
        stage=AcademicStage.values.firstWhere((x)=>x.name==s,orElse:()=>AcademicStage.intermediateThird).label;
      }else{
        final r=await _db.from('profiles').select('display_name,username,bio,age,gender,stage,avatar_url,badge').eq('user_id',user.id).maybeSingle();
        if(r!=null){
          name.text=(r['display_name']??'').toString();username.text=(r['username']??'').toString();
          bio.text=(r['bio']??'').toString();age.text=r['age']?.toString()??'';
          gender=r['gender']?.toString();stage=(r['stage']??stage).toString();
          avatarUrl=r['avatar_url']?.toString();badge=(r['badge']??'طالب').toString();
          available=username.text.isNotEmpty;usernameHint=available?'المعرّف الحالي محفوظ':'';
        }else{name.text=(user.userMetadata?['full_name']??user.userMetadata?['name']??'طالب').toString();avatarUrl=user.userMetadata?['picture']?.toString();}
      }
    }catch(e){toast('تعذر تحميل الملف: $e');}
    finally{if(mounted)setState(()=>loading=false);}
  }
  void validateUsername(String value){
    usernameTimer?.cancel();final v=value.trim().replaceFirst(RegExp(r'^@'),'').toLowerCase();
    final valid=v=='1'?developer:RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(v);
    if(!valid){setState(() { checking=false; available=false; usernameHint=v=='1'?'@1 للمطوّر فقط':'3–20 خانة إنجليزية أو أرقام أو _'; });return;}
    setState(() { checking=true; usernameHint='جارٍ التحقق من التوفر...'; });
    usernameTimer=Timer(const Duration(milliseconds:350),()async{
      try{
        final ok=await _db.rpc('is_student_username_available_v1',params:{'p_username':v});
        if(!mounted||username.text.trim().replaceFirst(RegExp(r'^@'),'').toLowerCase()!=v)return;
        setState(() { checking=false; available=ok==true; usernameHint=ok==true?'المعرّف متاح':'المعرّف مستخدم أو غير مسموح'; });
      }catch(_){if(mounted)setState(() { checking=false; available=false; usernameHint='تعذر التحقق من المعرّف'; });}
    });
  }
  Future<void> pickAvatar()async{
    final user=_db.auth.currentUser;if(user==null){toast('سجّل الدخول أولاً.');return;}if(uploading||saving)return;
    try{
      final image=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:512,maxHeight:512,imageQuality:82,requestFullMetadata:false);
      if(image==null)return;final ext=image.name.split('.').last.toLowerCase();
      const types={'jpg':'image/jpeg','jpeg':'image/jpeg','png':'image/png','webp':'image/webp'};
      if(!types.containsKey(ext)){toast('اختر صورة JPG أو PNG أو WEBP.');return;}
      final bytes=await image.readAsBytes();if(bytes.isEmpty||bytes.length>2*1024*1024){toast('حجم الصورة يجب ألا يتجاوز 2 ميغابايت.');return;}
      setState(()=>uploading=true);
      final path='${user.id}/profile_${DateTime.now().microsecondsSinceEpoch}.$ext';
      await _db.storage.from('avatars').uploadBinary(path,bytes,fileOptions:FileOptions(contentType:types[ext],upsert:false));
      final url=_db.storage.from('avatars').getPublicUrl(path);
      await _db.from('profiles').update({'avatar_url':url,'updated_at':DateTime.now().toUtc().toIso8601String()}).eq('user_id',user.id);
      if(mounted)setState(() { avatarUrl=url; selectedAvatar=image; });toast('تم تحديث صورة الحساب.');
    }on StorageException catch(e){toast('تعذر رفع الصورة (HTTP ${e.statusCode??'Storage'}): ${e.message}');}
    catch(e){toast('تعذر تغيير الصورة: $e');}
    finally{if(mounted)setState(()=>uploading=false);}
  }
  Future<void> save()async{
    final user=_db.auth.currentUser;final n=name.text.trim(),b=bio.text.trim();
    final u=username.text.trim().replaceFirst(RegExp(r'^@'),'').toLowerCase();final a=int.tryParse(age.text.trim());
    if(n.isEmpty||n.length>40){toast('اكتب اسماً من 1 إلى 40 حرفاً.');return;}
    if(a==null||a<10||a>80){toast('اكتب عمرك الحقيقي بين 10 و80 سنة.');return;}
    if(b.length>180){toast('النبذة لا تتجاوز 180 حرفاً.');return;}
    if(user!=null){
      if(!(u=='1'?developer:RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(u))){toast('@1 للمطوّر فقط وباقي المعرّفات 3–20 خانة.');return;}
      setState(()=>checking=true);
      try{final ok=await _db.rpc('is_student_username_available_v1',params:{'p_username':u});if(ok!=true){toast('هذا المعرّف مستخدم أو غير مسموح.');return;}}
      catch(e){toast('تعذر التحقق من المعرّف: $e');return;}
      finally{if(mounted)setState(()=>checking=false);}
    }
    setState(()=>saving=true);
    try{
      final band=a<13?'under_13':a<=15?'13_15':a<=17?'16_17':'18_plus';
      if(user==null){
        final p=await SharedPreferences.getInstance();
        final s=AcademicStage.values.firstWhere((x)=>x.label==stage,orElse:()=>AcademicStage.intermediateThird);
        await p.setString('dalilak_guest_display_name_v1',n);await p.setString('dalilak_guest_bio_v1',b);
        await p.setString('dalilak_student_age_band_v1',a.toString());await p.setString('dalilak_student_stage_v1',s.name);
        if(gender==null){await p.remove('dalilak_student_gender_v1');}else{await p.setString('dalilak_student_gender_v1',gender!);}
        await AcademicStageController.select(s);
      }else{
        await _db.from('profiles').upsert({'user_id':user.id,'display_name':n,'username':u,'bio':b,'age':a,'age_band':band,'gender':gender,'stage':stage,'avatar_url':avatarUrl??user.userMetadata?['picture']?.toString(),'updated_at':DateTime.now().toUtc().toIso8601String()},onConflict:'user_id');
        final p=await SharedPreferences.getInstance();
        await p.setString('dalilak_student_display_name_v1',n);await p.setString('dalilak_student_username_v1',u);
        await p.setString('dalilak_student_age_band_v1',a.toString());await p.setString('dalilak_student_stage_label_v1',stage);
        await AcademicStageController.select(AcademicStage.values.firstWhere((x)=>x.label==stage,orElse:()=>AcademicStage.intermediateThird));
      }
      if(mounted)setState(() { available=true; usernameHint='تم حفظ المعرّف'; });toast('تم تحديث الملف الشخصي بنجاح.');
    }on PostgrestException catch(e){toast('فشل حفظ الملف (رمز ${e.code??'DB'}): ${e.message}');}
    catch(e){toast('تعذر حفظ الملف: $e');}
    finally{if(mounted)setState(()=>saving=false);}
  }
  void toast(String s){if(mounted)ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content:Text(s)));}
  Future<void> copyId()async{final v=username.text.trim().replaceFirst(RegExp(r'^@'),'');if(v.isEmpty){toast('لا يوجد معرّف لنسخه.');return;}await Clipboard.setData(ClipboardData(text:'@$v'));toast('تم نسخ المعرّف');}
  Widget panel(Widget child){final dark=Theme.of(context).brightness==Brightness.dark;return Card(elevation:0,color:dark?const Color(0xFF112B45):Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20),side:BorderSide(color:Theme.of(context).colorScheme.outlineVariant.withValues(alpha:.55))),child:Padding(padding:const EdgeInsets.all(16),child:child));}
  @override void dispose(){usernameTimer?.cancel();profileScroll.dispose();name.dispose();username.dispose();bio.dispose();age.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final parentTheme=Theme.of(context);
    final dark=parentTheme.brightness==Brightness.dark;
    final c=parentTheme.colorScheme;
    final avatar=selectedAvatar!=null?FileImage(File(selectedAvatar!.path)) as ImageProvider<Object>:avatarUrl!=null?NetworkImage(avatarUrl!) as ImageProvider<Object>:null;
    return Theme(data:parentTheme,child:Directionality(textDirection:TextDirection.rtl,child:Scaffold(backgroundColor:dark?const Color(0xFF071421):c.surface,appBar:AppBar(backgroundColor:dark?const Color(0xFF071421):c.surface,foregroundColor:c.onSurface,title:const Text('الملف الشخصي'),elevation:0),
      body:loading?const Center(child:CircularProgressIndicator()):ListView(controller:profileScroll,padding:const EdgeInsets.all(16),children:[
        Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(25),gradient:LinearGradient(colors:dark?const[Color(0xFF142C4B),Color(0xFF285080)]:const[Color(0xFF17427E),Color(0xFF347FE8)])),
          child:Column(children:[
            GestureDetector(
              onTap: avatar == null ? null : () => showDialog<void>(
                context: context,
                builder: (dialogContext) => Dialog(
                  backgroundColor: Colors.black,
                  insetPadding: const EdgeInsets.all(18),
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        minScale: 0.7,
                        maxScale: 4,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image(image: avatar, fit: BoxFit.contain),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: avatar,
                  child: avatar == null
                      ? const Icon(Icons.person, size: 48, color: Colors.white)
                      : null,
                ),
              ),
            ),
            const SizedBox(height:12),Row(mainAxisAlignment:MainAxisAlignment.center,children:[
              Flexible(child:Text(name.text.isEmpty?'الملف الشخصي':name.text,style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900))),
              if(developer)...[const SizedBox(width:6),const _DeveloperBadge(onPrimary:true)],
            ]),
            const SizedBox(height:10),Wrap(alignment:WrapAlignment.center,spacing:7,runSpacing:7,children:[
              if(username.text.isNotEmpty)ActionChip(avatar:const Icon(Icons.copy,size:14),label:Text('@${username.text.trim().replaceFirst(RegExp(r'^@'),'')}'),onPressed:copyId,backgroundColor:const Color(0xFF071421),labelStyle:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),
              _profileChip(context,Icons.school,stage),_profileChip(context,Icons.workspace_premium,badge),_profileChip(context,Icons.quiz,'نقاط البنك: —'),
            ]),
          ])),
        const SizedBox(height:14),
        Row(children:[
          Expanded(child:OutlinedButton.icon(onPressed:uploading?null:pickAvatar,icon:const Icon(Icons.camera_alt_rounded),label:const Text('تعيين صورة'),style:OutlinedButton.styleFrom(foregroundColor:const Color(0xFFFFD36A),side:const BorderSide(color:Color(0x55FFD36A)),padding:const EdgeInsets.symmetric(vertical:13)))),
          const SizedBox(width:7),
          Expanded(child:FilledButton.icon(onPressed:()=>profileScroll.animateTo(390,duration:const Duration(milliseconds:350),curve:Curves.easeOut),icon:const Icon(Icons.edit_rounded),label:const Text('تعديل البيانات'),style:FilledButton.styleFrom(backgroundColor:const Color(0xFF17436D),foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:13)))),
          IconButton(tooltip:'الإعدادات',onPressed:()=>showModalBottomSheet<void>(context:context,backgroundColor:const Color(0xFF10263D),shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:Padding(padding:const EdgeInsets.all(18),child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('إعدادات الحساب',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),ListTile(leading:const Icon(Icons.verified_user_outlined,color:Color(0xFF56B4F8)),title:const Text('حماية الحساب',style:TextStyle(color:Colors.white)),subtitle:Text(_db.auth.currentUser?.email??'التصفح كضيف',style:const TextStyle(color:Colors.white60)),trailing:const Icon(Icons.chevron_left,color:Colors.white70),onTap:(){Navigator.pop(ctx);showDialog<void>(context:context,builder:(dialogContext){final user=_db.auth.currentUser;final session=_db.auth.currentSession;final email=user?.email??'غير مرتبط';final google=user?.identities?.any((identity)=>identity.provider.toLowerCase()=='google')??(user?.appMetadata['provider']?.toString().toLowerCase()=='google');final confirmed=user?.emailConfirmedAt;return Directionality(textDirection:TextDirection.rtl,child:AlertDialog(title:const Text('حماية الحساب'),content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[_securityInfoRow('طريقة الدخول',google?'Google':'غير محددة عبر Google'),_securityInfoRow('البريد الإلكتروني',email),_securityInfoRow('تأكيد البريد',confirmed==null?'غير مؤكّد':'مؤكّد'),_securityInfoRow('تاريخ التوثيق',confirmed==null?'—':(DateTime.tryParse(confirmed)?.toLocal().toString().split('.').first??'غير متاح')),_securityInfoRow('حالة الجلسة',session==null?'لا توجد جلسة نشطة':'جلسة نشطة'),_securityInfoRow('انتهاء الجلسة',session?.expiresAt==null?'—':DateTime.fromMillisecondsSinceEpoch(session!.expiresAt!*1000).toLocal().toString().split('.').first)]),actions:[TextButton.icon(onPressed:email=='غير مرتبط'?null:()async{await Clipboard.setData(ClipboardData(text:email));if(dialogContext.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم نسخ البريد الإلكتروني.')));},icon:const Icon(Icons.copy),label:const Text('نسخ البريد')),FilledButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('إغلاق'))]));});}),ListTile(leading:const Icon(Icons.logout_rounded,color:Color(0xFFFF8A80)),title:const Text('تسجيل الخروج',style:TextStyle(color:Colors.white)),subtitle:const Text('إنهاء جلسة الحساب بأمان',style:TextStyle(color:Colors.white60)),trailing:const Icon(Icons.chevron_left,color:Colors.white70),onTap:()async{Navigator.pop(ctx);final signedOut=await confirmStudentSignOut(context);if(signedOut&&context.mounted)Navigator.of(context).popUntil((route)=>route.isFirst);}),ListTile(leading:const Icon(Icons.info_outline,color:Color(0xFF56B4F8)),title:const Text('حالة التوثيق',style:TextStyle(color:Colors.white)),subtitle:Text(developer?'حساب المطوّر موثّق':'حساب طالب',style:const TextStyle(color:Colors.white60)))]))))),icon:const Icon(Icons.settings_rounded,color:Color(0xFFFFD36A))),
        ]),
        const SizedBox(height:14),
        panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          _profileHeading(context,'المعلومات الأساسية',Icons.person_outline),const SizedBox(height:12),
          TextField(controller:name,maxLength:40,decoration:const InputDecoration(labelText:'الاسم الظاهر',prefixIcon:Icon(Icons.badge_outlined),border:OutlineInputBorder(),filled:true)),
          const SizedBox(height:9),
          TextField(controller:username,maxLength:20,onChanged:validateUsername,decoration:InputDecoration(labelText:'اسم المستخدم بالإنجليزية',prefixText:'@',hintText:'student_2026',prefixIcon:const Icon(Icons.alternate_email),border:const OutlineInputBorder(),filled:true,helperText:usernameHint.isEmpty?'3–20 خانة؛ @1 للمطوّر فقط':usernameHint,helperStyle:TextStyle(color:checking?c.onSurfaceVariant:available?Colors.green:c.error),suffixIcon:checking?const Padding(padding:EdgeInsets.all(12),child:SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))):Icon(available?Icons.check_circle:Icons.alternate_email,color:available?Colors.green:null))),
          const SizedBox(height:9),TextField(controller:bio,maxLength:180,maxLines:3,decoration:const InputDecoration(labelText:'النبذة الشخصية (اختياري)',prefixIcon:Icon(Icons.notes),border:OutlineInputBorder(),filled:true)),
        ])),
        const SizedBox(height:12),
        panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          _profileHeading(context,'المعلومات الدراسية',Icons.school_outlined),const SizedBox(height:12),
          TextField(controller:age,keyboardType:TextInputType.number,maxLength:2,decoration:const InputDecoration(labelText:'العمر الحقيقي',suffixText:'سنة',prefixIcon:Icon(Icons.cake_outlined),border:OutlineInputBorder(),filled:true)),
          const SizedBox(height:9),
          DropdownButtonFormField<String>(initialValue:AcademicStage.values.any((x)=>x.label==stage)?stage:AcademicStage.intermediateThird.label,decoration:const InputDecoration(labelText:'المرحلة الدراسية',prefixIcon:Icon(Icons.menu_book),border:OutlineInputBorder(),filled:true),items:AcademicStage.values.map((x)=>DropdownMenuItem(value:x.label,child:Text(x.label))).toList(),onChanged:(v)=>setState(()=>stage=v??stage)),
          const SizedBox(height:9),
          DropdownButtonFormField<String?>(initialValue:gender,decoration:const InputDecoration(labelText:'الجنس (اختياري)',prefixIcon:Icon(Icons.people_outline),border:OutlineInputBorder(),filled:true),items:const[DropdownMenuItem<String?>(value:null,child:Text('عدم التحديد')),DropdownMenuItem<String?>(value:'male',child:Text('ذكر')),DropdownMenuItem<String?>(value:'female',child:Text('أنثى'))],onChanged:(v)=>setState(()=>gender=v)),
        ])),
        const SizedBox(height:16),FilledButton.icon(onPressed:saving||uploading||checking?null:save,style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(53),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),icon:saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.save),label:Text(saving?'جارٍ الحفظ...':'حفظ التغييرات')),
      ]))));
  }
}
Widget _securityInfoRow(String label,String value)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:4,child:Text(label,style:const TextStyle(fontWeight:FontWeight.w700))),const SizedBox(width:8),Expanded(flex:6,child:SelectableText(value))]));
Widget _profileHeading(BuildContext c,String text,IconData icon)=>Row(children:[Icon(icon,color:Theme.of(c).colorScheme.primary),const SizedBox(width:8),Text(text,style:Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w900))]);
Widget _profileChip(BuildContext context,IconData icon,String label)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.14),borderRadius:BorderRadius.circular(18),border:Border.all(color:Colors.white.withValues(alpha:.18))),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:14,color:const Color(0xFFFFD36A)),const SizedBox(width:5),Text(label,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w700))]));

class StudentSearchScreen extends StatefulWidget{const StudentSearchScreen({super.key});@override State<StudentSearchScreen> createState()=>_StudentSearchScreenState();}
class _StudentSearchScreenState extends State<StudentSearchScreen>{
  final query=TextEditingController();Timer? timer;List<Map<String,dynamic>> rows=[];bool loading=false;String? error;
  @override void initState(){super.initState();load('');}
  Future<void> load(String q)async{
    if(_db.auth.currentUser==null){if(mounted)setState(()=>error='سجّل الدخول حتى تبحث عن الطلاب.');return;}
    if(mounted)setState(()=>loading=true);
    try{
      final r=await _db.rpc('search_student_profiles_v1',params:{'p_query':q.trim().isEmpty?null:q.trim(),'p_stage':AcademicStageController.current.value.label,'p_user_id':null,'p_limit':30});
      final data=(r as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
      if(mounted)setState((){rows=data;loading=false;error=null;});
    }catch(e){if(mounted)setState((){loading=false;error='تعذر البحث: $e';});}
  }
  void changed(String q){timer?.cancel();timer=Timer(const Duration(milliseconds:320),()=>load(q));}
  @override void dispose(){timer?.cancel();query.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final c=Theme.of(context).colorScheme;
    return Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('البحث عن الطلاب')),body:Column(children:[
      Padding(padding:const EdgeInsets.all(15),child:TextField(controller:query,onChanged:changed,decoration:InputDecoration(hintText:'ابحث بالاسم أو @username',prefixIcon:const Icon(Icons.search),suffixIcon:query.text.isEmpty?const Icon(Icons.people):IconButton(icon:const Icon(Icons.close),onPressed:(){query.clear();changed('');}),filled:true,fillColor:c.surfaceContainerHighest,border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide.none)))),
      if(query.text.isEmpty)const Padding(padding:EdgeInsets.only(bottom:10),child:Text('زملاء من مرحلتك وأحدث المنضمين')),
      Expanded(child:loading&&rows.isEmpty?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Text(error!)):rows.isEmpty?const Center(child:Text('لا توجد نتائج حالياً.')):ListView.separated(padding:const EdgeInsets.all(13),itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(ctx,i){
        final r=rows[i];final av=r['avatar_url']?.toString();
        return Card(elevation:0,color:c.surfaceContainerLow,child:ListTile(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>StudentPublicProfileScreen(userId:r['user_id'].toString()))),
          leading:CircleAvatar(backgroundImage:av!=null?NetworkImage(av):null,child:av==null?const Icon(Icons.person):null),
          title:Row(children:[Flexible(child:Text(r['display_name']?.toString()??'طالب',overflow:TextOverflow.ellipsis)),if(r['is_developer']==true)...[const SizedBox(width:5),const _DeveloperBadge(compact:true)]]),
          subtitle:Text('@${r['username']??'—'} • ${r['stage']??'طالب'}'),trailing:const Icon(Icons.chevron_left)));
      })),
    ])));
  }
}
class StudentPublicProfileScreen extends StatefulWidget{
  final String userId;
  final String? fallbackName, fallbackUsername, fallbackStage, fallbackAvatar, fallbackBadge, fallbackBio;
  final bool fallbackDeveloper;
  const StudentPublicProfileScreen({super.key,required this.userId,this.fallbackName,this.fallbackUsername,this.fallbackStage,this.fallbackAvatar,this.fallbackBadge,this.fallbackBio,this.fallbackDeveloper=false});
  @override State<StudentPublicProfileScreen> createState()=>_StudentPublicProfileScreenState();
}
class _StudentPublicProfileScreenState extends State<StudentPublicProfileScreen>{
  Map<String,dynamic>? p;bool loading=true,blockedByMe=false,blockedByThem=false,blockBusy=false;
  bool get blocked=>blockedByMe||blockedByThem;
  @override void initState(){super.initState();load();}
  Future<void> load()async{
    p={
      'user_id':widget.userId,
      'display_name':widget.fallbackName??'طالب',
      'username':widget.fallbackUsername,
      'stage':widget.fallbackStage??'طالب',
      'avatar_url':widget.fallbackAvatar,
      'badge':widget.fallbackBadge??'طالب',
      'bio':widget.fallbackBio,
      'is_developer':widget.fallbackDeveloper,
    };
    try{
      final r=await _db.rpc('search_student_profiles_v1',params:{'p_query':null,'p_stage':null,'p_user_id':widget.userId,'p_limit':1});
      final l=r as List;
      if(l.isNotEmpty)p={...p!,...Map<String,dynamic>.from(l.first as Map)};
      final me=_db.auth.currentUser?.id;var mine=false,theirs=false;
      if(me!=null&&me!=widget.userId){final rows=await _db.from('user_blocks').select('blocker_id,blocked_id').or('and(blocker_id.eq.$me,blocked_id.eq.${widget.userId}),and(blocker_id.eq.${widget.userId},blocked_id.eq.$me)');mine=(rows as List).any((x)=>x['blocker_id']==me&&x['blocked_id']==widget.userId);theirs=rows.any((x)=>x['blocker_id']==widget.userId&&x['blocked_id']==me);}
      if(mounted)setState(() {blockedByMe=mine;blockedByThem=theirs;loading=false;});
    }catch(_){if(mounted)setState(()=>loading=false);}
  }
  Future<void> toggleBlock()async{
    final me=_db.auth.currentUser?.id;if(me==null||me==widget.userId||blockBusy)return;final removing=blockedByMe;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(removing?'إلغاء الحظر؟':'حظر هذا الطالب؟'),content:Text(removing?'سيعود خيار المراسلة إذا لم يكن هناك حظر من الطرف الآخر.':'لن تتمكنوا من مراسلة بعضكما ما دام الحظر مفعّلاً.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(removing?'إلغاء الحظر':'حظر'))]));
    if(ok!=true)return;setState(() { blockBusy=true;blockedByMe=!removing; });
    try{if(removing){await _db.from('user_blocks').delete().eq('blocker_id',me).eq('blocked_id',widget.userId);}else{await _db.from('user_blocks').insert({'blocker_id':me,'blocked_id':widget.userId});}if(mounted)ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content:Text(removing?'تم إلغاء الحظر.':'تم حظر الطالب.')));}
    catch(e){if(mounted){setState(()=>blockedByMe=removing);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تحديث الحظر: $e')));}}
    finally{if(mounted)setState(()=>blockBusy=false);}
  }
  @override Widget build(BuildContext context){final av=p?['avatar_url']?.toString();final own=_db.auth.currentUser?.id==widget.userId;
    return Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('ملف الطالب')),body:loading?const Center(child:CircularProgressIndicator()):p==null?const Center(child:Text('الملف غير متاح.')):ListView(padding:const EdgeInsets.all(17),children:[
      Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(borderRadius:BorderRadius.circular(24),gradient:const LinearGradient(begin:Alignment.topRight,end:Alignment.bottomLeft,colors:[Color(0xFF071421),Color(0xFF17436D),Color(0xFF0B2339)])),child:Column(children:[CircleAvatar(radius:48,backgroundImage:av!=null?NetworkImage(av):null,child:av==null?const Icon(Icons.person,size:48,color:Colors.white):null),const SizedBox(height:12),Row(mainAxisAlignment:MainAxisAlignment.center,children:[Flexible(child:Text(p!['display_name']?.toString()??'طالب',style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900))),if(p!['is_developer']==true)...[const SizedBox(width:6),const _DeveloperBadge(onPrimary:true)]]),const SizedBox(height:6),Text('@${p!['username']??'—'}',style:const TextStyle(color:Colors.white)),const SizedBox(height:12),Wrap(spacing:7,children:[_profileChip(context,Icons.school,p!['stage']?.toString()??'طالب'),_profileChip(context,Icons.workspace_premium,p!['badge']?.toString()??'طالب'),_profileChip(context,Icons.quiz,'النقاط: —')]) ])),
      const SizedBox(height:13),Card(color:const Color(0xFF112B45),elevation:0,child:Padding(padding:const EdgeInsets.all(17),child:Text((p!['bio']?.toString().trim().isNotEmpty??false)?p!['bio'].toString():'لم يضف نبذة شخصية بعد.',style:const TextStyle(color:Colors.white,height:1.6)))),
      if(!own)...[if(blockedByThem)const Padding(padding:EdgeInsets.only(bottom:10),child:Text('هذا الطالب فعّل الحظر بينكما، لذلك المراسلة غير متاحة حالياً.',style:TextStyle(color:Color(0xFFFFC56B)))),Row(children:[Expanded(child:FilledButton.icon(onPressed:blocked||blockBusy?null:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>StudentDirectMessageScreen(otherUserId:widget.userId,otherName:p!['display_name']?.toString()??'طالب',otherAvatar:av))),icon:const Icon(Icons.chat_bubble_outline),label:const Text('مراسلة'))),const SizedBox(width:8),OutlinedButton.icon(onPressed:blockBusy?null:toggleBlock,icon:blockBusy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):Icon(blockedByMe?Icons.lock_open_rounded:Icons.block),label:Text(blockedByMe?'إلغاء الحظر':'حظر'))])],
    ])));
  }
}
class StudentPresenceService {
  StudentPresenceService._();
  static final SupabaseClient _client = Supabase.instance.client;
  static final ValueNotifier<Set<String>> onlineUserIds = ValueNotifier<Set<String>>(<String>{});
  static RealtimeChannel? _channel;
  static StreamSubscription? _authSubscription;
  static String? _trackedUserId;

  static Future<void> initialize() async {
    _authSubscription ??= _client.auth.onAuthStateChange.listen((event) {
      unawaited(_startTracking(event.session?.user.id));
    });
    await _startTracking(_client.auth.currentUser?.id);
  }

  static Future<void> _startTracking(String? userId) async {
    if (_trackedUserId == userId && _channel != null) return;
    final previous = _channel;
    _channel = null;
    _trackedUserId = userId;
    if (previous != null) await _client.removeChannel(previous);
    if (userId == null) {
      onlineUserIds.value = <String>{};
      return;
    }
    final channel = _client.channel('student-presence');
    _channel = channel;
    channel.onPresenceSync((_) => _refreshOnlineUsers());
    channel.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed &&
          identical(_channel, channel)) {
        await channel.track({
          'user_id': userId,
          'online_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    });
  }

  static void _refreshOnlineUsers() {
    final channel = _channel;
    if (channel == null) return;
    final users = <String>{};
    for (final state in channel.presenceState()) {
      for (final presence in state.presences) {
        final id = presence.payload['user_id']?.toString();
        if (id != null && id.isNotEmpty) users.add(id);
      }
    }
    onlineUserIds.value = users;
  }
}

class StudentDirectMessageScreen extends StatefulWidget{
  final String otherUserId,otherName;final String? otherAvatar;
  const StudentDirectMessageScreen({super.key,required this.otherUserId,required this.otherName,this.otherAvatar});
  @override State<StudentDirectMessageScreen> createState()=>_StudentDirectMessageScreenState();
}
class _StudentDirectMessageScreenState extends State<StudentDirectMessageScreen>{
  final Set<String> _selectedDmIds = {};
  final List<Map<String, dynamic>> _cachedMessages = [];
  Timer? _offlineSyncTimer;
  bool _dmCacheLoaded = false;
  bool _syncingDmOutbox = false;
  String get _dmCacheKey => 'dalilak_dm_cache_${me}_${widget.otherUserId}';
  String get _dmOutboxKey => 'dalilak_dm_outbox_${me}_${widget.otherUserId}';

  Future<void> _loadDmCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dmCacheKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _cachedMessages
            ..clear()
            ..addAll(decoded.whereType<Map>().map((row) => Map<String, dynamic>.from(row)));
        }
      } catch (error) {
        debugPrint('Read private message cache failed: $error');
      }
    }
    final queued = prefs.getString(_dmOutboxKey);
    if (queued != null) {
      try {
        final decoded = jsonDecode(queued);
        if (decoded is List) {
          for (final value in decoded.whereType<Map>()) {
            final row = Map<String, dynamic>.from(value);
            if (!_optimisticMessages.any((item) => item['id'] == row['id'])) {
              _optimisticMessages.add(row);
            }
          }
        }
      } catch (error) {
        debugPrint('Read private message outbox failed: $error');
      }
    }
    _dmCacheLoaded = true;
    if (mounted) setState(() {});
    _scrollToLatest();
  }

  Future<void> _saveDmCache(List<Map<String, dynamic>> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unique = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final id = row['id']?.toString();
        if (id != null) unique[id] = Map<String, dynamic>.from(row);
      }
      await prefs.setString(_dmCacheKey, jsonEncode(unique.values.toList()));
    } catch (error) {
      debugPrint('Save private message cache failed: $error');
    }
  }

  Future<void> _saveDmOutbox() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = _optimisticMessages
          .where((row) => row['_local_status'] == 'queued')
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      await prefs.setString(_dmOutboxKey, jsonEncode(pending));
    } catch (error) {
      debugPrint('Save private message outbox failed: $error');
    }
  }

  Future<void> _syncDmOutbox() async {
    final user = me;
    if (user == null || !mounted || sending || _syncingDmOutbox ||
        _optimisticMessages.isEmpty) {
      return;
    }
    _syncingDmOutbox = true;
    try {
    final pending = _optimisticMessages
        .where((row) => row['_local_status'] == 'queued')
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    for (final row in pending) {
      if (!mounted) return;
      try {
        final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.now().toUtc();
        final duplicate = await _db.from('direct_messages')
            .select('id,sender_id,receiver_id,body,created_at,read_at')
            .eq('sender_id', user)
            .eq('receiver_id', widget.otherUserId)
            .eq('body', row['body'].toString())
            .gte('created_at', createdAt.subtract(const Duration(minutes: 2)).toIso8601String())
            .limit(1);
        Map<String, dynamic> delivered;
        if ((duplicate as List).isNotEmpty) {
          delivered = Map<String, dynamic>.from(duplicate.first);
        } else {
          delivered = Map<String, dynamic>.from(await _db.from('direct_messages')
              .insert({
                'sender_id': user,
                'receiver_id': widget.otherUserId,
                'body': row['body'],
              }).select().single());
        }
        final index = _optimisticMessages.indexWhere((item) => item['id'] == row['id']);
        if (index != -1) {
          _stableMessageRenderIds[delivered['id'].toString()] = row['id'].toString();
          _optimisticMessages[index] = {
            ...delivered,
            '_local_status': 'sent',
            '_render_id': row['id'],
          };
        }
        _cachedMessages.removeWhere((item) => item['id'] == delivered['id']);
        _cachedMessages.add(delivered);
        await _saveDmCache(_cachedMessages);
        await _saveDmOutbox();
        if (mounted) setState(() {});
      } catch (error) {
        debugPrint('Retry private message failed; kept in outbox: $error');
        break;
      }
    }
    } finally {
      _syncingDmOutbox = false;
    }
  }
  String? _editingDmId, _editingDmOriginal;
  RealtimeChannel? _typingChannel;
  Timer? _typingIdleTimer, _typingExpiryTimer;
  bool _otherTyping = false;
  final Map<String,Map<String,dynamic>> _selectedDmRows = {};
  final Map<String,List<Map<String,dynamic>>> _dmReactions = {};
  late final StreamSubscription<List<Map<String,dynamic>>> _dmReactionSubscription;
  bool get _dmSelectionMode => _selectedDmIds.isNotEmpty;
  Widget _dmSelectionToolbar(ColorScheme colors) => Row(mainAxisSize:MainAxisSize.min,children:[IconButton(tooltip:'إلغاء التحديد',onPressed:()=>setState(()=>_selectedDmIds.clear()),icon:const Icon(Icons.close_rounded)),Text(_selectedDmIds.length.toString(),style:const TextStyle(fontWeight:FontWeight.w900)),IconButton(tooltip:'نسخ',onPressed:_copySelectedDm,icon:const Icon(Icons.copy_rounded)),IconButton(tooltip:'تعديل',onPressed:_canEditSelectedDm?_editSelectedDm:null,icon:const Icon(Icons.edit_rounded)),IconButton(tooltip:'حذف',onPressed:_deleteSelectedDm,icon:Icon(Icons.delete_outline_rounded,color:colors.error))]);
  bool get _canEditSelectedDm => _selectedDmIds.length==1 && _selectedDmRows[_selectedDmIds.first]?['sender_id']==me && !((_selectedDmRows[_selectedDmIds.first]?['body']?.toString()??'').startsWith('[['));

  final input=TextEditingController();
  final FocusNode inputFocus = FocusNode();
  final ImagePicker _dmImagePicker = ImagePicker();
  final AudioRecorder _dmRecorder = AudioRecorder();
  final AudioPlayer _dmAudioPlayer = AudioPlayer();
  bool _dmRecording = false;
  DateTime? _dmRecordingStarted;
  Timer? _dmRecordTimer;
  int _dmRecordSeconds = 0;
  String? _dmPlayingMessageId;
  final ScrollController _scrollController=ScrollController();
  late final Stream<List<Map<String,dynamic>>> messages; late final StreamSubscription<List<Map<String,dynamic>>> blockSubscription;
  bool sending=false,blocked=false; String? get me=>_db.auth.currentUser?.id;
  late final StreamSubscription<List<Map<String,dynamic>>> messageSubscription; late String _resolvedOtherName;
  final Map<String,String> _participantNames={};
  bool _otherOnline = false;
  void _presenceChanged() {
    final next = StudentPresenceService.onlineUserIds.value.contains(widget.otherUserId);
    if (mounted && next != _otherOnline) setState(() => _otherOnline = next);
  }
  @override void initState(){super.initState();_resolvedOtherName=widget.otherName;_otherOnline=StudentPresenceService.onlineUserIds.value.contains(widget.otherUserId);StudentPresenceService.onlineUserIds.addListener(_presenceChanged);_loadOtherProfileName();_loadParticipantNames();activeDirectMessageUserId.value=widget.otherUserId;messages=stream();_initTypingChannel();messageSubscription=messages.listen((rows) {
      _cachedMessages
        ..clear()
        ..addAll(rows.map((row) => Map<String, dynamic>.from(row)));
      unawaited(_saveDmCache(_cachedMessages));
      markIncomingAsRead();
      _scrollToLatest();
    }, onError: (Object error) {
      debugPrint('Private messages stream offline; using local cache: $error');
    });
    unawaited(_loadDmCache());
    _offlineSyncTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_syncDmOutbox());
    });_dmReactionSubscription=_db.from('direct_message_reactions').stream(primaryKey:['id']).listen((rows){if(!mounted)return;final grouped=<String,List<Map<String,dynamic>>>{};for(final r in rows){final id=r['direct_message_id']?.toString();if(id!=null)grouped.putIfAbsent(id,()=>[]).add(r);}setState(()=>_dmReactions..clear()..addAll(grouped));});blockSubscription=_db.from('user_blocks').stream(primaryKey:['blocker_id','blocked_id']).listen((rows){final user=me;final next=user==null||rows.any((r)=>(r['blocker_id']==user&&r['blocked_id']==widget.otherUserId)||(r['blocker_id']==widget.otherUserId&&r['blocked_id']==user));if(mounted&&blocked!=next)setState(()=>blocked=next);});refreshBlockStatus();markIncomingAsRead();}
  void _initTypingChannel() {
    final ids = [me ?? '', widget.otherUserId]..sort();
    _typingChannel = _db.channel('dm-typing-${ids.join('-')}');
    _typingChannel!.onBroadcast(event: 'typing', callback: (payload) {
      if (!mounted || payload['user_id']?.toString() != widget.otherUserId) return;
      final typing = payload['typing'] == true;
      _typingExpiryTimer?.cancel();
      if (typing) {
        _typingExpiryTimer = Timer(const Duration(milliseconds: 2200), () {
          if (mounted) setState(() => _otherTyping = false);
        });
      }
      if (_otherTyping != typing) setState(() => _otherTyping = typing);
    }).subscribe();
  }
  void _notifyTyping(String value) {
    final user = me, channel = _typingChannel;
    if (user == null || channel == null) return;
    _typingIdleTimer?.cancel();
    unawaited(channel.sendBroadcastMessage(event: 'typing',
      payload: {'user_id': user, 'typing': value.trim().isNotEmpty}));
    if (value.trim().isNotEmpty) {
      _typingIdleTimer = Timer(const Duration(milliseconds: 1400), () {
        final current = _typingChannel;
        if (current != null) {
          unawaited(current.sendBroadcastMessage(event: 'typing',
            payload: {'user_id': user, 'typing': false}));
        }
      });
    }
  }
  void _beginDmEdit(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    if (id == null || row['sender_id'] != me || (row['body']?.toString() ?? '').startsWith('[[')) return;
    final value = row['body']?.toString() ?? '';
    setState(() {
      _editingDmId = id; _editingDmOriginal = value;
      _selectedDmIds.clear(); _selectedDmRows.clear();
      input.value = TextEditingValue(text: value,
        selection: TextSelection.collapsed(offset: value.length));
    });
    inputFocus.requestFocus();
  }
  void _cancelDmEdit() {
    setState(() { _editingDmId = null; _editingDmOriginal = null; input.clear(); });
    inputFocus.unfocus();
  }

  Future<void> _loadOtherProfileName() async {
    try {
      final rows = await _db.rpc('get_student_public_profile_v1', params: {'p_user_id': widget.otherUserId});
      final profile = (rows as List).isEmpty ? null : rows.first;
      final displayName = profile?['display_name']?.toString().trim() ?? '';
      final username = profile?['username']?.toString().trim() ?? '';
      final resolved = displayName.isNotEmpty ? displayName : (username.isNotEmpty ? '@$username' : widget.otherName);
      if (mounted && resolved.isNotEmpty && resolved != _resolvedOtherName) setState(() => _resolvedOtherName = resolved);
      _participantNames[widget.otherUserId] = resolved;
    } catch (error) { debugPrint('Load private chat participant profile failed: $error'); }
  }
  Future<void> _loadParticipantNames() async {
    final user = _db.auth.currentUser; if (user == null) return;
    try {
      final own = await _db.from('profiles').select('display_name').eq('user_id', user.id).maybeSingle();
      final meta = user.userMetadata ?? const <String,dynamic>{};
      final value = own?['display_name']?.toString().trim() ?? '';
      _participantNames[user.id] = value.isNotEmpty ? value : (meta['full_name'] ?? meta['name'] ?? 'حسابي').toString();
      if (mounted) setState(() {});
    } catch (error) { debugPrint('Load own private chat name failed: $error'); }
  }
  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }
  Stream<List<Map<String,dynamic>>> stream()=>_db.from('direct_messages').stream(primaryKey:['id']).order('created_at',ascending:true).map((items){final seen=<String>{};return items.where((r)=>((r['sender_id']==me&&r['receiver_id']==widget.otherUserId)||(r['sender_id']==widget.otherUserId&&r['receiver_id']==me))&&seen.add(r['id'].toString())).toList();});
  Future<bool> refreshBlockStatus()async{final user=me;if(user==null)return true;try{final rows=await _db.from('user_blocks').select('blocker_id,blocked_id').or('and(blocker_id.eq.$user,blocked_id.eq.${widget.otherUserId}),and(blocker_id.eq.${widget.otherUserId},blocked_id.eq.$user)');final value=(rows as List).isNotEmpty;if(mounted)setState(()=>blocked=value);return value;}catch(_){return blocked;}}
  Future<void> markIncomingAsRead()async{final user=me;if(user==null)return;try{await _db.rpc('mark_direct_messages_read',params:{'p_sender_id':widget.otherUserId});}catch(error){debugPrint('Mark private messages read failed: $error');}}
  void _toggleDmSelection(Map<String,dynamic> row){final id=row['id']?.toString();if(id==null||id.startsWith('local-'))return;setState((){if(_selectedDmIds.remove(id)){_selectedDmRows.remove(id);}else{_selectedDmIds.add(id);_selectedDmRows[id]=Map<String,dynamic>.from(row);}});}
  Future<void> _copySelectedDm() async {final text=_selectedDmIds.map((id)=>(_selectedDmRows[id]?['body']??'').toString()).where((v)=>v.trim().isNotEmpty&&!v.startsWith('[[')).join('\n');if(text.isEmpty)return;await Clipboard.setData(ClipboardData(text:text));if(mounted){setState(()=>_selectedDmIds.clear());_selectedDmRows.clear();ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم نسخ الرسائل المحددة.')));}}
  Future<void> _deleteSelectedDm() async {final ids=_selectedDmIds.where((id)=>_selectedDmRows[id]?['sender_id']==me).toList();if(ids.isEmpty){setState(()=>_selectedDmIds.clear());_selectedDmRows.clear();return;}final ok=await showDialog<bool>(context:context,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(title:const Text('حذف الرسائل المحددة؟'),content:Text('سيتم حذف ${ids.length} رسالة.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حذف'))])));if(ok!=true)return;setState(()=>_deletingMessageIds.addAll(ids));await Future<void>.delayed(const Duration(milliseconds:360));try{await _db.from('direct_messages').delete().inFilter('id',ids).eq('sender_id',me!);if(!mounted)return;setState(()=>_selectedDmIds.clear());_selectedDmRows.clear();ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم حذف الرسائل المحددة.')));}catch(e){if(mounted){setState(()=>_deletingMessageIds.removeAll(ids));ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر حذف الرسائل: $e')));}}}
  Future<void> _editSelectedDm() async {if(!_canEditSelectedDm)return;_beginDmEdit(_selectedDmRows[_selectedDmIds.first]!);}
  Future<void> _showDmReactionPicker(Map<String,dynamic> row) async {final id=row['id']?.toString(),user=me;if(id==null||user==null||id.startsWith('local-'))return;final emoji=await showModalBottomSheet<String>(context:context,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:Padding(padding:const EdgeInsets.all(18),child:Wrap(alignment:WrapAlignment.center,spacing:12,children:['❤️','👍','😂','🔥','💙','👏','🌟','🥰'].map((e)=>InkWell(onTap:()=>Navigator.pop(ctx,e),child:Padding(padding:const EdgeInsets.all(8),child:Text(e,style:const TextStyle(fontSize:30))))).toList())))));if(emoji==null||!mounted)return;try{final old=await _db.from('direct_message_reactions').select('id,emoji').eq('direct_message_id',id).eq('user_id',user).maybeSingle();if(old?['emoji']==emoji){await _db.from('direct_message_reactions').delete().eq('id',old!['id']).eq('user_id',user);}else{await _db.from('direct_message_reactions').upsert({'direct_message_id':id,'user_id':user,'emoji':emoji},onConflict:'direct_message_id,user_id');}}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تسجيل التفاعل: $e')));}}
  Widget _buildDmReactions(String id,ColorScheme colors){final list=_dmReactions[id]??const [];if(list.isEmpty)return const SizedBox.shrink();final counts=<String,int>{};final mine=<String>{};for(final r in list){final e=r['emoji']?.toString()??'';if(e.isEmpty)continue;counts[e]=(counts[e]??0)+1;if(r['user_id']==me)mine.add(e);}return Padding(padding:const EdgeInsets.only(top:5),child:Wrap(spacing:5,children:counts.entries.map((e)=>InkWell(onTap:()async{final user=me;if(user==null)return;try{final old=await _db.from('direct_message_reactions').select('id,emoji').eq('direct_message_id',id).eq('user_id',user).maybeSingle();if(old?['emoji']==e.key){await _db.from('direct_message_reactions').delete().eq('id',old!['id']).eq('user_id',user);}else{await _db.from('direct_message_reactions').upsert({'direct_message_id':id,'user_id':user,'emoji':e.key},onConflict:'direct_message_id,user_id');}}catch(err){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر تحديث التفاعل: $err')));}},child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),decoration:BoxDecoration(color:mine.contains(e.key)?colors.primaryContainer:colors.surfaceContainerHighest,borderRadius:BorderRadius.circular(15)),child:Text('${e.key} ${e.value}',style:TextStyle(color:colors.onSurface,fontSize:12))))).toList()));}
  Future<void> _privateMessageActions(Map<String,dynamic> row) async {
    if (row['sender_id'] != me) return;
    final action = await showModalBottomSheet<String>(context: context, builder: (ctx) =>
      Directionality(textDirection: TextDirection.rtl, child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('تعديل الرسالة'), onTap: () => Navigator.pop(ctx, 'edit')),
        ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('حذف الرسالة'), onTap: () => Navigator.pop(ctx, 'delete')),
      ]))));
    if (!mounted) return;
    if (action == 'edit') {
      _beginDmEdit(row);
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl,
        child: AlertDialog(title: const Text('حذف الرسالة؟'), content: const Text('سيتم حذفها من المحادثة لدى الطرفين.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))])));
      if (ok == true) {
        final id = row['id'].toString();
        if (mounted) setState(() => _deletingMessageIds.add(id));
        await Future<void>.delayed(const Duration(milliseconds: 300));
        try { await _db.from('direct_messages').delete().eq('id', id).eq('sender_id', me!); }
        catch (e) { if (mounted) { setState(() => _deletingMessageIds.remove(id)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف الرسالة: $e'))); } }
      }
    }
  }
  final List<Map<String, dynamic>> _optimisticMessages = [];
  final Map<String, String> _stableMessageRenderIds = {};
  final Set<String> _deletingMessageIds = {};

  List<Map<String, dynamic>> _mergeOptimisticMessages(
    List<Map<String, dynamic>> remote,
  ) {
    final merged = <String, Map<String, dynamic>>{
      for (final row in remote)
        row['id'].toString(): {
          ...row,
          if (_stableMessageRenderIds.containsKey(row['id'].toString()))
            '_render_id': _stableMessageRenderIds[row['id'].toString()],
        },
    };
    final matchedLocalIds = <String>{};
    final matchedRemoteIds = <String>{};
    for (final row in _optimisticMessages) {
      final id = row['id'].toString();
      if (merged.containsKey(id)) continue;
      final localTime = DateTime.tryParse(row['created_at']?.toString() ?? '');
      Map<String, dynamic>? match;
      var bestDelta = 31;
      for (final candidate in remote) {
        final remoteId = candidate['id'].toString();
        if (matchedRemoteIds.contains(remoteId) ||
            candidate['sender_id'] != row['sender_id'] ||
            candidate['receiver_id'] != row['receiver_id'] ||
            candidate['body'] != row['body']) {
          continue;
        }
        final serverTime = DateTime.tryParse(candidate['created_at']?.toString() ?? '');
        if (localTime == null || serverTime == null) continue;
        final delta = serverTime.difference(localTime).inSeconds.abs();
        if (delta <= 30 && delta < bestDelta) {
          bestDelta = delta;
          match = candidate;
        }
      }
      if (match != null) {
        final remoteId = match['id'].toString();
        matchedLocalIds.add(id);
        matchedRemoteIds.add(remoteId);
        _stableMessageRenderIds[remoteId] = id;
        merged[remoteId] = {...match, '_render_id': id};
      } else {
        merged[id] = row;
      }
    }
    final result = merged.values.toList()
      ..sort((a, b) => (a['created_at'] ?? '').toString()
          .compareTo((b['created_at'] ?? '').toString()));
    final remoteIds = remote.map((row) => row['id'].toString()).toSet();
    if (remoteIds.isNotEmpty || matchedLocalIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final before = _optimisticMessages.length;
        _optimisticMessages.removeWhere((row) => remoteIds.contains(row['id'].toString()) || matchedLocalIds.contains(row['id'].toString()));
        if (before != _optimisticMessages.length) setState(() {});
      });
    }
    return result;
  }

  Future<void> _openEmojiPicker() async {
    inputFocus.unfocus();
    final emoji = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PrivateEmojiPicker(
        dark: Theme.of(context).brightness == Brightness.dark,
      ),
    );
    if (!mounted || emoji == null) return;
    final oldValue = input.value;
    final selection = oldValue.selection;
    final start = selection.isValid ? selection.start : oldValue.text.length;
    final end = selection.isValid ? selection.end : oldValue.text.length;
    final updated = oldValue.text.replaceRange(start, end, emoji);
    input.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    inputFocus.requestFocus();
  }

  Future<void> _pickAndSendDirectImage() async {
    final user = _db.auth.currentUser;
    if (user == null || blocked || sending || _dmRecording) return;
    String? uploadedPath;
    var saved = false;
    try {
      final image = await _dmImagePicker.pickImage(source: ImageSource.gallery,
        maxWidth: 4096, maxHeight: 4096, imageQuality: 100, requestFullMetadata: false);
      if (image == null) return;
      final length = await File(image.path).length();
      if (length == 0 || length > 25 * 1024 * 1024) throw Exception('حجم الصورة الأصلية يجب ألا يتجاوز 25 ميغابايت.');
      final bytes = await FlutterImageCompress.compressWithFile(image.path,
        minWidth: 1600, minHeight: 1600, quality: 82,
        format: CompressFormat.jpeg, autoCorrectionAngle: true);
      if (bytes == null || bytes.isEmpty || bytes.lengthInBytes > 5 * 1024 * 1024) throw Exception('تعذر تجهيز الصورة أو تجاوزت 5 ميغابايت.');
      if (mounted) setState(() => sending = true);
      uploadedPath = '${user.id}/dm_image_${DateTime.now().microsecondsSinceEpoch}.jpg';
      await _db.storage.from('chat-media').uploadBinary(uploadedPath, bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
      await _db.from('direct_messages').insert({'sender_id': user.id,
        'receiver_id': widget.otherUserId, 'body': '[[DM_IMAGE:$uploadedPath]]'});
      saved = true;
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الصورة: $error')));
    } finally {
      if (uploadedPath != null && !saved) {
        try { await _db.storage.from('chat-media').remove([uploadedPath]); } catch (_) {}
      }
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _startDirectVoiceRecording() async {
    if (_dmRecording || sending || blocked) return;
    try {
      if (!await _dmRecorder.hasPermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اسمح للتطبيق باستخدام المايكروفون لتسجيل رسالة صوتية.')));
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/dalilak_dm_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _dmRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100), path: path);
      if (!mounted) return;
      setState(() { _dmRecording = true; _dmRecordingStarted = DateTime.now(); _dmRecordSeconds = 0; });
      _dmRecordTimer?.cancel();
      _dmRecordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _dmRecordingStarted == null) return;
        setState(() => _dmRecordSeconds = DateTime.now().difference(_dmRecordingStarted!).inSeconds);
        if (_dmRecordSeconds >= 120) unawaited(_stopDirectVoiceRecording(send: true));
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر بدء التسجيل: $error')));
    }
  }

  Future<void> _stopDirectVoiceRecording({required bool send}) async {
    _dmRecordTimer?.cancel();
    final seconds = _dmRecordSeconds;
    String? path;
    try { path = await _dmRecorder.stop(); } catch (_) {}
    if (mounted) setState(() { _dmRecording = false; _dmRecordingStarted = null; });
    if (path == null) return;
    if (!send) { try { await File(path).delete(); } catch (_) {} return; }
    final user = _db.auth.currentUser;
    if (user == null || seconds < 1 || seconds > 120 || blocked) {
      try { await File(path).delete(); } catch (_) {}
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('التسجيل يجب أن يكون بين ثانية واحدة ودقيقتين.')));
      return;
    }
    String? uploadedPath;
    var saved = false;
    if (mounted) setState(() => sending = true);
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty || bytes.length > 3 * 1024 * 1024) throw Exception('حجم التسجيل أكبر من الحد المسموح.');
      uploadedPath = '${user.id}/dm_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _db.storage.from('chat-voice').uploadBinary(uploadedPath, bytes,
        fileOptions: const FileOptions(contentType: 'audio/mp4', upsert: false));
      await _db.from('direct_messages').insert({'sender_id': user.id,
        'receiver_id': widget.otherUserId, 'body': '[[DM_VOICE:$uploadedPath]]'});
      saved = true;
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال التسجيل: $error')));
    } finally {
      if (uploadedPath != null && !saved) {
        try { await _db.storage.from('chat-voice').remove([uploadedPath]); } catch (_) {}
      }
      try { await File(path).delete(); } catch (_) {}
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _playDirectVoice(String id, String path) async {
    if (_dmPlayingMessageId == id) {
      await _dmAudioPlayer.pause();
      if (mounted) setState(() => _dmPlayingMessageId = null);
      return;
    }
    try {
      final url = await _db.storage.from('chat-voice').createSignedUrl(path, 86400);
      await _dmAudioPlayer.stop();
      await _dmAudioPlayer.play(UrlSource(url));
      if (mounted) setState(() => _dmPlayingMessageId = id);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تشغيل التسجيل: $error')));
    }
  }

  Widget _buildDirectMedia(String body, String id, Color foreground) {
    if (body.startsWith('[[DM_IMAGE:') && body.endsWith(']]')) {
      final path = body.substring('[[DM_IMAGE:'.length, body.length - 2);
      return FutureBuilder<String>(
        future: _db.storage.from('chat-media').createSignedUrl(path, 86400),
        builder: (context, snapshot) => snapshot.hasData
          ? GestureDetector(
              onTap: () => showDialog<void>(context: context, builder: (_) => Dialog(
                backgroundColor: Colors.black,
                child: InteractiveViewer(child: CachedNetworkImage(imageUrl: snapshot.data!, fit: BoxFit.contain)),
              )),
              child: ClipRRect(borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(imageUrl: snapshot.data!, width: 220, height: 180, fit: BoxFit.cover)),
            )
          : const SizedBox(width: 220, height: 150,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (body.startsWith('[[DM_VOICE:') && body.endsWith(']]')) {
      final path = body.substring('[[DM_VOICE:'.length, body.length - 2);
      return Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          onPressed: () => _playDirectVoice(id, path),
          icon: Icon(_dmPlayingMessageId == id
            ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
            color: foreground, size: 30),
        ),
        Text('رسالة صوتية', style: TextStyle(color: foreground)),
      ]);
    }
    return Text(body, style: TextStyle(color: foreground));
  }

  Future<void> send() async {
    final value = input.text.trim();
    final user = me;
    if (value.isEmpty || user == null || sending) return;
    if (_editingDmId != null) {
      if (value == _editingDmOriginal) { _cancelDmEdit(); return; }
      setState(() => sending = true);
      try {
        await _db.from('direct_messages').update({'body': value,
          'edited_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', _editingDmId!).eq('sender_id', user);
        if (!mounted) return;
        setState(() { _editingDmId = null; _editingDmOriginal = null; });
        input.clear(); inputFocus.unfocus();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعديل الرسالة.')));
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تعديل الرسالة دون اتصال. جرّب عند عودة الإنترنت.')),
          );
        }
      } finally { if (mounted) setState(() => sending = false); }
      return;
    }
    if (value.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرسالة طويلة جداً.')),
      );
      return;
    }
    if (blocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن إرسال الرسائل بسبب وجود حظر بين الحسابين.')),
      );
      return;
    }

    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = <String, dynamic>{
      'id': localId,
      'sender_id': user,
      'receiver_id': widget.otherUserId,
      'body': value,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'read_at': null,
      'edited_at': null,
      '_local_status': 'queued',
    };
    input.clear();
    setState(() {
      sending = true;
      _optimisticMessages.add(optimistic);
    });
    await _saveDmOutbox();
    _scrollToLatest();

    try {
      if (await refreshBlockStatus()) {
        _optimisticMessages.removeWhere((row) => row['id'] == localId);
        await _saveDmOutbox();
        if (mounted) {
          setState(() {});
          input.value = TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يمكن إرسال الرسائل بسبب وجود حظر بين الحسابين.')),
          );
        }
        return;
      }
      final inserted = await _db.from('direct_messages').insert({
        'sender_id': user,
        'receiver_id': widget.otherUserId,
        'body': value,
      }).select().single();
      final index = _optimisticMessages.indexWhere((row) => row['id'] == localId);
      if (index != -1) {
        _stableMessageRenderIds[inserted['id'].toString()] = localId;
        _optimisticMessages[index] = Map<String, dynamic>.from(inserted)
          ..['_local_status'] = 'sent'
          ..['_render_id'] = localId;
      }
      _cachedMessages.add(Map<String, dynamic>.from(inserted));
      await _saveDmCache(_cachedMessages);
      await _saveDmOutbox();
      if (mounted) {
        setState(() {});
        _scrollToLatest();
      }
    } catch (error) {
      final index = _optimisticMessages.indexWhere((row) => row['id'] == localId);
      if (index != -1) {
        _optimisticMessages[index]['_local_status'] = 'queued';
      }
      await _saveDmOutbox();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حُفظت الرسالة على جهازك وستُرسل تلقائياً عند عودة الإنترنت.')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
  @override void dispose(){
    _offlineSyncTimer?.cancel();
    activeDirectMessageUserId.value = null;
    StudentPresenceService.onlineUserIds.removeListener(_presenceChanged);
    messageSubscription.cancel();
    blockSubscription.cancel();
    _dmReactionSubscription.cancel();
    _scrollController.dispose();
    _dmRecordTimer?.cancel();
    unawaited(_dmRecorder.dispose());
    unawaited(_dmAudioPlayer.dispose());
    inputFocus.dispose();
    input.dispose();
    _typingIdleTimer?.cancel();
    _typingExpiryTimer?.cancel();
    final typingChannel = _typingChannel;
    if (typingChannel != null) unawaited(() async { await typingChannel.unsubscribe(); }());
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final avatar = widget.otherAvatar;
    final hasAvatar = avatar != null && avatar.startsWith('http');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? const Color(0xFF0C1B2D) : colors.surface,
        appBar: AppBar(
          backgroundColor: dark ? const Color(0xFF142B46) : colors.surface,
          foregroundColor: dark ? Colors.white : colors.onSurface,
          leading: _dmSelectionMode ? IconButton(onPressed:()=>setState(()=>_selectedDmIds.clear()),icon:const Icon(Icons.close_rounded)) : null,
          actions: _dmSelectionMode ? [_dmSelectionToolbar(colors)] : null,
          title: _dmSelectionMode ? Text('تم تحديد ${_selectedDmIds.length} رسالة') : Row(
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentPublicProfileScreen(
                      userId: widget.otherUserId,
                      fallbackName: _resolvedOtherName,
                      fallbackAvatar: avatar,
                    ),
                  ),
                ),
                child: CircleAvatar(
                  radius: 19,
                  backgroundImage: hasAvatar ? NetworkImage(avatar) : null,
                  child: hasAvatar ? null : const Icon(Icons.person_rounded, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _resolvedOtherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _otherOnline ? const Color(0xFF24B47E) : colors.outline,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _otherOnline ? 'متصل الآن' : 'غير متصل',
                          style: TextStyle(
                            fontSize: 11,
                            color: _otherOnline
                                ? const Color(0xFF24B47E)
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const [Color(0xFF071326), Color(0xFF0A1A31), Color(0xFF0B203B)]
                  : const [Color(0xFFF3F7FC), Color(0xFFE8F0FA), Color(0xFFF7F9FD)],
            ),
          ),
          child: Stack(children: [
            Positioned.fill(child: IgnorePointer(child: CustomPaint(
              painter: _StudyChatWallpaperPainter(dark: dark),
            ))),
            Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: messages,
                builder: (context, snapshot) {
                  if (snapshot.hasError && !_dmCacheLoaded && _cachedMessages.isEmpty) {
                    return const Center(child: Text('تعذر الاتصال. لا توجد رسائل محفوظة على هذا الجهاز بعد.'));
                  }
                  if (!snapshot.hasData && !_dmCacheLoaded) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final remoteRows = snapshot.data ?? _cachedMessages;
                  final items = _mergeOptimisticMessages(remoteRows);
                  if (items.isEmpty) {
                    return const Center(child: Text('ابدأ المحادثة برسالة ترحيبية 👋'));
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients &&
                        _scrollController.position.maxScrollExtent -
                                _scrollController.offset <
                            180) {
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(14),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final row = items[index];
                      final mine = row['sender_id'] == me;
                      final senderName = _participantNames[
                              row['sender_id']?.toString()] ??
                          (mine ? 'حسابي' : _resolvedOtherName);

                      return AnimatedOpacity(
                        opacity: _deletingMessageIds.contains(row['id'].toString()) ? 0 : 1,
                        duration: const Duration(milliseconds: 360),
                        child: AnimatedSlide(
                          offset: _deletingMessageIds.contains(row['id'].toString())
                            ? const Offset(0.32, 0) : Offset.zero,
                          duration: const Duration(milliseconds: 360),
                          curve: Curves.easeInCubic,
                          child: AnimatedScale(
                            scale: _deletingMessageIds.contains(row['id'].toString()) ? 0.82 : 1,
                            duration: const Duration(milliseconds: 360),
                            child: Align(
                        alignment: mine
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(row['_render_id'] ?? row['id']),
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 360),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 22 * (1 - value)),
                              child: child,
                            ),
                          ),
                          child: GestureDetector(
                            onTap: () => _dmSelectionMode ? _toggleDmSelection(row) : _showDmReactionPicker(row),
                            onLongPress: () => _toggleDmSelection(row),
                            onDoubleTap: mine ? () => _privateMessageActions(row) : null,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? colors.primary
                                    : colors.surfaceContainerHigh,
                                border: Border.all(
                                  color: mine
                                      ? colors.primary.withValues(alpha: 0.35)
                                      : colors.outlineVariant.withValues(alpha: 0.48),
                                  width: 0.7,
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(19),
                                  topRight: const Radius.circular(19),
                                  bottomLeft: Radius.circular(mine ? 19 : 6),
                                  bottomRight: Radius.circular(mine ? 6 : 19),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.shadow.withValues(alpha: 0.045),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_dmSelectionMode)
                                    Transform.translate(
                                      offset: const Offset(-25, 22),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 190),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        transitionBuilder: (child, animation) => ScaleTransition(
                                          scale: animation,
                                          child: FadeTransition(opacity: animation, child: child),
                                        ),
                                        child: Icon(
                                          _selectedDmIds.contains(row['id'].toString())
                                            ? Icons.check_circle_rounded
                                            : Icons.radio_button_unchecked_rounded,
                                          key: ValueKey(_selectedDmIds.contains(row['id'].toString())),
                                          color: _selectedDmIds.contains(row['id'].toString())
                                            ? colors.primary : colors.outline,
                                          size: 21,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: mine
                                          ? colors.onPrimary.withValues(alpha: 0.13)
                                          : colors.primary.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: mine
                                            ? colors.onPrimary.withValues(alpha: 0.22)
                                            : colors.primary.withValues(alpha: 0.20),
                                      ),
                                    ),
                                    child: Text(
                                      senderName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.1,
                                        letterSpacing: 0.15,
                                        fontWeight: FontWeight.w900,
                                        color: mine ? colors.onPrimary : colors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        child: _buildDirectMedia(
                                          row['body']?.toString() ?? '',
                                          (row['_render_id'] ?? row['id']).toString(),
                                          mine ? colors.onPrimary : colors.onSurface,
                                        ),
                                      ),
                                      if (row['edited_at'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 5),
                                          child: Text(
                                            'معدّلة',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: mine
                                                  ? colors.onPrimary.withValues(alpha: .7)
                                                  : colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      if (mine) ...[
                                        const SizedBox(width: 7),
                                        Tooltip(
                                          message: row['_local_status'] == 'queued'
                                              ? 'بانتظار عودة الإنترنت والإرسال'
                                              : row['read_at'] != null
                                                  ? 'تمت قراءة الرسالة'
                                                  : 'تم إرسال الرسالة',
                                          child: Icon(
                                            row['_local_status'] == 'queued'
                                                ? Icons.schedule_rounded
                                                : row['read_at'] != null
                                                    ? Icons.done_all_rounded
                                                    : Icons.done_rounded,
                                            size: 15,
                                            color: row['_local_status'] == 'queued'
                                                ? colors.onPrimary.withValues(alpha: .72)
                                                : row['read_at'] != null
                                                    ? Colors.lightBlueAccent
                                                    : colors.onPrimary.withValues(alpha: .72),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  _buildDmReactions(row['id'].toString(),colors),
                                ],
                              ),
                            ),
                          ),
                        ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_otherTyping)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 5),
                child: Row(children: [
                  const _TypingDots(),
                  const SizedBox(width: 8),
                  Text('يكتب الآن...', style: TextStyle(color: colors.primary,
                    fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            if (blocked)
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: Text(
                  'المراسلة متوقفة بسبب الحظر بين الحسابين.',
                  style: TextStyle(color: Color(0xFFB87922)),
                ),
              ),
            if (_editingDmId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                child: Row(children: [
                  Expanded(child: Text('تعديل الرسالة', style: TextStyle(
                    color: colors.primary, fontWeight: FontWeight.w700, fontSize: 12))),
                  IconButton(tooltip: 'إلغاء التعديل', onPressed: _cancelDmEdit,
                    icon: Icon(Icons.close_rounded, color: colors.error, size: 19)),
                ]),
              ),
            const _ChatRetentionNotice(),
          SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: input,
                      builder: (context, value, _) => Material(
                        color: Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: _dmRecording ? 'إيقاف وإرسال التسجيل' :
                            (value.text.trim().isEmpty ? 'تسجيل رسالة صوتية' : 'إرسال الرسالة'),
                          onPressed: sending || blocked ? null : (_dmRecording
                            ? () => _stopDirectVoiceRecording(send: true)
                            : (value.text.trim().isEmpty ? _startDirectVoiceRecording : send)),
                          icon: Icon(_dmRecording ? Icons.stop_rounded :
                            (value.text.trim().isEmpty ? Icons.mic_rounded : Icons.send_rounded),
                            color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    IconButton(
                      tooltip: _dmRecording ? 'إلغاء التسجيل' : 'إرسال صورة',
                      onPressed: sending || blocked ? null : (_dmRecording
                        ? () => _stopDirectVoiceRecording(send: false) : _pickAndSendDirectImage),
                      icon: Icon(_dmRecording ? Icons.close_rounded : Icons.image_outlined, size: 24),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: 54,
                          maxHeight: 118,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: dark ? const Color(0xFF1A304A) : Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: dark ? const Color(0xFF080E18) : const Color(0xFF26384D),
                            width: 1.35,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (dark ? Colors.black : const Color(0xFF26384D))
                                  .withValues(alpha: dark ? 0.28 : 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(painter: _StudyChatWallpaperPainter(dark: dark)),
                              ),
                            ),
                            Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: input,
                                focusNode: inputFocus,
                                enabled: !blocked,
                                minLines: 1,
                                maxLines: 4,
                                maxLength: 2000,
                                textAlignVertical: TextAlignVertical.center,
                                textInputAction: TextInputAction.send,
                                onChanged: _notifyTyping,
                                onSubmitted: (_) => send(),
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  hintText: blocked
                                      ? 'المراسلة غير متاحة بسبب الحظر'
                                      : 'الرسالة',
                                  hintStyle: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 15,
                                  ),
                                  counterText: '',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'إضافة رمز تعبيري',
                              visualDensity: VisualDensity.compact,
                              onPressed: blocked ? null : _openEmojiPicker,
                              icon: Icon(
                                Icons.emoji_emotions_outlined,
                                color: colors.onSurfaceVariant,
                                size: 25,
                              ),
                            ),
                          ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )]),
      ),
    ));
  }
}


class _PrivateEmojiPicker extends StatefulWidget {
  final bool dark;
  const _PrivateEmojiPicker({required this.dark});

  @override
  State<_PrivateEmojiPicker> createState() => _PrivateEmojiPickerState();
}

class _PrivateEmojiPickerState extends State<_PrivateEmojiPicker> {
  static const Map<String, List<String>> _categories = {
    'الوجوه': [
      '😀','😃','😄','😁','😆','😅','😂','🤣','😊','😇','🙂','🙃',
      '😉','😍','🥰','😘','😗','😙','😚','😋','😛','😜','🤪','😎',
      '🤓','🧐','🤔','🤫','🤭','😐','😑','😶','😏','😒','🙄','😬',
      '😴','🥱','😷','🤒','🤕','🤧','🥵','🥶','😵','🤯','🥳','😭',
      '😢','😤','😡','🤬','😱','😨','😰','😥','🤗','🤩','🥺','🫡',
    ],
    'القلوب': [
      '❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','🩷','🩵','🩶',
      '💔','❣️','💕','💞','💓','💗','💖','💘','💝','💟','♥️','💌',
      '👍','👎','👏','🙌','🤝','🙏','💪','🫶','👊','✊','🤞','✌️',
    ],
    'الإشارات': [
      '👋','🤚','🖐️','✋','🖖','👌','🤌','🤏','✍️','💅','🤳','💃',
      '🕺','☝️','👇','👆','👉','👈','🫵','🫰','🤟','🤘','🤙','🖕',
      '✅','❌','⭕','🚫','⚠️','❗','❓','💯','🔥','✨','⭐','🌟',
    ],
    'الدراسة': [
      '📚','📖','📕','📗','📘','📙','📓','📝','✏️','🖊️','📐','📏',
      '🎓','🏫','🧑‍🎓','👨‍🏫','👩‍🏫','🧠','💡','🔬','🧪','🧮','📊','📈',
      '🏆','🥇','🎯','⏰','📅','🔔','💻','⌨️','🖥️','🌍','☀️','🌈',
    ],
  };

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = _categories.entries.toList();
    final background = widget.dark
        ? const Color(0xFF142B46)
        : colors.surface;
    return SafeArea(
      top: false,
      child: Container(
        height: 350,
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'الإيموجيات',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    '${_categories.values.fold<int>(0, (sum, list) => sum + list.length)} رمز',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) => ChoiceChip(
                  label: Text(entries[index].key),
                  selected: _selected == index,
                  onSelected: (_) => setState(() => _selected = index),
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: GridView.builder(
                  key: ValueKey(_selected),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 3,
                    crossAxisSpacing: 3,
                  ),
                  itemCount: entries[_selected].value.length,
                  itemBuilder: (context, index) {
                    final emoji = entries[_selected].value[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.pop(context, emoji),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 25)),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentChatScreen extends StatefulWidget {
  const StudentChatScreen({super.key});
  @override
  State<StudentChatScreen> createState() => _StudentChatScreenState();
}
class _StudentChatScreenState extends State<StudentChatScreen> {
  Widget _selectionToolbar(int count, {required VoidCallback onClear, required VoidCallback onDelete, required VoidCallback onCopy, required VoidCallback onEdit, required bool canEdit, required ColorScheme colors}) => Row(mainAxisSize: MainAxisSize.min, children: [IconButton(tooltip:'إلغاء التحديد',onPressed:onClear,icon:const Icon(Icons.close_rounded)),Text(count.toString(),style:const TextStyle(fontWeight:FontWeight.w900)),IconButton(tooltip:'نسخ',onPressed:onCopy,icon:const Icon(Icons.copy_rounded)),IconButton(tooltip:'تعديل',onPressed:canEdit?onEdit:null,icon:const Icon(Icons.edit_rounded)),IconButton(tooltip:'حذف',onPressed:onDelete,icon:Icon(Icons.delete_outline_rounded,color:colors.error))]);
  final input = TextEditingController();
  final scroll = ScrollController();
  late Stream<List<Map<String, dynamic>>> messages;
  String _profileCacheKey = '';
  Future<Map<String, Map<String, dynamic>>>? _profilesFuture;
  bool sending = false;
  bool _isGroupChatAdmin = false;
  final Set<String> _deletingGroupMessageIds = {};
  final Set<String> _selectedGroupMessageIds = {};
  String? _editingGroupMessageId, _editingGroupOriginal;
  final Map<String, Map<String,dynamic>> _selectedGroupRows = {};
  final Map<String, List<Map<String, dynamic>>> _groupMessageReactions = {};
  StreamSubscription<List<Map<String, dynamic>>>? _groupReactionsSubscription;
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FocusNode inputFocus = FocusNode();
  final Set<String> _blockedUserIds = {};
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
    unawaited(_loadGroupChatRole());
    _groupReactionsSubscription = _db
        .from('chat_message_reactions')
        .stream(primaryKey: ['id'])
        .listen((rows) {
      if (!mounted) return;
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final reaction in rows) {
        final messageId = reaction['message_id']?.toString();
        if (messageId == null) continue;
        grouped.putIfAbsent(messageId, () => <Map<String, dynamic>>[])
            .add(reaction);
      }
      setState(() {
        _groupMessageReactions
          ..clear()
          ..addAll(grouped);
      });
    });
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
      _db.from('chat_messages').stream(primaryKey: ['id']).order('created_at', ascending: true);

  Future<void> _loadGroupChatRole() async {
    try {
      final result = await _db.rpc('is_group_chat_admin');
      if (!mounted) return;
      setState(() => _isGroupChatAdmin = result == true);
    } catch (error) {
      debugPrint('Load group chat moderation role failed: $error');
      if (mounted) setState(() => _isGroupChatAdmin = false);
    }
  }

  Future<bool> _checkGroupChatPostingPermission() async {
    try {
      final raw = await _db.rpc('get_my_group_chat_status');
      final status = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      if (status['is_banned'] == true) {
        toast('تم حظرك من غرفة الدردشة الجماعية.');
        return false;
      }
      if (status['is_muted'] == true) {
        if (status['is_permanent'] == true) {
          toast('تم كتمك بشكل دائم من غرفة الدردشة الجماعية.');
        } else {
          final until = DateTime.tryParse(status['muted_until']?.toString() ?? '')?.toLocal();
          final remaining = until == null ? '' : ' حتى ${TimeOfDay.fromDateTime(until).format(context)}';
          toast('أنت مكتوم من غرفة الدردشة$remaining.');
        }
        return false;
      }
      return true;
    } on PostgrestException catch (error) {
      debugPrint('Check group chat posting permission failed: ${error.message}');
      return true;
    } catch (error) {
      debugPrint('Check group chat posting permission failed: $error');
      return true;
    }
  }

  void _retryMessages() {
    setState(() => messages = _messageStream());
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

  void _openChatProfile(String userId, Map<String,dynamic>? profile, String name, String? avatar) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StudentPublicProfileScreen(
      userId: userId,
      fallbackName: name,
      fallbackUsername: profile?['username']?.toString(),
      fallbackStage: profile?['stage']?.toString(),
      fallbackAvatar: avatar,
      fallbackBadge: profile?['badge']?.toString(),
      fallbackBio: profile?['bio']?.toString(),
      fallbackDeveloper: profile?['is_developer'] == true,
    )));
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

  static const List<String> _messageReactionEmojis = ['❤️', '👍', '😂', '🔥', '💙', '👏', '🌟', '🥰'];

  Future<void> _showMessageReactionPicker(Map<String, dynamic> row) async {
    final messageId = row['id']?.toString();
    final userId = _db.auth.currentUser?.id;
    if (messageId == null || userId == null || messageId.startsWith('local-')) return;
    final emoji = await showModalBottomSheet<String>(
      context: context, backgroundColor: Colors.transparent,
      builder: (sheetContext) => Directionality(textDirection: TextDirection.rtl,
        child: SafeArea(child: Container(
          margin: const EdgeInsets.all(10), padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
          decoration: BoxDecoration(color: Theme.of(sheetContext).colorScheme.surface, borderRadius: BorderRadius.circular(22)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('تفاعل مع الرسالة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 14),
            Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12,
              children: _messageReactionEmojis.map((value) => InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.pop(sheetContext, value),
                child: Padding(padding: const EdgeInsets.all(7), child: Text(value, style: const TextStyle(fontSize: 30))),
              )).toList(),
            ),
          ]),
        )),
      ),
    );
    if (emoji == null || !mounted) return;
    try {
      final existing = await _db.from('chat_message_reactions').select('id,emoji').eq('message_id', messageId).eq('user_id', userId).maybeSingle();
      if (existing?['emoji'] == emoji) { await _db.from('chat_message_reactions').delete().eq('id', existing!['id']).eq('user_id', userId); }
      else { await _db.from('chat_message_reactions').upsert({'message_id': messageId, 'user_id': userId, 'emoji': emoji}, onConflict:'message_id,user_id'); }
    } catch (error) { if (mounted) toast('تعذر تسجيل التفاعل: $error'); }
  }

  Widget _buildGroupMessageReactions(String messageId, ColorScheme colors) {
    final reactions = _groupMessageReactions[messageId] ?? const [];
    if (reactions.isEmpty) return const SizedBox.shrink();
    final currentUserId = _db.auth.currentUser?.id;
    final counts = <String, int>{};
    final mine = <String>{};
    for (final reaction in reactions) {
      final emoji = reaction['emoji']?.toString() ?? '';
      if (emoji.isEmpty) continue;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
      if (reaction['user_id']?.toString() == currentUserId) mine.add(emoji);
    }
    return Padding(padding: const EdgeInsets.only(top: 5), child: Wrap(spacing: 5, runSpacing: 4,
      children: counts.entries.map((entry) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final userId = _db.auth.currentUser?.id;
          if (userId == null) return;
          try {
            final existing = await _db.from('chat_message_reactions').select('id,emoji').eq('message_id', messageId).eq('user_id', userId).maybeSingle();
            if (existing?['emoji'] == entry.key) { await _db.from('chat_message_reactions').delete().eq('id', existing!['id']).eq('user_id', userId); }
            else { await _db.from('chat_message_reactions').upsert({'message_id': messageId, 'user_id': userId, 'emoji': entry.key}, onConflict:'message_id,user_id'); }
          } catch (error) { if (mounted) toast('تعذر تحديث التفاعل: $error'); }
        },
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: mine.contains(entry.key) ? colors.primaryContainer : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: mine.contains(entry.key) ? colors.primary : colors.outlineVariant),
          ),
          child: Text('${entry.key} ${entry.value}', style: TextStyle(fontSize: 12, color: colors.onSurface)),
        ),
      )).toList(),
    ));
  }

  bool get _groupSelectionMode => _selectedGroupMessageIds.isNotEmpty;
  List<Map<String,dynamic>> get _selectedGroupMessages => _selectedGroupMessageIds.map((id)=>_selectedGroupRows[id]).whereType<Map<String,dynamic>>().toList();
  void _toggleGroupSelection(Map<String,dynamic> row) {
    final id = row['id']?.toString();
    final currentUserId = _db.auth.currentUser?.id;
    if (id == null || currentUserId == null || row['user_id'] != currentUserId) return;
    setState(() {
      if (_selectedGroupMessageIds.remove(id)) {
        _selectedGroupRows.remove(id);
      } else {
        _selectedGroupMessageIds.add(id);
        _selectedGroupRows[id] = Map<String,dynamic>.from(row);
      }
    });
  }
  Future<void> _copySelectedGroupMessages() async { final values=_selectedGroupMessages.map((r)=>(r['body']??'').toString()).where((v)=>v.trim().isNotEmpty).toList(); if(values.isEmpty){toast('لا توجد نصوص قابلة للنسخ.');return;} await Clipboard.setData(ClipboardData(text:values.join('\n'))); if(!mounted)return; toast('تم نسخ ${values.length} رسالة.'); setState(()=>_selectedGroupMessageIds.clear()); _selectedGroupRows.clear(); }
  Future<void> _deleteSelectedGroupMessages() async { final user=_db.auth.currentUser?.id; if(user==null)return; final ids=_selectedGroupMessages.where((r)=>r['user_id']==user).map((r)=>r['id'].toString()).toList(); if(ids.isEmpty){setState(()=>_selectedGroupMessageIds.clear());_selectedGroupRows.clear();return;} final ok=await showDialog<bool>(context:context,builder:(ctx)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(title:const Text('حذف الرسائل المحددة؟'),content:Text('سيتم حذف ${ids.length} رسالة تملكها.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حذف'))]))); if(ok!=true)return; setState(()=>_deletingGroupMessageIds.addAll(ids)); await Future<void>.delayed(const Duration(milliseconds:360)); try { await _db.from('chat_messages').delete().inFilter('id',ids).eq('user_id',user); if(!mounted)return; setState(()=>_selectedGroupMessageIds.clear()); _selectedGroupRows.clear(); toast('تم حذف الرسائل المحددة.'); } catch(e){if(mounted){setState(()=>_deletingGroupMessageIds.removeAll(ids));toast('تعذر حذف الرسائل: $e');}} }
  Future<void> _editSelectedGroupMessage() async { final rows=_selectedGroupMessages; final user=_db.auth.currentUser?.id; if(rows.length!=1||rows.first['user_id']!=user||rows.first['message_type']!='text')return; await _editGroupMessage(rows.first); if(mounted){setState(()=>_selectedGroupMessageIds.clear());_selectedGroupRows.clear();} }
  Future<void> _messageActions(Map<String, dynamic> row) async {
    final mine = row['user_id'] == _db.auth.currentUser?.id;
    final canModerate = _isGroupChatAdmin && !mine;
    final action = await showModalBottomSheet<String>(context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => Directionality(textDirection: TextDirection.rtl,
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (mine && row['message_type'] == 'text' && (row['body']?.toString().isNotEmpty ?? false))
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('تعديل الرسالة'), onTap: () => Navigator.pop(ctx, 'edit')),
          if (mine && (row['body']?.toString().trim().isNotEmpty ?? false))
            ListTile(leading: const Icon(Icons.copy_rounded), title: const Text('نسخ الرسالة'), onTap: () => Navigator.pop(ctx, 'copy')),
          if (mine) ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('حذف الرسالة'), onTap: () => Navigator.pop(ctx, 'delete')),
          if (canModerate) ...[
            ListTile(leading: const Icon(Icons.delete_forever_outlined, color: Colors.red), title: const Text('حذف رسالة المستخدم'), onTap: () => Navigator.pop(ctx, 'admin_delete')),
            ListTile(leading: const Icon(Icons.timer_off_outlined), title: const Text('كتم المستخدم'), onTap: () => Navigator.pop(ctx, 'admin_mute')),
            ListTile(leading: const Icon(Icons.gpp_bad_outlined, color: Colors.red), title: const Text('حظر المستخدم من الغرفة'), onTap: () => Navigator.pop(ctx, 'admin_ban')),
          ],
          if (!mine) ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('الإبلاغ عن الرسالة'), onTap: () => Navigator.pop(ctx, 'report')),
          if (!mine) ListTile(leading: const Icon(Icons.person_off_outlined), title: const Text('الإبلاغ عن المستخدم'), onTap: () => Navigator.pop(ctx, 'report_user')),
          if (!mine && !canModerate) ListTile(leading: const Icon(Icons.block_outlined), title: const Text('حظر المستخدم عندي'), onTap: () => Navigator.pop(ctx, 'block')),
        ]))));
    if (!mounted) return;
    if (action == 'copy') {
      final body = row['body']?.toString() ?? '';
      if (body.trim().isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: body));
        if (mounted) toast('تم نسخ الرسالة.');
      }
      return;
    }
    if (action == 'edit') {
      await _editGroupMessage(row);
      return;
    }
    if (action == 'delete') {
      final ok = await showDialog<bool>(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl,
        child: AlertDialog(title: const Text('حذف الرسالة؟'), content: const Text('سيتم حذف الرسالة من الدردشة.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))])));
      if (ok == true) {
        final userId = _db.auth.currentUser?.id;
        if (userId == null) { toast('انتهت جلسة تسجيل الدخول.'); return; }
        final id = row['id'].toString();
        if (mounted) setState(() => _deletingGroupMessageIds.add(id));
        await Future<void>.delayed(const Duration(milliseconds: 360));
        try { await _db.from('chat_messages').delete().eq('id', id).eq('user_id', userId); }
        catch (e) {
          if (mounted) setState(() => _deletingGroupMessageIds.remove(id));
          toast('تعذر حذف الرسالة: $e');
        }
      }
    }
    if (action == 'admin_delete') await _adminDeleteGroupMessage(row);
    if (action == 'admin_mute') await _adminMuteGroupUser(row);
    if (action == 'admin_ban') await _adminBanGroupUser(row);
    if (action == 'report') await report(row);
    if (action == 'report_user') await report(row, reportUser: true);
    if (action == 'block') await _blockUser(row);
  }

  Future<void> _editGroupMessage(Map<String,dynamic> row) async {
    if (row['user_id'] != _db.auth.currentUser?.id || row['message_type'] != 'text') return;
    final value = row['body']?.toString() ?? '';
    setState(() {
      _editingGroupMessageId = row['id'].toString(); _editingGroupOriginal = value;
      _selectedGroupMessageIds.clear(); _selectedGroupRows.clear();
      input.value = TextEditingValue(text: value,
        selection: TextSelection.collapsed(offset: value.length));
    });
    inputFocus.requestFocus();
  }
  void _cancelGroupEdit() {
    setState(() { _editingGroupMessageId = null; _editingGroupOriginal = null; input.clear(); });
    inputFocus.unfocus();
  }

  Future<void> _openGroupEmojiPicker() async {
    inputFocus.unfocus();
    final emoji = await showModalBottomSheet<String>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _PrivateEmojiPicker(dark: Theme.of(context).brightness == Brightness.dark));
    if (!mounted || emoji == null) return;
    final oldValue = input.value;
    final selection = oldValue.selection;
    final start = selection.isValid ? selection.start : oldValue.text.length;
    final end = selection.isValid ? selection.end : oldValue.text.length;
    input.value = TextEditingValue(text: oldValue.text.replaceRange(start, end, emoji), selection: TextSelection.collapsed(offset: start + emoji.length));
    inputFocus.requestFocus();
  }

  Future<void> send({String? sticker}) async {
    final user = _db.auth.currentUser;
    if (user == null) { toast('سجّل الدخول بحساب Google للمشاركة.'); return; }
    final text = input.text.trim();
    if (sticker == null && text.isEmpty) return;
    if (_editingGroupMessageId != null) {
      if (sticker != null) return;
      if (text == _editingGroupOriginal) { _cancelGroupEdit(); return; }
      if (text.length > 500 || unsafe(text)) {
        toast('لم تُعدّل الرسالة: تجنب الإساءة أو أرقام الهواتف أو البريد أو الروابط، والحد 500 حرف.');
        return;
      }
      setState(() => sending = true);
      try {
        await _db.from('chat_messages').update({'body': text,
          'edited_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', _editingGroupMessageId!).eq('user_id', user.id);
        if (mounted) {
          setState(() { _editingGroupMessageId = null; _editingGroupOriginal = null; });
          input.clear(); inputFocus.unfocus(); toast('تم تعديل الرسالة.');
        }
      } catch (error) { toast('تعذر تعديل الرسالة: $error'); }
      finally { if (mounted) setState(() => sending = false); }
      return;
    }
    if (sticker == null && (text.length > 500 || unsafe(text))) {
      toast('لم تُرسل الرسالة: تجنب الإساءة أو أرقام الهواتف أو البريد أو الروابط.'); return;
    }
    setState(() => sending = true);
    try {
      await _db.from('chat_messages').insert({
        'user_id': user.id, 'message_type': sticker == null ? 'text' : 'builtin_sticker',
        'body': sticker == null ? text : null, 'sticker_id': sticker,
      });
      input.clear();
      if (scroll.hasClients) {
        await scroll.animateTo(
          scroll.position.maxScrollExtent,
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
  Future<void> _showGroupMembers() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final raw = await _db.from('chat_messages')
        .select('user_id')
        .isFilter('deleted_at', null)
        .isFilter('hidden_at', null)
        .order('created_at', ascending: false)
        .limit(500);
      final ids = (raw as List).whereType<Map>()
        .map((row) => row['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty).toSet();

      Map<String, dynamic>? developer;
      try {
        final found = await _db.rpc('search_student_profiles_v1', params: {
          'p_query': '1', 'p_stage': null, 'p_user_id': null, 'p_limit': 50,
        });
        for (final row in (found as List).whereType<Map>()) {
          final profile = Map<String, dynamic>.from(row);
          if (profile['is_developer'] == true || profile['username']?.toString() == '1') {
            developer = profile;
            final id = profile['user_id']?.toString();
            if (id != null && id.isNotEmpty) ids.add(id);
            break;
          }
        }
      } catch (_) {}

      final profiles = <String, Map<String, dynamic>>{};
      if (ids.isNotEmpty) {
        final result = await _db.rpc('get_student_chat_profiles_v1',
          params: {'p_user_ids': ids.toList()});
        for (final row in (result as List).whereType<Map>()) {
          final profile = Map<String, dynamic>.from(row);
          profiles[profile['user_id'].toString()] = profile;
        }
      }
      if (developer == null) {
        for (final profile in profiles.values) {
          if (profile['is_developer'] == true) {
            developer = profile;
            break;
          }
        }
      }
      final online = StudentPresenceService.onlineUserIds.value;
      final participants = profiles.values.toList();
      final devId = developer?['user_id']?.toString();
      participants.removeWhere((p) => p['user_id']?.toString() == devId);
      participants.sort((a, b) {
        final aOnline = online.contains(a['user_id']?.toString());
        final bOnline = online.contains(b['user_id']?.toString());
        return (bOnline ? 1 : 0).compareTo(aOnline ? 1 : 0);
      });
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.72,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: SvgPicture.asset('assets/brand/app_icon.svg', width: 34, height: 34),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('أعضاء غرفة الدردشة',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                    Text('${participants.length + 1}', style: TextStyle(
                      color: Theme.of(sheetContext).colorScheme.primary,
                      fontWeight: FontWeight.w900)),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    Builder(builder: (context) {
                      final developerProfile = devId == null
                        ? developer
                        : (profiles[devId] ?? developer);
                      final avatarUrl = developerProfile?['avatar_url']?.toString();
                      final isOnline = devId != null && online.contains(devId);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [Color(0xFF172F55), Color(0xFF101D34), Color(0xFF17243B)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF398EFF).withValues(alpha: 0.48)),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF247DDF).withValues(alpha: 0.12),
                              blurRadius: 16, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF55A5FF), width: 1.8),
                            ),
                            child: CircleAvatar(
                              radius: 25,
                              backgroundColor: const Color(0xFF123F80),
                              backgroundImage: avatarUrl != null && avatarUrl.startsWith('http')
                                ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl == null || !avatarUrl.startsWith('http')
                                ? const Icon(Icons.person_rounded, color: Colors.white, size: 27)
                                : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('المدير', style: TextStyle(
                                color: Color(0xFF82BCFF), fontSize: 11,
                                fontWeight: FontWeight.w800, letterSpacing: 0.7)),
                              SizedBox(height: 3),
                              Row(children: [
                                Text('ذوالفقار', style: TextStyle(
                                  color: Colors.white, fontSize: 18,
                                  fontWeight: FontWeight.w900, letterSpacing: 0.15)),
                                SizedBox(width: 6),
                                _DeveloperBadge(compact: true),
                              ]),
                              SizedBox(height: 3),
                              Text('مطور التطبيق', style: TextStyle(
                                color: Color(0xFFB9CBE3), fontSize: 11,
                                fontWeight: FontWeight.w600)),
                            ],
                          )),
                          const SizedBox(width: 8),
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(
                              color: isOnline ? const Color(0xFF29C58A) : Colors.grey,
                              shape: BoxShape.circle)),
                            const SizedBox(height: 5),
                            Text(isOnline ? 'متصل' : 'غير متصل',
                              style: const TextStyle(color: Color(0xFFCBD8E8), fontSize: 10)),
                          ]),
                        ]),
                      );
                    }),
                    const Divider(indent: 16, endIndent: 16),
                    for (final profile in participants)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundImage: (profile['avatar_url']?.toString().startsWith('http') ?? false)
                            ? NetworkImage(profile['avatar_url'].toString()) : null,
                          child: !(profile['avatar_url']?.toString().startsWith('http') ?? false)
                            ? const Icon(Icons.person_rounded) : null,
                        ),
                        title: Text(profile['display_name']?.toString().trim().isNotEmpty == true
                          ? profile['display_name'].toString() : 'طالب',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('@${profile['username'] ?? '—'}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 7, height: 7, decoration: BoxDecoration(
                            color: online.contains(profile['user_id']?.toString())
                              ? const Color(0xFF29C58A) : Colors.grey,
                            shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text(online.contains(profile['user_id']?.toString())
                            ? 'متصل' : 'غير متصل', style: const TextStyle(fontSize: 11)),
                        ]),
                      ),
                  ],
                )),
              ]),
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('تعذر تحميل أعضاء الغرفة: $error')),
        );
      }
    }
  }

  Future<Map<String, Map<String, dynamic>>> getProfiles(List<Map<String, dynamic>> rows) async {
    final ids = rows.map((r) => r['user_id'].toString()).toSet().toList();
    if (ids.isEmpty) return {};
    try {
      final result = await _db.rpc('get_student_chat_profiles_v1', params: {'p_user_ids': ids});
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
    _groupReactionsSubscription?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    unawaited(_recorder.dispose());
    unawaited(_audioPlayer.dispose());
    inputFocus.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: dark ? const Color(0xFF0C1B2D) : colors.surface,
      appBar: AppBar(backgroundColor: dark ? const Color(0xFF142B46) : colors.surface, foregroundColor: dark ? Colors.white : colors.onSurface, elevation: 0,
        leading: _groupSelectionMode ? IconButton(onPressed:()=>setState(()=>_selectedGroupMessageIds.clear()),icon:const Icon(Icons.close_rounded)) : null,
        title: _groupSelectionMode ? Text('تم تحديد ${_selectedGroupMessageIds.length} رسالة') : Row(children: [
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('غرفة الدردشة', style: TextStyle(fontWeight: FontWeight.w800)),
              Text('محادثة جماعية للطلاب', style: TextStyle(fontSize: 11)),
            ],
          )),
          const SizedBox(width: 9),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _showGroupMembers,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SvgPicture.asset('assets/brand/app_icon.svg', width: 36, height: 36),
              ),
            ),
          ),
        ]),
        actions: _groupSelectionMode ? [_selectionToolbar(_selectedGroupMessageIds.length,onClear:()=>setState(()=>_selectedGroupMessageIds.clear()),onDelete:_deleteSelectedGroupMessages,onCopy:_copySelectedGroupMessages,onEdit:_editSelectedGroupMessage,canEdit:_selectedGroupMessages.length==1&&_selectedGroupMessages.first['user_id']==_db.auth.currentUser?.id&&_selectedGroupMessages.first['message_type']=='text',colors:colors)] : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const [Color(0xFF071326), Color(0xFF0A1A31), Color(0xFF0B203B)]
                : const [Color(0xFFF3F7FC), Color(0xFFE8F0FA), Color(0xFFF7F9FD)],
          ),
        ),
        child: Stack(children: [
          Positioned.fill(child: IgnorePointer(child: CustomPaint(
            painter: _StudyChatWallpaperPainter(dark: dark),
          ))),
          Column(children: [
        const _ChatRetentionNotice(),
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
            if (rows.length != _lastMessageCount) {
              final hadPreviousMessages = _lastMessageCount > 0;
              _lastMessageCount = rows.length;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!scroll.hasClients) return;
                final distanceFromBottom = scroll.position.maxScrollExtent - scroll.offset;
                if (!hadPreviousMessages || distanceFromBottom <= 120) {
                  scroll.animateTo(scroll.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
                }
              });
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
                reverse: false,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final mine = row['user_id']?.toString() == _db.auth.currentUser?.id;
                  final profile = profiles.data?[row['user_id'].toString()];
                  final currentUser = _db.auth.currentUser;
                  final currentUserMetadata =
                      currentUser?.userMetadata ?? const <String, dynamic>{};
                  final name = (profile?['display_name'] ??
                    (mine ? (currentUserMetadata['full_name'] ??
                      currentUserMetadata['name']) : null) ??
                    'طالب').toString();
                  final type = row['message_type']?.toString() ?? 'text';
                  final sticker = type == 'builtin_sticker' || type == 'custom_sticker';
                  final mediaPath = row['storage_path']?.toString() ?? '';
                  final colors = Theme.of(context).colorScheme;
                  final avatar = profile?['avatar_url']?.toString();
                  final fallbackAvatar = mine
                      ? currentUserMetadata['picture']?.toString()
                      : null;
                  final avatarSource = avatar != null && avatar.startsWith('http')
                      ? avatar
                      : fallbackAvatar != null && fallbackAvatar.startsWith('http')
                          ? fallbackAvatar
                          : null;
                  final isDeveloper = profile?['is_developer'] == true ||
                      (mine && _isVerifiedDeveloper(currentUser));
                  final bubbleTextColor = mine
                      ? colors.onPrimary
                      : colors.onSurface;
                  final bubbleNameColor = mine
                      ? colors.onPrimary
                      : colors.primary;
                  final bubbleMetaColor = mine
                      ? colors.onPrimary.withValues(alpha: 0.78)
                      : colors.onSurfaceVariant;

                  return AnimatedOpacity(
                    opacity: _deletingGroupMessageIds.contains(row['id'].toString()) ? 0 : 1,
                    duration: const Duration(milliseconds: 360),
                    child: AnimatedSlide(
                      offset: _deletingGroupMessageIds.contains(row['id'].toString())
                        ? const Offset(0.32, 0) : Offset.zero,
                      duration: const Duration(milliseconds: 360),
                      curve: Curves.easeInCubic,
                      child: AnimatedScale(
                        scale: _deletingGroupMessageIds.contains(row['id'].toString()) ? 0.82 : 1,
                        duration: const Duration(milliseconds: 360),
                        child: Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        if (_groupSelectionMode) {
                          if (mine) _toggleGroupSelection(row);
                        } else {
                          _showMessageReactionPicker(row);
                        }
                      },
                      onLongPress: () {
                        if (mine) {
                          _toggleGroupSelection(row);
                        } else {
                          if (_groupSelectionMode) {
                            setState(() {
                              _selectedGroupMessageIds.clear();
                              _selectedGroupRows.clear();
                            });
                          }
                          _messageActions(row);
                        }
                      },
                      onDoubleTap: () => _messageActions(row),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (_groupSelectionMode && mine)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 190),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) => ScaleTransition(
                                  scale: animation,
                                  child: FadeTransition(opacity: animation, child: child),
                                ),
                                child: Icon(
                                  _selectedGroupMessageIds.contains(row['id'].toString())
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                  key: ValueKey(_selectedGroupMessageIds.contains(row['id'].toString())),
                                  color: _selectedGroupMessageIds.contains(row['id'].toString())
                                    ? colors.primary : colors.outline,
                                  size: 22,
                                ),
                              ),
                            ),
                          if (!mine) ...[
                            InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _openChatProfile(
                                row['user_id'].toString(), profile, name, avatarSource,
                              ),
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: colors.surfaceContainerHighest,
                                backgroundImage: avatarSource == null
                                    ? null
                                    : CachedNetworkImageProvider(avatarSource),
                                child: avatarSource == null
                                    ? Icon(Icons.person_rounded,
                                        size: 17, color: colors.onSurfaceVariant)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                            decoration: BoxDecoration(
                              color: mine ? colors.primary : colors.surfaceContainerHigh,
                              border: Border.all(
                                color: mine
                                    ? colors.primary.withValues(alpha: 0.35)
                                    : colors.outlineVariant.withValues(alpha: 0.48),
                                width: 0.7,
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(19),
                                topRight: const Radius.circular(19),
                                bottomLeft: Radius.circular(mine ? 19 : 6),
                                bottomRight: Radius.circular(mine ? 6 : 19),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.shadow.withValues(alpha: 0.045),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? colors.onPrimary.withValues(alpha: 0.13)
                                        : colors.primary.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: mine
                                          ? colors.onPrimary.withValues(alpha: 0.22)
                                          : colors.primary.withValues(alpha: 0.20),
                                    ),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.15,
                                          letterSpacing: 0.15,
                                          fontWeight: FontWeight.w900,
                                          color: bubbleNameColor,
                                        ),
                                      ),
                                    ),
                                    if (isDeveloper) ...[
                                      const SizedBox(width: 5),
                                      _DeveloperBadge(compact: true, onPrimary: mine),
                                    ],
                                  ]),
                                ),
                                const SizedBox(height: 7),
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
                                          color: bubbleTextColor,
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
                                    style: TextStyle(
                                      fontSize: sticker ? 28 : 14,
                                      height: 1.35,
                                      color: bubbleTextColor,
                                    ),
                                  ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                      Text(
                                        timeOf(row['created_at']),
                                        style: TextStyle(
                                          fontSize: 9,
                                          height: 1,
                                          color: bubbleMetaColor,
                                        ),
                                      ),
                                      if (mine && row['_local_status'] == 'queued') ...[
                                        const SizedBox(width: 4),
                                        Text('بانتظار الإرسال',
                                          style: TextStyle(fontSize: 9,
                                            color: bubbleMetaColor,
                                            fontWeight: FontWeight.w700)),
                                        const SizedBox(width: 3),
                                        Icon(Icons.schedule_rounded, size: 12,
                                          color: bubbleMetaColor),
                                      ] else if (mine) ...[
                                        const SizedBox(width: 3),
                                        Icon(Icons.done_rounded, size: 12,
                                          color: colors.onSurfaceVariant),
                                      ],
                                  ],
                                ),
                                _buildGroupMessageReactions(row['id'].toString(), colors),
                              ],
                            ),
                          ),
                          if (mine) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _openChatProfile(
                                row['user_id'].toString(), profile, name, avatarSource,
                              ),
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: colors.surfaceContainerHighest,
                                backgroundImage: avatarSource == null
                                    ? null
                                    : CachedNetworkImageProvider(avatarSource),
                                child: avatarSource == null
                                    ? Icon(Icons.person_rounded,
                                        size: 17, color: colors.onSurfaceVariant)
                                    : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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
          SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Column(children: [
              Row(
                textDirection: TextDirection.rtl,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: input,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      return Material(
                        color: Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: _recording ? 'إيقاف التسجيل' : (hasText ? 'إرسال الرسالة' : 'تسجيل رسالة صوتية'),
                          onPressed: sending ? null : (_recording
                            ? () => _stopVoiceRecording(send: true)
                            : (hasText ? () => send() : _startVoiceRecording)),
                          icon: Icon(
                            _recording ? Icons.stop_rounded
                              : (hasText ? Icons.send_rounded : Icons.mic_rounded),
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 7),
                  IconButton(
                    tooltip: _recording ? 'إلغاء التسجيل' : 'إرسال صورة',
                    onPressed: sending ? null : (_recording
                      ? () => _stopVoiceRecording(send: false)
                      : _pickAndSendImage),
                    icon: Icon(
                      _recording ? Icons.close_rounded : Icons.image_outlined,
                      size: 25,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 54, maxHeight: 118),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF1A304A) : Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: dark ? const Color(0xFF080E18) : const Color(0xFF26384D),
                          width: 1.35,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (dark ? Colors.black : const Color(0xFF26384D))
                                .withValues(alpha: dark ? 0.28 : 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(painter: _StudyChatWallpaperPainter(dark: dark)),
                            ),
                          ),
                          Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: input,
                              focusNode: inputFocus,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 500,
                              textAlignVertical: TextAlignVertical.center,
                              style: TextStyle(color: colors.onSurface, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'الرسالة',
                                hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 15),
                                counterText: '',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'إضافة رمز تعبيري',
                            visualDensity: VisualDensity.compact,
                            onPressed: _openGroupEmojiPicker,
                            icon: Icon(Icons.emoji_emotions_outlined, color: colors.onSurfaceVariant, size: 25),
                          ),
                          ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (_editingGroupMessageId != null)
                Row(children: [
                  Expanded(child: Text('تعديل الرسالة', style: TextStyle(
                    color: colors.primary, fontSize: 12, fontWeight: FontWeight.w700))),
                  IconButton(tooltip: 'إلغاء التعديل', onPressed: _cancelGroupEdit,
                    icon: Icon(Icons.close_rounded, color: colors.error, size: 19)),
                ]),
              if (_recording)
                Text('جارٍ التسجيل • $_recordSeconds ثانية',
                  style: const TextStyle(fontSize: 11, color: Colors.red)),
              const Text('اضغط مطولاً على رسالة للإبلاغ أو حظر المستخدم.',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
            ]))),
          ]),
        ]),
      )));
  }
}


class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}
class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 720),
  )..repeat(reverse: true);
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Row(mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          final phase = ((_controller.value * 3) - index * 0.55).clamp(0.0, 1.0).toDouble();
          return Container(width: 5, height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.35 + phase * 0.65),
              shape: BoxShape.circle));
        })),
    );
  }
}

class _ChatRetentionNotice extends StatelessWidget {
  const _ChatRetentionNotice();

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFFC66D);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.schedule_rounded, size: 13, color: accent),
              SizedBox(width: 5),
              Text('سوف يتم حذف الدردشة في غضون يومين',
                style: TextStyle(color: Color(0xFFFFD18A), fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _StudyChatWallpaperPainter extends CustomPainter {
  final bool dark;
  const _StudyChatWallpaperPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final ink = dark ? const Color(0xFF8FA9D0) : const Color(0xFF55749B);
    final opacity = dark ? 0.19 : 0.14;
    final icons = <IconData>[
      Icons.menu_book_outlined,
      Icons.science_outlined,
      Icons.school_outlined,
      Icons.edit_outlined,
      Icons.lightbulb_outline_rounded,
      Icons.calculate_outlined,
      Icons.auto_stories_outlined,
      Icons.straighten_outlined,
      Icons.biotech_outlined,
      Icons.book_outlined,
      Icons.functions_rounded,
      Icons.draw_outlined,
    ];
    final cellWidth = size.width / 2.35;
    final cellHeight = size.height / 4.15;
    final iconStyle = TextStyle(
      fontFamily: 'MaterialIcons',
      color: ink.withValues(alpha: opacity),
      fontSize: (size.width * 0.105).clamp(30.0, 54.0).toDouble(),
    );
    final decorationStyle = TextStyle(
      color: ink.withValues(alpha: opacity * 0.92),
      fontSize: 25,
      fontWeight: FontWeight.w300,
    );

    // Staggered school-themed doodles based on the supplied reference image.
    for (var row = 0; row < 5; row++) {
      for (var col = 0; col < 3; col++) {
        final index = (row * 3 + col) % icons.length;
        final x = col * cellWidth + (row.isOdd ? cellWidth * 0.28 : 8);
        final y = row * cellHeight + 12;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(((row + col).isEven ? -1 : 1) * 0.13);
        final iconPainter = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icons[index].codePoint),
            style: iconStyle,
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        iconPainter.paint(canvas, Offset.zero);
        canvas.restore();

        final ornament = ['☆', '+', '÷', '×', '·', '⌁'][(row * 2 + col) % 6];
        final ornamentPainter = TextPainter(
          text: TextSpan(text: ornament, style: decorationStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        ornamentPainter.paint(
          canvas,
          Offset(x + cellWidth * 0.62, y + cellHeight * 0.53),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StudyChatWallpaperPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

class StudentDirectInboxPreferences {
  static String _key(String userId, String kind) =>
      'student_dm_${kind}_v1_$userId';

  static Future<Set<String>> _read(String userId, String kind) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key(userId, kind)) ?? const <String>[]).toSet();
  }

  static Future<void> _write(String userId, String kind, Set<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(userId, kind), values.toList());
  }

  static Future<bool> isMuted(String? otherUserId) async {
    final me = _db.auth.currentUser?.id;
    if (me == null || otherUserId == null || otherUserId.isEmpty) return false;
    return (await _read(me, 'muted')).contains(otherUserId);
  }

  static Future<void> setMuted(String userId, String otherId, bool value) async {
    final values = await _read(userId, 'muted');
    value ? values.add(otherId) : values.remove(otherId);
    await _write(userId, 'muted', values);
  }

  static Future<void> setPinned(String userId, String otherId, bool value) async {
    final values = await _read(userId, 'pinned');
    value ? values.add(otherId) : values.remove(otherId);
    await _write(userId, 'pinned', values);
  }

  static Future<void> hideConversation(String userId, String otherId) async {
    final values = await _read(userId, 'hidden');
    values.add(otherId);
    await _write(userId, 'hidden', values);
  }

  static Future<Set<String>> pinned(String userId) => _read(userId, 'pinned');
  static Future<Set<String>> muted(String userId) => _read(userId, 'muted');
  static Future<Set<String>> hidden(String userId) => _read(userId, 'hidden');
}

/// Current private conversation, used to suppress duplicate live banners while it is open.
final ValueNotifier<String?> activeDirectMessageUserId = ValueNotifier<String?>(null);

class StudentDirectInboxScreen extends StatefulWidget {
  const StudentDirectInboxScreen({super.key});
  @override State<StudentDirectInboxScreen> createState() => _StudentDirectInboxScreenState();
}

class _StudentDirectInboxScreenState extends State<StudentDirectInboxScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  List<Map<String,dynamic>> _conversations = [];
  bool _hasInboxCache = false;
  String get _inboxCacheKey => 'dalilak_private_inbox_$_me';

  Future<void> _loadInboxCache() async {
    final me = _me;
    if (me == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_inboxCacheKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final cached = decoded.whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row)).toList();
        if (mounted && cached.isNotEmpty) {
          setState(() {
            _conversations = cached;
            _loading = false;
            _hasInboxCache = true;
            _error = null;
          });
        }
      }
    } catch (error) {
      debugPrint('Read private inbox cache failed: $error');
    }
  }

  Future<void> _saveInboxCache(List<Map<String, dynamic>> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_inboxCacheKey, jsonEncode(rows));
    } catch (error) {
      debugPrint('Save private inbox cache failed: $error');
    }
  }
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;
  String? _selectedConversationId;
  String? get _me => _client.auth.currentUser?.id;

  @override void initState() {
    super.initState();
    unawaited(_loadInboxCache());
    _load();
    final me = _me;
    if (me != null) {
      _channel = _client.channel('private-inbox-$me')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direct_messages',
          callback: (_) => _load(),
        ).subscribe();
    }
  }

  Future<void> _load() async {
    final me = _me;
    if (me == null) {
      if (mounted) setState(() { _loading = false; _error = 'سجّل الدخول أولاً.'; });
      return;
    }
    try {
      final raw = await _client.from('direct_messages')
        .select('id,sender_id,receiver_id,body,created_at,read_at')
        .or('sender_id.eq.$me,receiver_id.eq.$me')
        .order('created_at', ascending: false);
      final messages = (raw as List).whereType<Map>()
        .map((row) => Map<String,dynamic>.from(row)).toList();
      final ids = <String>{};
      for (final row in messages) {
        final other = row['sender_id'] == me ? row['receiver_id'] : row['sender_id'];
        if (other != null && other.toString() != me) ids.add(other.toString());
      }
      final profiles = <String,Map<String,dynamic>>{};
      if (ids.isNotEmpty) {
        final rows = await _client.rpc('get_student_chat_profiles_v1',
          params: {'p_user_ids': ids.toList()});
        for (final row in (rows as List).whereType<Map>()) {
          final profile = Map<String,dynamic>.from(row);
          profiles[profile['user_id'].toString()] = profile;
        }
      }
      final hidden = await StudentDirectInboxPreferences.hidden(me);
      final pinned = await StudentDirectInboxPreferences.pinned(me);
      final muted = await StudentDirectInboxPreferences.muted(me);
      final grouped = <String,Map<String,dynamic>>{};
      for (final row in messages) {
        final other = (row['sender_id'] == me ? row['receiver_id'] : row['sender_id']).toString();
        if (hidden.contains(other)) continue;
        final item = grouped.putIfAbsent(other, () => {
          'user_id': other,
          'last': row,
          'unread': 0,
          'profile': profiles[other] ?? <String,dynamic>{},
          'pinned': pinned.contains(other),
          'muted': muted.contains(other),
        });
        if (row['receiver_id'] == me && row['read_at'] == null) {
          item['unread'] = (item['unread'] as int) + 1;
        }
      }
      final result = grouped.values.toList()
        ..sort((a,b) {
          final pinOrder = (b['pinned'] == true ? 1 : 0).compareTo(a['pinned'] == true ? 1 : 0);
          if (pinOrder != 0) return pinOrder;
          return (b['last']['created_at'] as String)
            .compareTo(a['last']['created_at'] as String);
        });
      if (mounted) {
        setState(() {
          _conversations = result;
        _loading = false;
        _error = null;
          _hasInboxCache = true;
        });
      }
      await _saveInboxCache(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
        _error = _conversations.isEmpty && !_hasInboxCache
            ? 'ليس متصلاً بالإنترنت، ولا توجد محادثات محفوظة على هذا الجهاز بعد.'
            : null;
        });
      }
    }
  }

  String _time(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
    }
    return '${date.day}/${date.month}';
  }

  Future<void> _togglePin() async {
    final me = _me, other = _selectedConversationId;
    if (me == null || other == null) return;
    final item = _conversations.firstWhere((e) => e['user_id'].toString() == other);
    final pinned = item['pinned'] == true;
    await StudentDirectInboxPreferences.setPinned(me, other, !pinned);
    if (!mounted) return;
    setState(() => _selectedConversationId = null);
    await _load();
  }

  Future<void> _toggleMute() async {
    final me = _me, other = _selectedConversationId;
    if (me == null || other == null) return;
    final item = _conversations.firstWhere((e) => e['user_id'].toString() == other);
    final muted = item['muted'] == true;
    await StudentDirectInboxPreferences.setMuted(me, other, !muted);
    if (!mounted) return;
    setState(() => _selectedConversationId = null);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            muted ? 'تم إلغاء كتم المحادثة.' : 'تم كتم إشعارات هذه المحادثة على هذا الجهاز.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteConversation() async {
    final me = _me, other = _selectedConversationId;
    if (me == null || other == null) return;
    final item = _conversations.firstWhere((e) => e['user_id'].toString() == other);
    final profile = item['profile'] as Map<String,dynamic>;
    final name = profile['display_name']?.toString().trim().isNotEmpty == true
      ? profile['display_name'].toString() : 'هذا المستخدم';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_sweep_outlined),
        title: const Text('حذف المحادثة؟'),
        content: Text('سيتم إخفاء محادثة $name من قائمتك فقط. لن تُحذف رسائل الطرف الآخر أو حسابه.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف المحادثة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await StudentDirectInboxPreferences.hideConversation(me, other);
    if (!mounted) return;
    setState(() => _selectedConversationId = null);
    await _load();
  }

  @override void dispose() {
    if (_channel != null) _client.removeChannel(_channel!);
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Map<String, dynamic>? selected;
    if (_selectedConversationId != null) {
      for (final item in _conversations) {
        if (item['user_id'].toString() == _selectedConversationId) {
          selected = item;
          break;
        }
      }
    }
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(
        title: Text(_selectedConversationId == null ? 'المحادثات الخاصة' : 'إجراءات المحادثة'),
        leading: _selectedConversationId == null ? null : IconButton(
          tooltip: 'إلغاء التحديد',
          onPressed: () => setState(() => _selectedConversationId = null),
          icon: const Icon(Icons.close_rounded),
        ),
        actions: selected == null ? null : [
          IconButton(
            tooltip: selected['pinned'] == true ? 'إلغاء التثبيت' : 'تثبيت بالأعلى',
            onPressed: _togglePin,
            icon: Icon(selected['pinned'] == true ? Icons.push_pin_rounded : Icons.push_pin_outlined),
          ),
          IconButton(
            tooltip: selected['muted'] == true ? 'إلغاء الكتم' : 'كتم الإشعارات',
            onPressed: _toggleMute,
            icon: Icon(selected['muted'] == true ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
          ),
          IconButton(
            tooltip: 'حذف المحادثة',
            onPressed: _deleteConversation,
            icon: Icon(Icons.delete_outline_rounded, color: colors.error),
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Column(
              mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
              ])))
          : _conversations.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(
                mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.forum_outlined, size: 54, color: colors.primary),
                  const SizedBox(height: 12),
                  const Text('ما عندك محادثات خاصة بعد', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 6),
                  Text('ابدأ محادثة من الملف الشخصي لأي طالب', style: TextStyle(color: colors.onSurfaceVariant)),
                ])))
            : RefreshIndicator(onRefresh: _load, child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _conversations.length,
                separatorBuilder: (_,__) => const Divider(height: 1, indent: 82),
                itemBuilder: (context,index) {
                  final item = _conversations[index];
                  final profile = item['profile'] as Map<String,dynamic>;
                  final last = item['last'] as Map<String,dynamic>;
                  final userId = item['user_id'].toString();
                  final avatar = profile['avatar_url']?.toString();
                  final displayName = profile['display_name']?.toString().trim() ?? '';
                  final usernameValue = profile['username']?.toString().trim() ?? '';
                  final name = displayName.isNotEmpty ? displayName : (usernameValue.isNotEmpty ? '@$usernameValue' : 'مستخدم');
                  final username = (profile['username'] ?? '').toString();
                  final unread = item['unread'] as int;
                  final isSelected = _selectedConversationId == userId;
                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: colors.primary.withValues(alpha: 0.10),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    leading: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => StudentPublicProfileScreen(
                          userId: userId,
                          fallbackName: name,
                          fallbackUsername: username,
                          fallbackStage: profile['stage']?.toString(),
                          fallbackAvatar: avatar,
                          fallbackBadge: profile['badge']?.toString(),
                          fallbackBio: profile['bio']?.toString(),
                          fallbackDeveloper: profile['is_developer'] == true,
                        ),
                      )),
                      child: CircleAvatar(
                        radius: 25,
                        backgroundImage: avatar != null && avatar.startsWith('http') ? NetworkImage(avatar) : null,
                        child: avatar == null || !avatar.startsWith('http') ? const Icon(Icons.person_rounded) : null,
                      ),
                    ),
                    title: Row(children: [
                      Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                      if (item['pinned'] == true) const Padding(
                        padding: EdgeInsets.only(left: 5),
                        child: Icon(Icons.push_pin_rounded, size: 14, color: Color(0xFF5EA7FF)),
                      ),
                      if (item['muted'] == true) const Padding(
                        padding: EdgeInsets.only(left: 5),
                        child: Icon(Icons.notifications_off_outlined, size: 14),
                      ),
                      Text(_time(last['created_at']), style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                    ]),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (username.isNotEmpty) Text('@$username', style: TextStyle(fontSize: 11, color: colors.primary)),
                      const SizedBox(height: 3),
                      Text(last['body']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                    trailing: unread > 0 ? CircleAvatar(
                      radius: 12, backgroundColor: colors.primary,
                      child: Text(unread > 99 ? '99+' : '$unread',
                        style: TextStyle(color: colors.onPrimary, fontSize: 10, fontWeight: FontWeight.w900)),
                    ) : const Icon(Icons.chevron_left_rounded),
                    onLongPress: () => setState(() => _selectedConversationId = userId),
                    onTap: () {
                      if (_selectedConversationId != null) {
                        setState(() => _selectedConversationId = userId);
                        return;
                      }
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => StudentDirectMessageScreen(
                          otherUserId: userId, otherName: name, otherAvatar: avatar,
                        ),
                      )).then((_) => _load());
                    },
                  );
                },
              )),
    ));
  }
}
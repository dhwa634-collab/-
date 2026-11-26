// ignore_for_file: deprecated_member_use

import 'dart:async';
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
    final color = onPrimary
        ? Colors.white
        : Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: 'حساب المطوّر الرسمي',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 8,
          vertical: compact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: onPrimary ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: onPrimary ? 0.55 : 0.28)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified_rounded, size: compact ? 13 : 16, color: color),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text('المطوّر', style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800,
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
        content: Text('فشل تسجيل الدخول (${error.runtimeType}): $message'),
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
            Stack(alignment:Alignment.bottomLeft,children:[
              Container(padding:const EdgeInsets.all(4),decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:Colors.white,width:3)),child:CircleAvatar(radius:48,backgroundImage:avatar,child:avatar==null?const Icon(Icons.person,size:48,color:Colors.white):null)),
              IconButton.filled(onPressed:uploading?null:pickAvatar,style:IconButton.styleFrom(backgroundColor:Colors.white,foregroundColor:c.primary),icon:uploading?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.camera_alt)),
            ]),
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
class StudentDirectMessageScreen extends StatefulWidget{
  final String otherUserId,otherName;final String? otherAvatar;
  const StudentDirectMessageScreen({super.key,required this.otherUserId,required this.otherName,this.otherAvatar});
  @override State<StudentDirectMessageScreen> createState()=>_StudentDirectMessageScreenState();
}
class _StudentDirectMessageScreenState extends State<StudentDirectMessageScreen>{
  final input=TextEditingController();late final Stream<List<Map<String,dynamic>>> messages;late final StreamSubscription<List<Map<String,dynamic>>> blockSubscription;bool sending=false,blocked=false;String? get me=>_db.auth.currentUser?.id;
  late final StreamSubscription<List<Map<String,dynamic>>> messageSubscription;
  late String _resolvedOtherName;
  @override void initState(){super.initState();_resolvedOtherName=widget.otherName;_loadOtherProfileName();activeDirectMessageUserId.value=widget.otherUserId;messages=stream();messageSubscription=messages.listen((_)=>markIncomingAsRead());blockSubscription=_db.from('user_blocks').stream(primaryKey:['blocker_id','blocked_id']).listen((rows){final user=me;final next=user==null||rows.any((r)=>(r['blocker_id']==user&&r['blocked_id']==widget.otherUserId)||(r['blocker_id']==widget.otherUserId&&r['blocked_id']==user));if(mounted&&blocked!=next)setState(()=>blocked=next);});refreshBlockStatus();markIncomingAsRead();}
  Future<void> _loadOtherProfileName() async {
    try {
      final profile = await _db.from('profiles')
        .select('display_name,username')
        .eq('user_id', widget.otherUserId).maybeSingle();
      final displayName = profile?['display_name']?.toString().trim() ?? '';
      final username = profile?['username']?.toString().trim() ?? '';
      final resolved = displayName.isNotEmpty
        ? displayName : (username.isNotEmpty ? '@$username' : widget.otherName);
      if (mounted && resolved.isNotEmpty && resolved != _resolvedOtherName) {
        setState(() => _resolvedOtherName = resolved);
      }
    } catch (error) {
      debugPrint('Load private chat participant profile failed: $error');
    }
  }
  Stream<List<Map<String,dynamic>>> stream()=>_db.from('direct_messages').stream(primaryKey:['id']).order('created_at').map((items){final seen=<String>{};return items.where((r)=>((r['sender_id']==me&&r['receiver_id']==widget.otherUserId)||(r['sender_id']==widget.otherUserId&&r['receiver_id']==me))&&seen.add(r['id'].toString())).toList();});
  Future<bool> refreshBlockStatus()async{final user=me;if(user==null)return true;try{final rows=await _db.from('user_blocks').select('blocker_id,blocked_id').or('and(blocker_id.eq.$user,blocked_id.eq.${widget.otherUserId}),and(blocker_id.eq.${widget.otherUserId},blocked_id.eq.$user)');final value=(rows as List).isNotEmpty;if(mounted)setState(()=>blocked=value);return value;}catch(_){return blocked;}}
  Future<void> markIncomingAsRead()async{final user=me;if(user==null)return;try{await _db.rpc('mark_direct_messages_read',params:{'p_sender_id':widget.otherUserId});}catch(error){debugPrint('Mark private messages read failed: $error');}}
  Future<void> send()async{final v=input.text.trim();final user=me;if(v.isEmpty||user==null||sending)return;if(v.length>2000){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('الرسالة طويلة جداً.')));return;}FocusScope.of(context).unfocus();setState(()=>sending=true);try{if(await refreshBlockStatus()){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('لا يمكن إرسال الرسائل بسبب وجود حظر بين الحسابين.')));return;}await _db.from('direct_messages').insert({'sender_id':user,'receiver_id':widget.otherUserId,'body':v});input.clear();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر إرسال الرسالة: $e')));}finally{if(mounted)setState(()=>sending=false);}}
  @override void dispose(){activeDirectMessageUserId.value=null;messageSubscription.cancel();blockSubscription.cancel();input.dispose();super.dispose();}
  @override Widget build(BuildContext context){final c=Theme.of(context).colorScheme;return Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:Text(_resolvedOtherName)),body:Column(children:[
    Expanded(child:StreamBuilder<List<Map<String,dynamic>>>(stream:messages,builder:(ctx,s){if(s.hasError)return Center(child:Text('تعذر تحميل المحادثة: ${s.error}'));if(!s.hasData)return const Center(child:CircularProgressIndicator());final l=s.data!;if(l.isEmpty)return const Center(child:Text('ابدأ المحادثة برسالة ترحيبية 👋'));return ListView.builder(reverse:true,padding:const EdgeInsets.all(14),itemCount:l.length,itemBuilder:(ctx,i){final r=l[l.length-1-i];final mine=r['sender_id']==me;return Align(alignment:mine?Alignment.centerRight:Alignment.centerLeft,child:Container(margin:const EdgeInsets.symmetric(vertical:4),padding:const EdgeInsets.all(12),constraints:const BoxConstraints(maxWidth:300),decoration:BoxDecoration(color:mine?c.primary:c.surfaceContainerHighest,borderRadius:BorderRadius.circular(16)),child:Row(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.end,children:[Flexible(child:Text(r['body']?.toString()??'',style:TextStyle(color:mine?c.onPrimary:c.onSurface))),if(mine)...[const SizedBox(width:7),Icon(r['read_at']!=null?Icons.done_all_rounded:Icons.done_rounded,size:15,color:r['read_at']!=null?Colors.lightBlueAccent:(mine?c.onPrimary.withValues(alpha:.72):c.onSurfaceVariant))]])));});})),
    if(blocked)const Padding(padding:EdgeInsets.fromLTRB(14,6,14,0),child:Text('المراسلة متوقفة بسبب الحظر بين الحسابين.',style:TextStyle(color:Color(0xFFB87922)))),
    SafeArea(top:false,child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[Expanded(child:TextField(controller:input,enabled:!blocked,minLines:1,maxLines:4,textInputAction:TextInputAction.send,onSubmitted:(_)=>send(),decoration:InputDecoration(hintText:blocked?'المراسلة غير متاحة بسبب الحظر':'اكتب رسالتك...',filled:true,border:OutlineInputBorder(borderRadius:BorderRadius.circular(24),borderSide:BorderSide.none)))),IconButton.filled(onPressed:sending||blocked?null:send,icon:sending?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.send))]))),
  ])));}
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('غرفة الدردشة',
              style: TextStyle(fontWeight: FontWeight.w800)),
            Text('محادثة جماعية للطلاب',
              style: TextStyle(fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), Color(0xFFDCEAFF), Color(0xFFF2F7FF)],
          ),
        ),
        child: Stack(children: [
          const Positioned.fill(child: IgnorePointer(child: CustomPaint(
            painter: _StudyChatWallpaperPainter(),
          ))),
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
                  final mine = row['user_id']?.toString() == _db.auth.currentUser?.id;
                  final profile = profiles.data?[row['user_id'].toString()];
                  final currentUser = _db.auth.currentUser;
                  final currentUserMetadata =
                      currentUser?.userMetadata ?? const <String, dynamic>{};
                  final name = (profile?['display_name'] ??
                    (mine ? (currentUserMetadata['full_name'] ??
                      currentUserMetadata['name'] ??
                      currentUser?.email?.split('@').first) : null) ??
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

                  return Align(
                    alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
                    child: GestureDetector(
                      onLongPress: () => _messageActions(row),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
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
                              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
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
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.15,
                                      fontWeight: FontWeight.w800,
                                      color: bubbleNameColor,
                                    ),
                                  ),
                                  if (isDeveloper) ...[
                                    const SizedBox(width: 5),
                                    _DeveloperBadge(compact: true, onPrimary: mine),
                                  ],
                                ]),
                                const SizedBox(height: 3),
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
                                      if (mine) ...[
                                        const SizedBox(width: 3),
                                        Icon(Icons.done_rounded, size: 12,
                                          color: colors.onSurfaceVariant),
                                      ],
                                  ],
                                ),
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
              SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal,
                children: stickers.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ActionChip(label: Text(e.value, style: const TextStyle(fontSize: 20)),
                    onPressed: sending ? null : () => send(sticker: e.key)),
                )).toList())),
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
                    tooltip: _recording ? 'إلغاء التسجيل' : 'إرفاق صورة أو ملصق',
                    onPressed: sending ? null : (_recording
                      ? () => _stopVoiceRecording(send: false)
                      : () {
                          showModalBottomSheet<void>(
                            context: context,
                            builder: (sheetContext) => SafeArea(
                              child: Wrap(children: [
                                ListTile(
                                  leading: const Icon(Icons.image_outlined),
                                  title: const Text('إرسال صورة'),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _pickAndSendImage();
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.add_photo_alternate_outlined),
                                  title: const Text('إضافة ملصق من الجهاز'),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _pickCustomSticker();
                                  },
                                ),
                              ]),
                            ),
                          );
                        }),
                    icon: Icon(_recording ? Icons.close_rounded : Icons.attach_file_rounded, size: 25),
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 54, maxHeight: 118),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF17191B),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: input,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 500,
                              textAlignVertical: TextAlignVertical.center,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                              decoration: const InputDecoration(
                                hintText: 'الرسالة',
                                hintStyle: TextStyle(color: Colors.white54, fontSize: 15),
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
                            onPressed: () {
                              const emojis = ['😀','😂','🥰','😍','❤️','👍','🙏','🔥','🎯','📚','🌟','👏'];
                              showModalBottomSheet<void>(
                                context: context,
                                builder: (sheetContext) => SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: emojis.map((emoji) => InkWell(
                                        onTap: () {
                                          final old = input.value;
                                          final selection = old.selection;
                                          final start = selection.isValid ? selection.start : old.text.length;
                                          final finish = selection.isValid ? selection.end : old.text.length;
                                          final text = old.text.replaceRange(start, finish, emoji);
                                          input.value = TextEditingValue(
                                            text: text,
                                            selection: TextSelection.collapsed(offset: start + emoji.length),
                                          );
                                          Navigator.pop(sheetContext);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(5),
                                          child: Text(emoji, style: const TextStyle(fontSize: 27)),
                                        ),
                                      )).toList(),
                                    ),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white70, size: 25),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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


class _StudyChatWallpaperPainter extends CustomPainter {
  const _StudyChatWallpaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF477DBB).withValues(alpha: 0.075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;
    final symbols = <String>['✎', '▱', '△', '⌁', '▤'];
    for (var i = 0; i < 18; i++) {
      final x = (i % 4) * (size.width / 3.6) + 12;
      final y = (i ~/ 4) * 145.0 + 32;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((i.isEven ? -1 : 1) * 0.16);
      final tp = TextPainter(
        text: TextSpan(
          text: symbols[i % symbols.length],
          style: TextStyle(
            fontSize: i.isEven ? 31 : 25,
            color: const Color(0xFF477DBB).withValues(alpha: 0.075),
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset.zero);
      canvas.drawCircle(const Offset(8, 8), 2.2, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _StudyChatWallpaperPainter oldDelegate) => false;
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
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;
  String? get _me => _client.auth.currentUser?.id;

  @override void initState() {
    super.initState();
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
        final rows = await _client.from('profiles')
          .select('user_id,display_name,username,avatar_url,badge')
          .inFilter('user_id', ids.toList());
        for (final row in (rows as List).whereType<Map>()) {
          final profile = Map<String,dynamic>.from(row);
          profiles[profile['user_id'].toString()] = profile;
        }
      }
      final grouped = <String,Map<String,dynamic>>{};
      for (final row in messages) {
        final other = (row['sender_id'] == me ? row['receiver_id'] : row['sender_id']).toString();
        final item = grouped.putIfAbsent(other, () => {
          'user_id': other,
          'last': row,
          'unread': 0,
          'profile': profiles[other] ?? <String,dynamic>{},
        });
        if (row['receiver_id'] == me && row['read_at'] == null) {
          item['unread'] = (item['unread'] as int) + 1;
        }
      }
      final result = grouped.values.toList()
        ..sort((a,b) => (b['last']['created_at'] as String)
          .compareTo(a['last']['created_at'] as String));
      if (mounted) setState(() { _conversations = result; _loading = false; _error = null; });
    } catch (error) {
      if (mounted) setState(() { _loading = false; _error = 'تعذر تحميل صندوق الوارد: $error'; });
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

  @override void dispose() {
    if (_channel != null) _client.removeChannel(_channel!);
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('المحادثات الخاصة')),
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
                  final displayName = profile['display_name']?.toString().trim() ?? '';\n                  final usernameValue = profile['username']?.toString().trim() ?? '';\n                  final name = displayName.isNotEmpty ? displayName : (usernameValue.isNotEmpty ? '@$usernameValue' : 'مستخدم');
                  final username = (profile['username'] ?? '').toString();
                  final unread = item['unread'] as int;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundImage: avatar != null && avatar.startsWith('http') ? NetworkImage(avatar) : null,
                      child: avatar == null || !avatar.startsWith('http') ? const Icon(Icons.person_rounded) : null,
                    ),
                    title: Row(children: [
                      Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800))),
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
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => StudentDirectMessageScreen(
                        otherUserId: userId, otherName: name, otherAvatar: avatar,
                      ),
                    )).then((_) => _load()),
                  );
                },
              )),
    ));
  }
}

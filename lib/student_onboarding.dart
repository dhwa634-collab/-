// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'academic_stages.dart';
import 'student_community.dart';

/// Routes signed-out users to the welcome screen and authenticated users
/// according to the completeness of their server-side student profile.
class StudentOnboardingGate extends StatefulWidget {
  final Widget child;
  const StudentOnboardingGate({super.key, required this.child});

  @override
  State<StudentOnboardingGate> createState() => _StudentOnboardingGateState();
}

class _StudentOnboardingGateState extends State<StudentOnboardingGate> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _loading = true;
  bool _needsSetup = false;
  bool _signedIn = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _authSubscription = _client.auth.onAuthStateChange.listen((_) {
      _refreshDestination();
    });
    _refreshDestination();
  }

  Future<void> _refreshDestination() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _signedIn = false;
          _needsSetup = false;
          _loading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _signedIn = true;
        _loading = true;
      });
    }

    try {
      final row = await _client.from('profiles')
          .select('display_name,username,stage,age')
          .eq('user_id', user.id)
          .maybeSingle();
      final name = (row?['display_name'] ?? '').toString().trim();
      final username = (row?['username'] ?? '').toString().trim();
      final stage = (row?['stage'] ?? '').toString().trim();
      final ageValue = row?['age'];
      final age = ageValue is int ? ageValue : int.tryParse('$ageValue');
      final complete = row != null && name.isNotEmpty &&
          username.isNotEmpty && stage.isNotEmpty &&
          age != null && age >= 10 && age <= 80;
      if (!mounted) return;
      setState(() {
        _needsSetup = !complete;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _needsSetup = true;
        _loading = false;
      });
    }
  }

  void _finish() {
    _refreshDestination();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_signedIn) return const StudentWelcomeScreen();
    if (_needsSetup) {
      return StudentFirstRunSetup(onComplete: _finish);
    }
    return widget.child;
  }
}

class StudentWelcomeScreen extends StatelessWidget {
  const StudentWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2868D7);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF0A1424), Color(0xFF142D50), Color(0xFF101B31)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(26),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(34),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4389F5), Color(0xFF173D73)],
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x552868D7), blurRadius: 34, spreadRadius: 2),
                          ],
                        ),
                        child: const Icon(Icons.school_rounded, color: Colors.white, size: 62),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'دليلك للنجاح',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'كل ما تحتاجه لرحلتك الدراسية في مكان واحد',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFD4E1F5), fontSize: 15, height: 1.7),
                      ),
                      const SizedBox(height: 38),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const StudentGoogleLoginScreen(returnToCaller: true),
                              ),
                            );
                          },
                          icon: const Icon(Icons.g_mobiledata_rounded, size: 32),
                          label: const Text(
                            'تسجيل الدخول بحساب Google',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'سجّل الدخول حتى نحفظ بياناتك الدراسية ونجهّز حسابك.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFB8C8DF), fontSize: 12, height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      const Icon(Icons.lock_outline_rounded, color: Color(0xFF91A9C9), size: 18),
                      const SizedBox(height: 6),
                      const Text('تسجيل آمن عبر Google', style: TextStyle(color: Color(0xFF91A9C9), fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StudentFirstRunSetup extends StatefulWidget {
  final VoidCallback onComplete;
  const StudentFirstRunSetup({super.key, required this.onComplete});

  @override
  State<StudentFirstRunSetup> createState() => _StudentFirstRunSetupState();
}

class _StudentFirstRunSetupState extends State<StudentFirstRunSetup> {
  static const _stages = <String>[
    'السادس الابتدائي',
    'الثالث المتوسط',
    'السادس العلمي',
    'السادس الأدبي',
    'الثالث المتوسط المهني',
    'السادس المهني',
  ];

  final _pages = PageController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _picker = ImagePicker();

  final _ageController = TextEditingController();
  String _gender = 'male';
  String _stage = 'الثالث المتوسط';
  String _usernameState = 'أدخل اسم مستخدم باللغة الإنجليزية';
  String? _avatarUrl;
  Uint8List? _avatarBytes;
  bool _guest = false;
  bool _busy = false;
  bool _usernameChecking = false;
  bool? _usernameAvailable;
  int _usernameRequest = 0;
  int _page = 0;
  Timer? _usernameDebounce;

  SupabaseClient get _client => Supabase.instance.client;
  User? get _user => _client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    final metadata = _user?.userMetadata ?? {};
    _nameController.text =
        (metadata['full_name'] ?? metadata['name'] ?? '').toString().trim();
    _avatarUrl = metadata['picture']?.toString();
    if (_user != null) {
      _usernameState = 'اكتب اسم المستخدم للتحقق من توفره';
    }
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _pages.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  bool get _isDeveloperEmail =>
      (_user?.email ?? '').trim().toLowerCase() == 'dhwa44430@gmail.com';

  bool _validUsername(String value) {
    final username = value.trim();
    if (username == '1') return _isDeveloperEmail;
    return RegExp(r'^[a-z0-9_]{3,20}
    _usernameAvailable = null;
    if (value.trim().isEmpty) {
      setState(() => _usernameState = 'أدخل اسم مستخدم باللغة الإنجليزية');
      return;
    }
    if (!_validUsername(value)) {
      setState(() {
        _usernameState = 'استخدم 3–20 خانة من a-z و0-9 و_؛ المعرّف 1 للمطوّر فقط';
      });
      return;
    }
    if (_user == null) {
      setState(() => _usernameState = 'سجّل عبر Google حتى نتحقق من التوفر');
      return;
    }
    setState(() {
      _usernameChecking = true;
      _usernameState = 'جارٍ التحقق من توفر الاسم...';
    });
    _usernameDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _checkUsername(),
    );
  }

  Future<bool> _checkUsername() async {
    final username = _usernameController.text.trim();
    if (!_validUsername(username) || _user == null) {
      if (mounted) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = false;
          _usernameState = 'اسم المستخدم غير صالح أو يلزم تسجيل الدخول';
        });
      }
      return false;
    }
    final request = ++_usernameRequest;
    try {
      final available = await _client.rpc(
        'is_student_username_available_v1',
        params: {'p_username': username},
      ) as bool;
      if (!mounted || request != _usernameRequest ||
          username != _usernameController.text.trim()) {
        return false;
      }
      setState(() {
        _usernameChecking = false;
        _usernameAvailable = available;
        _usernameState = available
            ? 'اسم المستخدم متاح ✓'
            : 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
      });
      return available;
    } catch (_) {
      if (mounted && request == _usernameRequest) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = null;
          _usernameState = 'تعذر التحقق الآن. تحقق من الاتصال وحاول مجدداً';
        });
      }
      return false;
    }
  }

  Future<bool> _ensureGoogleAccount() async {
    if (_user != null) return true;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudentGoogleLoginScreen()),
    );
    if (!mounted) return false;
    final user = _user;
    if (user == null) return false;

    final metadata = user.userMetadata ?? {};
    if (_nameController.text.trim().isEmpty) {
      _nameController.text =
          (metadata['full_name'] ?? metadata['name'] ?? '').toString().trim();
    }
    _avatarUrl ??= metadata['picture']?.toString();
    setState(() {
      _usernameState = _usernameController.text.trim().isEmpty
          ? 'اكتب اسم المستخدم للتحقق من توفره'
          : 'جارٍ التحقق من توفر الاسم...';
    });
    if (_usernameController.text.trim().isNotEmpty) {
      return _checkUsername();
    }
    return true;
  }

  Future<void> _continueIdentity() async {
    if (_busy) return;
    if (!await _ensureGoogleAccount()) return;
    if (!mounted) return;
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 40) {
      _message('اكتب اسم العرض (من حرف إلى 40 حرفاً).');
      return;
    }
    if (!_usernameFormatValid) {
      _message('اسم المستخدم 3–20 خانة، أو 1 لحساب المطوّر المحدد فقط.');
      return;
    }
    final available = _usernameAvailable == true
        ? true
        : await _checkUsername();
    if (!available || !mounted) return;
    _goTo(1);
  }

  void _continueAsGuest() {
    if (_busy) return;
    setState(() {
      _guest = true;
      _avatarBytes = null;
    });
    _goTo(2);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarUrl = null;
      });
    } catch (_) {
      if (mounted) _message('تعذر اختيار الصورة. حاول مرة ثانية.');
    }
  }

  Future<String?> _uploadAvatar(User user) async {
    final bytes = _avatarBytes;
    if (bytes == null) return _avatarUrl;
    final path = '${user.id}/onboarding-${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  AcademicStage _mappedAcademicStage() {
    switch (_stage) {
      case 'السادس الابتدائي':
        return AcademicStage.primarySixth;
      case 'الثالث المتوسط':
      case 'الثالث المتوسط المهني':
        return AcademicStage.intermediateThird;
      case 'السادس العلمي':
      case 'السادس الأدبي':
      case 'السادس المهني':
        return AcademicStage.preparatorySixth;
      default:
        return AcademicStage.intermediateThird;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final user = _guest ? null : _user;
    if (!_guest && user == null) {
      _message('سجّل الدخول عبر Google أولاً حتى نحفظ معلومات حسابك.');
      _goTo(0);
      return;
    }
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 10 || age > 80) {
      _message('اكتب عمراً صحيحاً بين 10 و80 سنة.');
      return;
    }
    if (!_guest) {
      if (_nameController.text.trim().isEmpty ||
          _nameController.text.trim().length > 40 ||
          !_usernameFormatValid) {
        _goTo(0);
        _message('راجع الاسم واسم المستخدم قبل الحفظ.');
        return;
      }
      final available = _usernameAvailable == true
          ? true
          : await _checkUsername();
      if (!available || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dalilak_student_age_band_v1', age.toString());
      await prefs.setString('dalilak_student_gender_v1', _gender);
      await prefs.setString('dalilak_student_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_selected_academic_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_student_stage_label_v1', _stage);
      await AcademicStageController.select(_mappedAcademicStage());

      if (user != null) {
        final name = _nameController.text.trim();
        final avatar = await _uploadAvatar(user);
        await _client.from('profiles').upsert({
          'user_id': user.id,
          'display_name': name,
          'username': _usernameController.text.trim(),
          'age_band': age.toString(),
          'age': age,
          'gender': _gender,
          'stage': _stage,
          'avatar_url': avatar,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await prefs.setString('dalilak_student_display_name_v1', name);
        await prefs.setString(
          'dalilak_student_username_v1',
          _usernameController.text.trim(),
        );
      }
      await prefs.setBool('dalilak_student_onboarding_done_v1', true);
      await prefs.setBool('dalilak_home_welcome_seen_v1', true);
      if (!mounted) return;
      widget.onComplete();
    } on PostgrestException catch (error) {
      if (mounted) {
        if (error.code == '23505') {
          setState(() {
            _usernameAvailable = false;
            _usernameState = 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
            _page = 0;
          });
          await _pages.animateToPage(
            0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
          _message('هذا الاسم مستخدم من حساب آخر. اختَر اسماً مختلفاً.');
        } else {
          _message('تعذر حفظ البيانات: ${error.message}');
        }
      }
    } catch (_) {
      if (mounted) {
        _message('تعذر حفظ البيانات حالياً. تحقق من الاتصال وحاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goTo(int page) {
    if (!mounted) return;
    setState(() => _page = page);
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = scheme.primary;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: dark
                  ? const [Color(0xFF101B31), Color(0xFF172B49), Color(0xFF111827)]
                  : const [Color(0xFFEAF2FF), Color(0xFFF7F9FF), Color(0xFFE8F3F2)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      if (_page > 0)
                        IconButton.filledTonal(
                          tooltip: 'الخطوة السابقة',
                          onPressed: _busy
                              ? null
                              : () => _goTo(_page == 2 && _guest ? 0 : _page - 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      else
                        const SizedBox(width: 48),
                      const Spacer(),
                      Text(
                        'إعداد حساب الطالب',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                _StepIndicator(current: _page, accent: accent, dark: dark),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _identityStep(scheme, dark),
                      _avatarStep(scheme, dark),
                      _studyStep(scheme, dark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _identityStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.waving_hand_rounded,
            eyebrow: 'الخطوة 1 من 3',
            title: 'خلّينا نتعرّف عليك',
            subtitle: 'اختَر اسماً يميزك داخل مجتمع الطلبة.',
            scheme: scheme,
          ),
          const SizedBox(height: 22),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اسم العرض'),
                TextField(
                  controller: _nameController,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'اكتب اسمك الظاهر للطلاب',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                const _FieldCaption('اسم المستخدم بالإنجليزية'),
                TextField(
                  controller: _usernameController,
                  maxLength: 20,
                  autocorrect: false,
                  enableSuggestions: false,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  onChanged: _onUsernameChanged,
                  inputFormatters: const [],
                  decoration: InputDecoration(
                    hintText: 'مثال: student_2026',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    counterText: '',
                    suffixIcon: _usernameChecking
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameAvailable == true
                            ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                            : _usernameAvailable == false
                                ? const Icon(Icons.error_rounded, color: Colors.redAccent)
                                : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _usernameState,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: _usernameAvailable == true
                        ? Colors.green.shade700
                        : _usernameAvailable == false
                            ? Colors.redAccent
                            : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 10),
                Text(
                  'المسموح 3–20 خانة من a-z و0-9 و_، والرقم 1 مخصص لحساب المطوّر فقط.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _continueIdentity,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('متابعة'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _continueAsGuest,
            icon: const Icon(Icons.explore_outlined),
            label: const Text('الدخول كضيف ومتابعة التصفح'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'تقدر تتصفح الكتب والأدوات كضيف، وتحتاج حساب Google للمشاركة في الدردشة الجماعية.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _avatarStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.photo_camera_back_rounded,
            eyebrow: 'الخطوة 2 من 3',
            title: 'صورتك، بطريقتك',
            subtitle: 'أضف صورة تساعد زملاءك على تمييز حسابك. هذه الخطوة اختيارية.',
            scheme: scheme,
          ),
          const SizedBox(height: 26),
          _glassCard(
            dark: dark,
            child: Column(
              children: [
                Container(
                  width: 164,
                  height: 164,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: .20),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? NetworkImage(_avatarUrl!)
                            : null) as ImageProvider?,
                    child: _avatarBytes == null &&
                            (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? Icon(Icons.person_rounded, size: 72, color: scheme.onSurfaceVariant)
                        : null,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('المعرض'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('الكاميرا'),
                      ),
                    ),
                  ],
                ),
                if (_avatarBytes != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _avatarBytes = null),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('إزالة الصورة المختارة'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : () => _goTo(2),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
            child: const Text('متابعة'),
          ),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => _goTo(2),
              child: const Text('تخطي هذه الخطوة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studyStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.school_rounded,
            eyebrow: 'الخطوة 3 من 3',
            title: 'شنو صفّك الدراسي؟',
            subtitle: 'نرتّب المحتوى والمواد حسب مرحلتك.',
            scheme: scheme,
          ),
          const SizedBox(height: 18),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اختر صفك'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _stages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.35,
                  ),
                  itemBuilder: (context, index) {
                    final label = _stages[index];
                    final selected = label == _stage;
                    return InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () => setState(() => _stage = label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 190),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: selected
                              ? LinearGradient(
                                  colors: [scheme.primary, scheme.tertiary],
                                )
                              : null,
                          color: selected ? null : scheme.surface.withValues(alpha: .72),
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : scheme.outlineVariant.withValues(alpha: .8),
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected ? Icons.check_circle_rounded : Icons.school_outlined,
                              size: 20,
                              color: selected ? Colors.white : scheme.primary,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? Colors.white : scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const _FieldCaption('العمر الحقيقي'),
                TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 2,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.cake_outlined),
                    hintText: 'اكتب عمرك بالأرقام (10–80)',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                const _FieldCaption('الجنس'),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded)),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('ذكر')),
                    DropdownMenuItem(value: 'female', child: Text('أنثى')),
                  ],
                  onChanged: (value) => setState(() => _gender = value ?? _gender),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_busy ? 'جارٍ حفظ بياناتك...' : 'إنهاء وحفظ البيانات'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _stepScroll({required Widget child}) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: child,
      );

  Widget _heroHeading({
    required IconData icon,
    required String eyebrow,
    required String title,
    required String subtitle,
    required ColorScheme scheme,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Text(
                eyebrow,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.6,
              fontSize: 13,
            ),
          ),
        ],
      );

  Widget _glassCard({required bool dark, required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: (dark ? const Color(0xFF1D2D45) : Colors.white)
              .withValues(alpha: dark ? .88 : .82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (dark ? Colors.white : const Color(0xFF8EA7CA))
                .withValues(alpha: dark ? .12 : .34),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .18 : .06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      );
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final Color accent;
  final bool dark;

  const _StepIndicator({
    required this.current,
    required this.accent,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      child: Row(
        children: List.generate(5, (index) {
          if (index.isOdd) {
            final completed = index ~/ 2 < current;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 3,
                decoration: BoxDecoration(
                  color: completed ? accent : muted.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            );
          }
          final step = index ~/ 2;
          final active = step == current;
          final completed = step < current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: active ? 34 : 28,
            height: active ? 34 : 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || completed
                  ? accent
                  : (dark ? const Color(0xFF26364E) : Colors.white),
              border: Border.all(
                color: active || completed ? accent : muted,
                width: active ? 2 : 1,
              ),
            ),
            child: Center(
              child: Icon(
                completed ? Icons.check_rounded : Icons.circle,
                size: completed ? 17 : (active ? 9 : 7),
                color: active || completed
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FieldCaption extends StatelessWidget {
  final String text;
  const _FieldCaption(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );
}
).hasMatch(username);
  }

  bool get _usernameFormatValid => _validUsername(_usernameController.text);

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    _usernameAvailable = null;
    if (value.trim().isEmpty) {
      setState(() => _usernameState = 'أدخل اسم مستخدم باللغة الإنجليزية');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(value.trim())) {
      setState(() {
        _usernameState = 'استخدم a-z و0-9 والشرطة السفلية فقط (3–20 حرفاً)';
      });
      return;
    }
    if (_user == null) {
      setState(() => _usernameState = 'سجّل عبر Google حتى نتحقق من التوفر');
      return;
    }
    setState(() {
      _usernameChecking = true;
      _usernameState = 'جارٍ التحقق من توفر الاسم...';
    });
    _usernameDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _checkUsername(),
    );
  }

  Future<bool> _checkUsername() async {
    final username = _usernameController.text.trim();
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username) || _user == null) {
      if (mounted) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = false;
          _usernameState = 'اسم المستخدم غير صالح أو يلزم تسجيل الدخول';
        });
      }
      return false;
    }
    final request = ++_usernameRequest;
    try {
      final available = await _client.rpc(
        'is_student_username_available_v1',
        params: {'p_username': username},
      ) as bool;
      if (!mounted || request != _usernameRequest ||
          username != _usernameController.text.trim()) {
        return false;
      }
      setState(() {
        _usernameChecking = false;
        _usernameAvailable = available;
        _usernameState = available
            ? 'اسم المستخدم متاح ✓'
            : 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
      });
      return available;
    } catch (_) {
      if (mounted && request == _usernameRequest) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = null;
          _usernameState = 'تعذر التحقق الآن. تحقق من الاتصال وحاول مجدداً';
        });
      }
      return false;
    }
  }

  Future<bool> _ensureGoogleAccount() async {
    if (_user != null) return true;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudentGoogleLoginScreen()),
    );
    if (!mounted) return false;
    final user = _user;
    if (user == null) return false;

    final metadata = user.userMetadata ?? {};
    if (_nameController.text.trim().isEmpty) {
      _nameController.text =
          (metadata['full_name'] ?? metadata['name'] ?? '').toString().trim();
    }
    _avatarUrl ??= metadata['picture']?.toString();
    setState(() {
      _usernameState = _usernameController.text.trim().isEmpty
          ? 'اكتب اسم المستخدم للتحقق من توفره'
          : 'جارٍ التحقق من توفر الاسم...';
    });
    if (_usernameController.text.trim().isNotEmpty) {
      return _checkUsername();
    }
    return true;
  }

  Future<void> _continueIdentity() async {
    if (_busy) return;
    if (!await _ensureGoogleAccount()) return;
    if (!mounted) return;
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 40) {
      _message('اكتب اسم العرض (من حرف إلى 40 حرفاً).');
      return;
    }
    if (!_usernameFormatValid) {
      _message('اسم المستخدم يجب أن يكون إنجليزياً من 3 إلى 20 حرفاً أو رقماً أو _.');
      return;
    }
    final available = _usernameAvailable == true
        ? true
        : await _checkUsername();
    if (!available || !mounted) return;
    _goTo(1);
  }

  void _continueAsGuest() {
    if (_busy) return;
    setState(() {
      _guest = true;
      _avatarBytes = null;
    });
    _goTo(2);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarUrl = null;
      });
    } catch (_) {
      if (mounted) _message('تعذر اختيار الصورة. حاول مرة ثانية.');
    }
  }

  Future<String?> _uploadAvatar(User user) async {
    final bytes = _avatarBytes;
    if (bytes == null) return _avatarUrl;
    final path = '${user.id}/onboarding-${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  AcademicStage _mappedAcademicStage() {
    switch (_stage) {
      case 'السادس الابتدائي':
        return AcademicStage.primarySixth;
      case 'الثالث المتوسط':
      case 'الثالث المتوسط المهني':
        return AcademicStage.intermediateThird;
      case 'السادس العلمي':
      case 'السادس الأدبي':
      case 'السادس المهني':
        return AcademicStage.preparatorySixth;
      default:
        return AcademicStage.intermediateThird;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final user = _guest ? null : _user;
    if (!_guest && user == null) {
      _message('سجّل الدخول عبر Google أولاً حتى نحفظ معلومات حسابك.');
      _goTo(0);
      return;
    }
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 10 || age > 80) {
      _message('اكتب عمراً صحيحاً بين 10 و80 سنة.');
      return;
    }
    if (!_guest) {
      if (_nameController.text.trim().isEmpty ||
          _nameController.text.trim().length > 40 ||
          !_usernameFormatValid) {
        _goTo(0);
        _message('راجع الاسم واسم المستخدم قبل الحفظ.');
        return;
      }
      final available = _usernameAvailable == true
          ? true
          : await _checkUsername();
      if (!available || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final age = int.tryParse(_ageController.text.trim());
      if (age == null || age < 10 || age > 80) {
        _message('اكتب عمراً صحيحاً بين 10 و80 سنة.');
        return;
      }
      await prefs.setString('dalilak_student_age_band_v1', age.toString());
      await prefs.setString('dalilak_student_gender_v1', _gender);
      await prefs.setString('dalilak_student_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_selected_academic_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_student_stage_label_v1', _stage);
      await AcademicStageController.select(_mappedAcademicStage());

      if (user != null) {
        final name = _nameController.text.trim();
        final avatar = await _uploadAvatar(user);
        await _client.from('profiles').upsert({
          'user_id': user.id,
          'display_name': name,
          'username': _usernameController.text.trim(),
          'age_band': age.toString(),
          'age': age,
          'gender': _gender,
          'stage': _stage,
          'avatar_url': avatar,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await prefs.setString('dalilak_student_display_name_v1', name);
        await prefs.setString(
          'dalilak_student_username_v1',
          _usernameController.text.trim(),
        );
      }
      await prefs.setBool('dalilak_student_onboarding_done_v1', true);
      await prefs.setBool('dalilak_home_welcome_seen_v1', true);
      if (!mounted) return;
      widget.onComplete();
    } on PostgrestException catch (error) {
      if (mounted) {
        if (error.code == '23505') {
          setState(() {
            _usernameAvailable = false;
            _usernameState = 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
            _page = 0;
          });
          await _pages.animateToPage(
            0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
          _message('هذا الاسم مستخدم من حساب آخر. اختَر اسماً مختلفاً.');
        } else {
          _message('تعذر حفظ البيانات: ${error.message}');
        }
      }
    } catch (_) {
      if (mounted) {
        _message('تعذر حفظ البيانات حالياً. تحقق من الاتصال وحاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goTo(int page) {
    if (!mounted) return;
    setState(() => _page = page);
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = scheme.primary;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: dark
                  ? const [Color(0xFF101B31), Color(0xFF172B49), Color(0xFF111827)]
                  : const [Color(0xFFEAF2FF), Color(0xFFF7F9FF), Color(0xFFE8F3F2)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      if (_page > 0)
                        IconButton.filledTonal(
                          tooltip: 'الخطوة السابقة',
                          onPressed: _busy
                              ? null
                              : () => _goTo(_page == 2 && _guest ? 0 : _page - 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      else
                        const SizedBox(width: 48),
                      const Spacer(),
                      Text(
                        'إعداد حساب الطالب',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                _StepIndicator(current: _page, accent: accent, dark: dark),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _identityStep(scheme, dark),
                      _avatarStep(scheme, dark),
                      _studyStep(scheme, dark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _identityStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.waving_hand_rounded,
            eyebrow: 'الخطوة 1 من 3',
            title: 'خلّينا نتعرّف عليك',
            subtitle: 'اختَر اسماً يميزك داخل مجتمع الطلبة.',
            scheme: scheme,
          ),
          const SizedBox(height: 22),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اسم العرض'),
                TextField(
                  controller: _nameController,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'اكتب اسمك الظاهر للطلاب',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                const _FieldCaption('اسم المستخدم بالإنجليزية'),
                TextField(
                  controller: _usernameController,
                  maxLength: 20,
                  autocorrect: false,
                  enableSuggestions: false,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  onChanged: _onUsernameChanged,
                  inputFormatters: const [],
                  decoration: InputDecoration(
                    hintText: 'مثال: student_2026',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    counterText: '',
                    suffixIcon: _usernameChecking
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameAvailable == true
                            ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                            : _usernameAvailable == false
                                ? const Icon(Icons.error_rounded, color: Colors.redAccent)
                                : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _usernameState,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: _usernameAvailable == true
                        ? Colors.green.shade700
                        : _usernameAvailable == false
                            ? Colors.redAccent
                            : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 10),
                Text(
                  'المسموح: أحرف إنجليزية صغيرة وأرقام وشرطة سفلية فقط، من 3 إلى 20 خانة.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _continueIdentity,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('متابعة'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _continueAsGuest,
            icon: const Icon(Icons.explore_outlined),
            label: const Text('الدخول كضيف ومتابعة التصفح'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'تقدر تتصفح الكتب والأدوات كضيف، وتحتاج حساب Google للمشاركة في الدردشة الجماعية.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _avatarStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.photo_camera_back_rounded,
            eyebrow: 'الخطوة 2 من 3',
            title: 'صورتك، بطريقتك',
            subtitle: 'أضف صورة تساعد زملاءك على تمييز حسابك. هذه الخطوة اختيارية.',
            scheme: scheme,
          ),
          const SizedBox(height: 26),
          _glassCard(
            dark: dark,
            child: Column(
              children: [
                Container(
                  width: 164,
                  height: 164,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: .20),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? NetworkImage(_avatarUrl!)
                            : null) as ImageProvider?,
                    child: _avatarBytes == null &&
                            (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? Icon(Icons.person_rounded, size: 72, color: scheme.onSurfaceVariant)
                        : null,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('المعرض'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('الكاميرا'),
                      ),
                    ),
                  ],
                ),
                if (_avatarBytes != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _avatarBytes = null),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('إزالة الصورة المختارة'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : () => _goTo(2),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
            child: const Text('متابعة'),
          ),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => _goTo(2),
              child: const Text('تخطي هذه الخطوة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studyStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.school_rounded,
            eyebrow: 'الخطوة 3 من 3',
            title: 'شنو صفّك الدراسي؟',
            subtitle: 'نرتّب المحتوى والمواد حسب مرحلتك.',
            scheme: scheme,
          ),
          const SizedBox(height: 18),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اختر صفك'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _stages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.35,
                  ),
                  itemBuilder: (context, index) {
                    final label = _stages[index];
                    final selected = label == _stage;
                    return InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () => setState(() => _stage = label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 190),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: selected
                              ? LinearGradient(
                                  colors: [scheme.primary, scheme.tertiary],
                                )
                              : null,
                          color: selected ? null : scheme.surface.withValues(alpha: .72),
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : scheme.outlineVariant.withValues(alpha: .8),
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected ? Icons.check_circle_rounded : Icons.school_outlined,
                              size: 20,
                              color: selected ? Colors.white : scheme.primary,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? Colors.white : scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const _FieldCaption('الفئة العمرية'),
                DropdownButtonFormField<String>(
                  initialValue: _age,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.cake_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'under_13', child: Text('أقل من 13 سنة')),
                    DropdownMenuItem(value: '13_15', child: Text('13–15 سنة')),
                    DropdownMenuItem(value: '16_17', child: Text('16–17 سنة')),
                    DropdownMenuItem(value: '18_plus', child: Text('18 سنة فأكثر')),
                  ],
                  onChanged: (value) => setState(() => _age = value ?? _age),
                ),
                const SizedBox(height: 14),
                const _FieldCaption('الجنس'),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded)),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('ذكر')),
                    DropdownMenuItem(value: 'female', child: Text('أنثى')),
                  ],
                  onChanged: (value) => setState(() => _gender = value ?? _gender),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_busy ? 'جارٍ حفظ بياناتك...' : 'إنهاء وحفظ البيانات'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _stepScroll({required Widget child}) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: child,
      );

  Widget _heroHeading({
    required IconData icon,
    required String eyebrow,
    required String title,
    required String subtitle,
    required ColorScheme scheme,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Text(
                eyebrow,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.6,
              fontSize: 13,
            ),
          ),
        ],
      );

  Widget _glassCard({required bool dark, required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: (dark ? const Color(0xFF1D2D45) : Colors.white)
              .withValues(alpha: dark ? .88 : .82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (dark ? Colors.white : const Color(0xFF8EA7CA))
                .withValues(alpha: dark ? .12 : .34),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .18 : .06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      );
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final Color accent;
  final bool dark;

  const _StepIndicator({
    required this.current,
    required this.accent,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      child: Row(
        children: List.generate(5, (index) {
          if (index.isOdd) {
            final completed = index ~/ 2 < current;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 3,
                decoration: BoxDecoration(
                  color: completed ? accent : muted.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            );
          }
          final step = index ~/ 2;
          final active = step == current;
          final completed = step < current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: active ? 34 : 28,
            height: active ? 34 : 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || completed
                  ? accent
                  : (dark ? const Color(0xFF26364E) : Colors.white),
              border: Border.all(
                color: active || completed ? accent : muted,
                width: active ? 2 : 1,
              ),
            ),
            child: Center(
              child: Icon(
                completed ? Icons.check_rounded : Icons.circle,
                size: completed ? 17 : (active ? 9 : 7),
                color: active || completed
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FieldCaption extends StatelessWidget {
  final String text;
  const _FieldCaption(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );
}
).hasMatch(username);
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    _usernameAvailable = null;
    if (value.trim().isEmpty) {
      setState(() => _usernameState = 'أدخل اسم مستخدم باللغة الإنجليزية');
      return;
    }
    if (!_validUsername(value)) {
      setState(() {
        _usernameState = 'استخدم 3–20 خانة من a-z و0-9 و_؛ المعرّف 1 للمطوّر فقط';
      });
      return;
    }
    if (_user == null) {
      setState(() => _usernameState = 'سجّل عبر Google حتى نتحقق من التوفر');
      return;
    }
    setState(() {
      _usernameChecking = true;
      _usernameState = 'جارٍ التحقق من توفر الاسم...';
    });
    _usernameDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _checkUsername(),
    );
  }

  Future<bool> _checkUsername() async {
    final username = _usernameController.text.trim();
    if (!_validUsername(username) || _user == null) {
      if (mounted) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = false;
          _usernameState = 'اسم المستخدم غير صالح أو يلزم تسجيل الدخول';
        });
      }
      return false;
    }
    final request = ++_usernameRequest;
    try {
      final available = await _client.rpc(
        'is_student_username_available_v1',
        params: {'p_username': username},
      ) as bool;
      if (!mounted || request != _usernameRequest ||
          username != _usernameController.text.trim()) {
        return false;
      }
      setState(() {
        _usernameChecking = false;
        _usernameAvailable = available;
        _usernameState = available
            ? 'اسم المستخدم متاح ✓'
            : 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
      });
      return available;
    } catch (_) {
      if (mounted && request == _usernameRequest) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = null;
          _usernameState = 'تعذر التحقق الآن. تحقق من الاتصال وحاول مجدداً';
        });
      }
      return false;
    }
  }

  Future<bool> _ensureGoogleAccount() async {
    if (_user != null) return true;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudentGoogleLoginScreen()),
    );
    if (!mounted) return false;
    final user = _user;
    if (user == null) return false;

    final metadata = user.userMetadata ?? {};
    if (_nameController.text.trim().isEmpty) {
      _nameController.text =
          (metadata['full_name'] ?? metadata['name'] ?? '').toString().trim();
    }
    _avatarUrl ??= metadata['picture']?.toString();
    setState(() {
      _usernameState = _usernameController.text.trim().isEmpty
          ? 'اكتب اسم المستخدم للتحقق من توفره'
          : 'جارٍ التحقق من توفر الاسم...';
    });
    if (_usernameController.text.trim().isNotEmpty) {
      return _checkUsername();
    }
    return true;
  }

  Future<void> _continueIdentity() async {
    if (_busy) return;
    if (!await _ensureGoogleAccount()) return;
    if (!mounted) return;
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 40) {
      _message('اكتب اسم العرض (من حرف إلى 40 حرفاً).');
      return;
    }
    if (!_usernameFormatValid) {
      _message('اسم المستخدم 3–20 خانة، أو 1 لحساب المطوّر المحدد فقط.');
      return;
    }
    final available = _usernameAvailable == true
        ? true
        : await _checkUsername();
    if (!available || !mounted) return;
    _goTo(1);
  }

  void _continueAsGuest() {
    if (_busy) return;
    setState(() {
      _guest = true;
      _avatarBytes = null;
    });
    _goTo(2);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarUrl = null;
      });
    } catch (_) {
      if (mounted) _message('تعذر اختيار الصورة. حاول مرة ثانية.');
    }
  }

  Future<String?> _uploadAvatar(User user) async {
    final bytes = _avatarBytes;
    if (bytes == null) return _avatarUrl;
    final path = '${user.id}/onboarding-${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  AcademicStage _mappedAcademicStage() {
    switch (_stage) {
      case 'السادس الابتدائي':
        return AcademicStage.primarySixth;
      case 'الثالث المتوسط':
      case 'الثالث المتوسط المهني':
        return AcademicStage.intermediateThird;
      case 'السادس العلمي':
      case 'السادس الأدبي':
      case 'السادس المهني':
        return AcademicStage.preparatorySixth;
      default:
        return AcademicStage.intermediateThird;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final user = _guest ? null : _user;
    if (!_guest && user == null) {
      _message('سجّل الدخول عبر Google أولاً حتى نحفظ معلومات حسابك.');
      _goTo(0);
      return;
    }
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 10 || age > 80) {
      _message('اكتب عمراً صحيحاً بين 10 و80 سنة.');
      return;
    }
    if (!_guest) {
      if (_nameController.text.trim().isEmpty ||
          _nameController.text.trim().length > 40 ||
          !_usernameFormatValid) {
        _goTo(0);
        _message('راجع الاسم واسم المستخدم قبل الحفظ.');
        return;
      }
      final available = _usernameAvailable == true
          ? true
          : await _checkUsername();
      if (!available || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dalilak_student_age_band_v1', age.toString());
      await prefs.setString('dalilak_student_gender_v1', _gender);
      await prefs.setString('dalilak_student_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_selected_academic_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_student_stage_label_v1', _stage);
      await AcademicStageController.select(_mappedAcademicStage());

      if (user != null) {
        final name = _nameController.text.trim();
        final avatar = await _uploadAvatar(user);
        await _client.from('profiles').upsert({
          'user_id': user.id,
          'display_name': name,
          'username': _usernameController.text.trim(),
          'age_band': age.toString(),
          'age': age,
          'gender': _gender,
          'stage': _stage,
          'avatar_url': avatar,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await prefs.setString('dalilak_student_display_name_v1', name);
        await prefs.setString(
          'dalilak_student_username_v1',
          _usernameController.text.trim(),
        );
      }
      await prefs.setBool('dalilak_student_onboarding_done_v1', true);
      await prefs.setBool('dalilak_home_welcome_seen_v1', true);
      if (!mounted) return;
      widget.onComplete();
    } on PostgrestException catch (error) {
      if (mounted) {
        if (error.code == '23505') {
          setState(() {
            _usernameAvailable = false;
            _usernameState = 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
            _page = 0;
          });
          await _pages.animateToPage(
            0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
          _message('هذا الاسم مستخدم من حساب آخر. اختَر اسماً مختلفاً.');
        } else {
          _message('تعذر حفظ البيانات: ${error.message}');
        }
      }
    } catch (_) {
      if (mounted) {
        _message('تعذر حفظ البيانات حالياً. تحقق من الاتصال وحاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goTo(int page) {
    if (!mounted) return;
    setState(() => _page = page);
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = scheme.primary;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: dark
                  ? const [Color(0xFF101B31), Color(0xFF172B49), Color(0xFF111827)]
                  : const [Color(0xFFEAF2FF), Color(0xFFF7F9FF), Color(0xFFE8F3F2)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      if (_page > 0)
                        IconButton.filledTonal(
                          tooltip: 'الخطوة السابقة',
                          onPressed: _busy
                              ? null
                              : () => _goTo(_page == 2 && _guest ? 0 : _page - 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      else
                        const SizedBox(width: 48),
                      const Spacer(),
                      Text(
                        'إعداد حساب الطالب',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                _StepIndicator(current: _page, accent: accent, dark: dark),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _identityStep(scheme, dark),
                      _avatarStep(scheme, dark),
                      _studyStep(scheme, dark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _identityStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.waving_hand_rounded,
            eyebrow: 'الخطوة 1 من 3',
            title: 'خلّينا نتعرّف عليك',
            subtitle: 'اختَر اسماً يميزك داخل مجتمع الطلبة.',
            scheme: scheme,
          ),
          const SizedBox(height: 22),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اسم العرض'),
                TextField(
                  controller: _nameController,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'اكتب اسمك الظاهر للطلاب',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                const _FieldCaption('اسم المستخدم بالإنجليزية'),
                TextField(
                  controller: _usernameController,
                  maxLength: 20,
                  autocorrect: false,
                  enableSuggestions: false,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  onChanged: _onUsernameChanged,
                  inputFormatters: const [],
                  decoration: InputDecoration(
                    hintText: 'مثال: student_2026',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    counterText: '',
                    suffixIcon: _usernameChecking
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameAvailable == true
                            ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                            : _usernameAvailable == false
                                ? const Icon(Icons.error_rounded, color: Colors.redAccent)
                                : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _usernameState,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: _usernameAvailable == true
                        ? Colors.green.shade700
                        : _usernameAvailable == false
                            ? Colors.redAccent
                            : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 10),
                Text(
                  'المسموح 3–20 خانة من a-z و0-9 و_، والرقم 1 مخصص لحساب المطوّر فقط.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _continueIdentity,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('متابعة'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _continueAsGuest,
            icon: const Icon(Icons.explore_outlined),
            label: const Text('الدخول كضيف ومتابعة التصفح'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'تقدر تتصفح الكتب والأدوات كضيف، وتحتاج حساب Google للمشاركة في الدردشة الجماعية.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _avatarStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.photo_camera_back_rounded,
            eyebrow: 'الخطوة 2 من 3',
            title: 'صورتك، بطريقتك',
            subtitle: 'أضف صورة تساعد زملاءك على تمييز حسابك. هذه الخطوة اختيارية.',
            scheme: scheme,
          ),
          const SizedBox(height: 26),
          _glassCard(
            dark: dark,
            child: Column(
              children: [
                Container(
                  width: 164,
                  height: 164,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: .20),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? NetworkImage(_avatarUrl!)
                            : null) as ImageProvider?,
                    child: _avatarBytes == null &&
                            (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? Icon(Icons.person_rounded, size: 72, color: scheme.onSurfaceVariant)
                        : null,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('المعرض'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('الكاميرا'),
                      ),
                    ),
                  ],
                ),
                if (_avatarBytes != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _avatarBytes = null),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('إزالة الصورة المختارة'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : () => _goTo(2),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
            child: const Text('متابعة'),
          ),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => _goTo(2),
              child: const Text('تخطي هذه الخطوة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studyStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.school_rounded,
            eyebrow: 'الخطوة 3 من 3',
            title: 'شنو صفّك الدراسي؟',
            subtitle: 'نرتّب المحتوى والمواد حسب مرحلتك.',
            scheme: scheme,
          ),
          const SizedBox(height: 18),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اختر صفك'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _stages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.35,
                  ),
                  itemBuilder: (context, index) {
                    final label = _stages[index];
                    final selected = label == _stage;
                    return InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () => setState(() => _stage = label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 190),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: selected
                              ? LinearGradient(
                                  colors: [scheme.primary, scheme.tertiary],
                                )
                              : null,
                          color: selected ? null : scheme.surface.withValues(alpha: .72),
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : scheme.outlineVariant.withValues(alpha: .8),
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected ? Icons.check_circle_rounded : Icons.school_outlined,
                              size: 20,
                              color: selected ? Colors.white : scheme.primary,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? Colors.white : scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const _FieldCaption('العمر الحقيقي'),
                TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 2,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.cake_outlined),
                    hintText: 'اكتب عمرك بالأرقام (10–80)',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                const _FieldCaption('الجنس'),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded)),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('ذكر')),
                    DropdownMenuItem(value: 'female', child: Text('أنثى')),
                  ],
                  onChanged: (value) => setState(() => _gender = value ?? _gender),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_busy ? 'جارٍ حفظ بياناتك...' : 'إنهاء وحفظ البيانات'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _stepScroll({required Widget child}) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: child,
      );

  Widget _heroHeading({
    required IconData icon,
    required String eyebrow,
    required String title,
    required String subtitle,
    required ColorScheme scheme,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Text(
                eyebrow,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.6,
              fontSize: 13,
            ),
          ),
        ],
      );

  Widget _glassCard({required bool dark, required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: (dark ? const Color(0xFF1D2D45) : Colors.white)
              .withValues(alpha: dark ? .88 : .82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (dark ? Colors.white : const Color(0xFF8EA7CA))
                .withValues(alpha: dark ? .12 : .34),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .18 : .06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      );
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final Color accent;
  final bool dark;

  const _StepIndicator({
    required this.current,
    required this.accent,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      child: Row(
        children: List.generate(5, (index) {
          if (index.isOdd) {
            final completed = index ~/ 2 < current;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 3,
                decoration: BoxDecoration(
                  color: completed ? accent : muted.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            );
          }
          final step = index ~/ 2;
          final active = step == current;
          final completed = step < current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: active ? 34 : 28,
            height: active ? 34 : 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || completed
                  ? accent
                  : (dark ? const Color(0xFF26364E) : Colors.white),
              border: Border.all(
                color: active || completed ? accent : muted,
                width: active ? 2 : 1,
              ),
            ),
            child: Center(
              child: Icon(
                completed ? Icons.check_rounded : Icons.circle,
                size: completed ? 17 : (active ? 9 : 7),
                color: active || completed
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FieldCaption extends StatelessWidget {
  final String text;
  const _FieldCaption(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );
}
).hasMatch(username);
  }

  bool get _usernameFormatValid => _validUsername(_usernameController.text);

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    _usernameAvailable = null;
    if (value.trim().isEmpty) {
      setState(() => _usernameState = 'أدخل اسم مستخدم باللغة الإنجليزية');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(value.trim())) {
      setState(() {
        _usernameState = 'استخدم a-z و0-9 والشرطة السفلية فقط (3–20 حرفاً)';
      });
      return;
    }
    if (_user == null) {
      setState(() => _usernameState = 'سجّل عبر Google حتى نتحقق من التوفر');
      return;
    }
    setState(() {
      _usernameChecking = true;
      _usernameState = 'جارٍ التحقق من توفر الاسم...';
    });
    _usernameDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _checkUsername(),
    );
  }

  Future<bool> _checkUsername() async {
    final username = _usernameController.text.trim();
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username) || _user == null) {
      if (mounted) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = false;
          _usernameState = 'اسم المستخدم غير صالح أو يلزم تسجيل الدخول';
        });
      }
      return false;
    }
    final request = ++_usernameRequest;
    try {
      final available = await _client.rpc(
        'is_student_username_available_v1',
        params: {'p_username': username},
      ) as bool;
      if (!mounted || request != _usernameRequest ||
          username != _usernameController.text.trim()) {
        return false;
      }
      setState(() {
        _usernameChecking = false;
        _usernameAvailable = available;
        _usernameState = available
            ? 'اسم المستخدم متاح ✓'
            : 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
      });
      return available;
    } catch (_) {
      if (mounted && request == _usernameRequest) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = null;
          _usernameState = 'تعذر التحقق الآن. تحقق من الاتصال وحاول مجدداً';
        });
      }
      return false;
    }
  }

  Future<bool> _ensureGoogleAccount() async {
    if (_user != null) return true;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudentGoogleLoginScreen()),
    );
    if (!mounted) return false;
    final user = _user;
    if (user == null) return false;

    final metadata = user.userMetadata ?? {};
    if (_nameController.text.trim().isEmpty) {
      _nameController.text =
          (metadata['full_name'] ?? metadata['name'] ?? '').toString().trim();
    }
    _avatarUrl ??= metadata['picture']?.toString();
    setState(() {
      _usernameState = _usernameController.text.trim().isEmpty
          ? 'اكتب اسم المستخدم للتحقق من توفره'
          : 'جارٍ التحقق من توفر الاسم...';
    });
    if (_usernameController.text.trim().isNotEmpty) {
      return _checkUsername();
    }
    return true;
  }

  Future<void> _continueIdentity() async {
    if (_busy) return;
    if (!await _ensureGoogleAccount()) return;
    if (!mounted) return;
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 40) {
      _message('اكتب اسم العرض (من حرف إلى 40 حرفاً).');
      return;
    }
    if (!_usernameFormatValid) {
      _message('اسم المستخدم يجب أن يكون إنجليزياً من 3 إلى 20 حرفاً أو رقماً أو _.');
      return;
    }
    final available = _usernameAvailable == true
        ? true
        : await _checkUsername();
    if (!available || !mounted) return;
    _goTo(1);
  }

  void _continueAsGuest() {
    if (_busy) return;
    setState(() {
      _guest = true;
      _avatarBytes = null;
    });
    _goTo(2);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarUrl = null;
      });
    } catch (_) {
      if (mounted) _message('تعذر اختيار الصورة. حاول مرة ثانية.');
    }
  }

  Future<String?> _uploadAvatar(User user) async {
    final bytes = _avatarBytes;
    if (bytes == null) return _avatarUrl;
    final path = '${user.id}/onboarding-${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  AcademicStage _mappedAcademicStage() {
    switch (_stage) {
      case 'السادس الابتدائي':
        return AcademicStage.primarySixth;
      case 'الثالث المتوسط':
      case 'الثالث المتوسط المهني':
        return AcademicStage.intermediateThird;
      case 'السادس العلمي':
      case 'السادس الأدبي':
      case 'السادس المهني':
        return AcademicStage.preparatorySixth;
      default:
        return AcademicStage.intermediateThird;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final user = _guest ? null : _user;
    if (!_guest && user == null) {
      _message('سجّل الدخول عبر Google أولاً حتى نحفظ معلومات حسابك.');
      _goTo(0);
      return;
    }
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 10 || age > 80) {
      _message('اكتب عمراً صحيحاً بين 10 و80 سنة.');
      return;
    }
    if (!_guest) {
      if (_nameController.text.trim().isEmpty ||
          _nameController.text.trim().length > 40 ||
          !_usernameFormatValid) {
        _goTo(0);
        _message('راجع الاسم واسم المستخدم قبل الحفظ.');
        return;
      }
      final available = _usernameAvailable == true
          ? true
          : await _checkUsername();
      if (!available || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final age = int.tryParse(_ageController.text.trim());
      if (age == null || age < 10 || age > 80) {
        _message('اكتب عمراً صحيحاً بين 10 و80 سنة.');
        return;
      }
      await prefs.setString('dalilak_student_age_band_v1', age.toString());
      await prefs.setString('dalilak_student_gender_v1', _gender);
      await prefs.setString('dalilak_student_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_selected_academic_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_student_stage_label_v1', _stage);
      await AcademicStageController.select(_mappedAcademicStage());

      if (user != null) {
        final name = _nameController.text.trim();
        final avatar = await _uploadAvatar(user);
        await _client.from('profiles').upsert({
          'user_id': user.id,
          'display_name': name,
          'username': _usernameController.text.trim(),
          'age_band': age.toString(),
          'age': age,
          'gender': _gender,
          'stage': _stage,
          'avatar_url': avatar,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await prefs.setString('dalilak_student_display_name_v1', name);
        await prefs.setString(
          'dalilak_student_username_v1',
          _usernameController.text.trim(),
        );
      }
      await prefs.setBool('dalilak_student_onboarding_done_v1', true);
      await prefs.setBool('dalilak_home_welcome_seen_v1', true);
      if (!mounted) return;
      widget.onComplete();
    } on PostgrestException catch (error) {
      if (mounted) {
        if (error.code == '23505') {
          setState(() {
            _usernameAvailable = false;
            _usernameState = 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
            _page = 0;
          });
          await _pages.animateToPage(
            0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
          _message('هذا الاسم مستخدم من حساب آخر. اختَر اسماً مختلفاً.');
        } else {
          _message('تعذر حفظ البيانات: ${error.message}');
        }
      }
    } catch (_) {
      if (mounted) {
        _message('تعذر حفظ البيانات حالياً. تحقق من الاتصال وحاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goTo(int page) {
    if (!mounted) return;
    setState(() => _page = page);
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = scheme.primary;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: dark
                  ? const [Color(0xFF101B31), Color(0xFF172B49), Color(0xFF111827)]
                  : const [Color(0xFFEAF2FF), Color(0xFFF7F9FF), Color(0xFFE8F3F2)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      if (_page > 0)
                        IconButton.filledTonal(
                          tooltip: 'الخطوة السابقة',
                          onPressed: _busy
                              ? null
                              : () => _goTo(_page == 2 && _guest ? 0 : _page - 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      else
                        const SizedBox(width: 48),
                      const Spacer(),
                      Text(
                        'إعداد حساب الطالب',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                _StepIndicator(current: _page, accent: accent, dark: dark),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _identityStep(scheme, dark),
                      _avatarStep(scheme, dark),
                      _studyStep(scheme, dark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _identityStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.waving_hand_rounded,
            eyebrow: 'الخطوة 1 من 3',
            title: 'خلّينا نتعرّف عليك',
            subtitle: 'اختَر اسماً يميزك داخل مجتمع الطلبة.',
            scheme: scheme,
          ),
          const SizedBox(height: 22),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اسم العرض'),
                TextField(
                  controller: _nameController,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'اكتب اسمك الظاهر للطلاب',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                const _FieldCaption('اسم المستخدم بالإنجليزية'),
                TextField(
                  controller: _usernameController,
                  maxLength: 20,
                  autocorrect: false,
                  enableSuggestions: false,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  onChanged: _onUsernameChanged,
                  inputFormatters: const [],
                  decoration: InputDecoration(
                    hintText: 'مثال: student_2026',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    counterText: '',
                    suffixIcon: _usernameChecking
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameAvailable == true
                            ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                            : _usernameAvailable == false
                                ? const Icon(Icons.error_rounded, color: Colors.redAccent)
                                : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _usernameState,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: _usernameAvailable == true
                        ? Colors.green.shade700
                        : _usernameAvailable == false
                            ? Colors.redAccent
                            : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 10),
                Text(
                  'المسموح: أحرف إنجليزية صغيرة وأرقام وشرطة سفلية فقط، من 3 إلى 20 خانة.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _continueIdentity,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('متابعة'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _continueAsGuest,
            icon: const Icon(Icons.explore_outlined),
            label: const Text('الدخول كضيف ومتابعة التصفح'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'تقدر تتصفح الكتب والأدوات كضيف، وتحتاج حساب Google للمشاركة في الدردشة الجماعية.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _avatarStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.photo_camera_back_rounded,
            eyebrow: 'الخطوة 2 من 3',
            title: 'صورتك، بطريقتك',
            subtitle: 'أضف صورة تساعد زملاءك على تمييز حسابك. هذه الخطوة اختيارية.',
            scheme: scheme,
          ),
          const SizedBox(height: 26),
          _glassCard(
            dark: dark,
            child: Column(
              children: [
                Container(
                  width: 164,
                  height: 164,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: .20),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? NetworkImage(_avatarUrl!)
                            : null) as ImageProvider?,
                    child: _avatarBytes == null &&
                            (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? Icon(Icons.person_rounded, size: 72, color: scheme.onSurfaceVariant)
                        : null,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('المعرض'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('الكاميرا'),
                      ),
                    ),
                  ],
                ),
                if (_avatarBytes != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _avatarBytes = null),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('إزالة الصورة المختارة'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : () => _goTo(2),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
            child: const Text('متابعة'),
          ),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => _goTo(2),
              child: const Text('تخطي هذه الخطوة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studyStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.school_rounded,
            eyebrow: 'الخطوة 3 من 3',
            title: 'شنو صفّك الدراسي؟',
            subtitle: 'نرتّب المحتوى والمواد حسب مرحلتك.',
            scheme: scheme,
          ),
          const SizedBox(height: 18),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اختر صفك'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _stages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.35,
                  ),
                  itemBuilder: (context, index) {
                    final label = _stages[index];
                    final selected = label == _stage;
                    return InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () => setState(() => _stage = label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 190),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: selected
                              ? LinearGradient(
                                  colors: [scheme.primary, scheme.tertiary],
                                )
                              : null,
                          color: selected ? null : scheme.surface.withValues(alpha: .72),
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : scheme.outlineVariant.withValues(alpha: .8),
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected ? Icons.check_circle_rounded : Icons.school_outlined,
                              size: 20,
                              color: selected ? Colors.white : scheme.primary,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? Colors.white : scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const _FieldCaption('الفئة العمرية'),
                DropdownButtonFormField<String>(
                  initialValue: _age,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.cake_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'under_13', child: Text('أقل من 13 سنة')),
                    DropdownMenuItem(value: '13_15', child: Text('13–15 سنة')),
                    DropdownMenuItem(value: '16_17', child: Text('16–17 سنة')),
                    DropdownMenuItem(value: '18_plus', child: Text('18 سنة فأكثر')),
                  ],
                  onChanged: (value) => setState(() => _age = value ?? _age),
                ),
                const SizedBox(height: 14),
                const _FieldCaption('الجنس'),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded)),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('ذكر')),
                    DropdownMenuItem(value: 'female', child: Text('أنثى')),
                  ],
                  onChanged: (value) => setState(() => _gender = value ?? _gender),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_busy ? 'جارٍ حفظ بياناتك...' : 'إنهاء وحفظ البيانات'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _stepScroll({required Widget child}) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: child,
      );

  Widget _heroHeading({
    required IconData icon,
    required String eyebrow,
    required String title,
    required String subtitle,
    required ColorScheme scheme,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Text(
                eyebrow,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.6,
              fontSize: 13,
            ),
          ),
        ],
      );

  Widget _glassCard({required bool dark, required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: (dark ? const Color(0xFF1D2D45) : Colors.white)
              .withValues(alpha: dark ? .88 : .82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (dark ? Colors.white : const Color(0xFF8EA7CA))
                .withValues(alpha: dark ? .12 : .34),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .18 : .06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      );
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final Color accent;
  final bool dark;

  const _StepIndicator({
    required this.current,
    required this.accent,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      child: Row(
        children: List.generate(5, (index) {
          if (index.isOdd) {
            final completed = index ~/ 2 < current;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 3,
                decoration: BoxDecoration(
                  color: completed ? accent : muted.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            );
          }
          final step = index ~/ 2;
          final active = step == current;
          final completed = step < current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: active ? 34 : 28,
            height: active ? 34 : 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || completed
                  ? accent
                  : (dark ? const Color(0xFF26364E) : Colors.white),
              border: Border.all(
                color: active || completed ? accent : muted,
                width: active ? 2 : 1,
              ),
            ),
            child: Center(
              child: Icon(
                completed ? Icons.check_rounded : Icons.circle,
                size: completed ? 17 : (active ? 9 : 7),
                color: active || completed
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FieldCaption extends StatelessWidget {
  final String text;
  const _FieldCaption(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );
}
).hasMatch(username);
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    _usernameAvailable = null;
    if (value.trim().isEmpty) {
      setState(() => _usernameState = 'أدخل اسم مستخدم باللغة الإنجليزية');
      return;
    }
    if (!_validUsername(value)) {
      setState(() {
        _usernameState = 'استخدم 3–20 خانة من a-z و0-9 و_؛ المعرّف 1 للمطوّر فقط';
      });
      return;
    }
    if (_user == null) {
      setState(() => _usernameState = 'سجّل عبر Google حتى نتحقق من التوفر');
      return;
    }
    setState(() {
      _usernameChecking = true;
      _usernameState = 'جارٍ التحقق من توفر الاسم...';
    });
    _usernameDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _checkUsername(),
    );
  }

  Future<bool> _checkUsername() async {
    final username = _usernameController.text.trim();
    if (!_validUsername(username) || _user == null) {
      if (mounted) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = false;
          _usernameState = 'اسم المستخدم غير صالح أو يلزم تسجيل الدخول';
        });
      }
      return false;
    }
    final request = ++_usernameRequest;
    try {
      final available = await _client.rpc(
        'is_student_username_available_v1',
        params: {'p_username': username},
      ) as bool;
      if (!mounted || request != _usernameRequest ||
          username != _usernameController.text.trim()) {
        return false;
      }
      setState(() {
        _usernameChecking = false;
        _usernameAvailable = available;
        _usernameState = available
            ? 'اسم المستخدم متاح ✓'
            : 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
      });
      return available;
    } catch (_) {
      if (mounted && request == _usernameRequest) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = null;
          _usernameState = 'تعذر التحقق الآن. تحقق من الاتصال وحاول مجدداً';
        });
      }
      return false;
    }
  }

  Future<bool> _ensureGoogleAccount() async {
    if (_user != null) return true;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudentGoogleLoginScreen()),
    );
    if (!mounted) return false;
    final user = _user;
    if (user == null) return false;

    final metadata = user.userMetadata ?? {};
    if (_nameController.text.trim().isEmpty) {
      _nameController.text =
          (metadata['full_name'] ?? metadata['name'] ?? '').toString().trim();
    }
    _avatarUrl ??= metadata['picture']?.toString();
    setState(() {
      _usernameState = _usernameController.text.trim().isEmpty
          ? 'اكتب اسم المستخدم للتحقق من توفره'
          : 'جارٍ التحقق من توفر الاسم...';
    });
    if (_usernameController.text.trim().isNotEmpty) {
      return _checkUsername();
    }
    return true;
  }

  Future<void> _continueIdentity() async {
    if (_busy) return;
    if (!await _ensureGoogleAccount()) return;
    if (!mounted) return;
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 40) {
      _message('اكتب اسم العرض (من حرف إلى 40 حرفاً).');
      return;
    }
    if (!_usernameFormatValid) {
      _message('اسم المستخدم 3–20 خانة، أو 1 لحساب المطوّر المحدد فقط.');
      return;
    }
    final available = _usernameAvailable == true
        ? true
        : await _checkUsername();
    if (!available || !mounted) return;
    _goTo(1);
  }

  void _continueAsGuest() {
    if (_busy) return;
    setState(() {
      _guest = true;
      _avatarBytes = null;
    });
    _goTo(2);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarUrl = null;
      });
    } catch (_) {
      if (mounted) _message('تعذر اختيار الصورة. حاول مرة ثانية.');
    }
  }

  Future<String?> _uploadAvatar(User user) async {
    final bytes = _avatarBytes;
    if (bytes == null) return _avatarUrl;
    final path = '${user.id}/onboarding-${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  AcademicStage _mappedAcademicStage() {
    switch (_stage) {
      case 'السادس الابتدائي':
        return AcademicStage.primarySixth;
      case 'الثالث المتوسط':
      case 'الثالث المتوسط المهني':
        return AcademicStage.intermediateThird;
      case 'السادس العلمي':
      case 'السادس الأدبي':
      case 'السادس المهني':
        return AcademicStage.preparatorySixth;
      default:
        return AcademicStage.intermediateThird;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final user = _guest ? null : _user;
    if (!_guest && user == null) {
      _message('سجّل الدخول عبر Google أولاً حتى نحفظ معلومات حسابك.');
      _goTo(0);
      return;
    }
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 10 || age > 80) {
      _message('اكتب عمراً صحيحاً بين 10 و80 سنة.');
      return;
    }
    if (!_guest) {
      if (_nameController.text.trim().isEmpty ||
          _nameController.text.trim().length > 40 ||
          !_usernameFormatValid) {
        _goTo(0);
        _message('راجع الاسم واسم المستخدم قبل الحفظ.');
        return;
      }
      final available = _usernameAvailable == true
          ? true
          : await _checkUsername();
      if (!available || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dalilak_student_age_band_v1', age.toString());
      await prefs.setString('dalilak_student_gender_v1', _gender);
      await prefs.setString('dalilak_student_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_selected_academic_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_student_stage_label_v1', _stage);
      await AcademicStageController.select(_mappedAcademicStage());

      if (user != null) {
        final name = _nameController.text.trim();
        final avatar = await _uploadAvatar(user);
        await _client.from('profiles').upsert({
          'user_id': user.id,
          'display_name': name,
          'username': _usernameController.text.trim(),
          'age_band': age.toString(),
          'age': age,
          'gender': _gender,
          'stage': _stage,
          'avatar_url': avatar,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await prefs.setString('dalilak_student_display_name_v1', name);
        await prefs.setString(
          'dalilak_student_username_v1',
          _usernameController.text.trim(),
        );
      }
      await prefs.setBool('dalilak_student_onboarding_done_v1', true);
      await prefs.setBool('dalilak_home_welcome_seen_v1', true);
      if (!mounted) return;
      widget.onComplete();
    } on PostgrestException catch (error) {
      if (mounted) {
        if (error.code == '23505') {
          setState(() {
            _usernameAvailable = false;
            _usernameState = 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
            _page = 0;
          });
          await _pages.animateToPage(
            0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
          _message('هذا الاسم مستخدم من حساب آخر. اختَر اسماً مختلفاً.');
        } else {
          _message('تعذر حفظ البيانات: ${error.message}');
        }
      }
    } catch (_) {
      if (mounted) {
        _message('تعذر حفظ البيانات حالياً. تحقق من الاتصال وحاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goTo(int page) {
    if (!mounted) return;
    setState(() => _page = page);
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = scheme.primary;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: dark
                  ? const [Color(0xFF101B31), Color(0xFF172B49), Color(0xFF111827)]
                  : const [Color(0xFFEAF2FF), Color(0xFFF7F9FF), Color(0xFFE8F3F2)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      if (_page > 0)
                        IconButton.filledTonal(
                          tooltip: 'الخطوة السابقة',
                          onPressed: _busy
                              ? null
                              : () => _goTo(_page == 2 && _guest ? 0 : _page - 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      else
                        const SizedBox(width: 48),
                      const Spacer(),
                      Text(
                        'إعداد حساب الطالب',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                _StepIndicator(current: _page, accent: accent, dark: dark),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _identityStep(scheme, dark),
                      _avatarStep(scheme, dark),
                      _studyStep(scheme, dark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _identityStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.waving_hand_rounded,
            eyebrow: 'الخطوة 1 من 3',
            title: 'خلّينا نتعرّف عليك',
            subtitle: 'اختَر اسماً يميزك داخل مجتمع الطلبة.',
            scheme: scheme,
          ),
          const SizedBox(height: 22),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اسم العرض'),
                TextField(
                  controller: _nameController,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'اكتب اسمك الظاهر للطلاب',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                const _FieldCaption('اسم المستخدم بالإنجليزية'),
                TextField(
                  controller: _usernameController,
                  maxLength: 20,
                  autocorrect: false,
                  enableSuggestions: false,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  onChanged: _onUsernameChanged,
                  inputFormatters: const [],
                  decoration: InputDecoration(
                    hintText: 'مثال: student_2026',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    counterText: '',
                    suffixIcon: _usernameChecking
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameAvailable == true
                            ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                            : _usernameAvailable == false
                                ? const Icon(Icons.error_rounded, color: Colors.redAccent)
                                : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _usernameState,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: _usernameAvailable == true
                        ? Colors.green.shade700
                        : _usernameAvailable == false
                            ? Colors.redAccent
                            : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 10),
                Text(
                  'المسموح 3–20 خانة من a-z و0-9 و_، والرقم 1 مخصص لحساب المطوّر فقط.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _continueIdentity,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('متابعة'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _continueAsGuest,
            icon: const Icon(Icons.explore_outlined),
            label: const Text('الدخول كضيف ومتابعة التصفح'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'تقدر تتصفح الكتب والأدوات كضيف، وتحتاج حساب Google للمشاركة في الدردشة الجماعية.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _avatarStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.photo_camera_back_rounded,
            eyebrow: 'الخطوة 2 من 3',
            title: 'صورتك، بطريقتك',
            subtitle: 'أضف صورة تساعد زملاءك على تمييز حسابك. هذه الخطوة اختيارية.',
            scheme: scheme,
          ),
          const SizedBox(height: 26),
          _glassCard(
            dark: dark,
            child: Column(
              children: [
                Container(
                  width: 164,
                  height: 164,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: .20),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? NetworkImage(_avatarUrl!)
                            : null) as ImageProvider?,
                    child: _avatarBytes == null &&
                            (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? Icon(Icons.person_rounded, size: 72, color: scheme.onSurfaceVariant)
                        : null,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('المعرض'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('الكاميرا'),
                      ),
                    ),
                  ],
                ),
                if (_avatarBytes != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _avatarBytes = null),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('إزالة الصورة المختارة'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : () => _goTo(2),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
            child: const Text('متابعة'),
          ),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => _goTo(2),
              child: const Text('تخطي هذه الخطوة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studyStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.school_rounded,
            eyebrow: 'الخطوة 3 من 3',
            title: 'شنو صفّك الدراسي؟',
            subtitle: 'نرتّب المحتوى والمواد حسب مرحلتك.',
            scheme: scheme,
          ),
          const SizedBox(height: 18),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اختر صفك'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _stages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.35,
                  ),
                  itemBuilder: (context, index) {
                    final label = _stages[index];
                    final selected = label == _stage;
                    return InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () => setState(() => _stage = label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 190),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: selected
                              ? LinearGradient(
                                  colors: [scheme.primary, scheme.tertiary],
                                )
                              : null,
                          color: selected ? null : scheme.surface.withValues(alpha: .72),
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : scheme.outlineVariant.withValues(alpha: .8),
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected ? Icons.check_circle_rounded : Icons.school_outlined,
                              size: 20,
                              color: selected ? Colors.white : scheme.primary,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? Colors.white : scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const _FieldCaption('العمر الحقيقي'),
                TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 2,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.cake_outlined),
                    hintText: 'اكتب عمرك بالأرقام (10–80)',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                const _FieldCaption('الجنس'),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded)),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('ذكر')),
                    DropdownMenuItem(value: 'female', child: Text('أنثى')),
                  ],
                  onChanged: (value) => setState(() => _gender = value ?? _gender),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_busy ? 'جارٍ حفظ بياناتك...' : 'إنهاء وحفظ البيانات'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _stepScroll({required Widget child}) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: child,
      );

  Widget _heroHeading({
    required IconData icon,
    required String eyebrow,
    required String title,
    required String subtitle,
    required ColorScheme scheme,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Text(
                eyebrow,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.6,
              fontSize: 13,
            ),
          ),
        ],
      );

  Widget _glassCard({required bool dark, required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: (dark ? const Color(0xFF1D2D45) : Colors.white)
              .withValues(alpha: dark ? .88 : .82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (dark ? Colors.white : const Color(0xFF8EA7CA))
                .withValues(alpha: dark ? .12 : .34),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .18 : .06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      );
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final Color accent;
  final bool dark;

  const _StepIndicator({
    required this.current,
    required this.accent,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      child: Row(
        children: List.generate(5, (index) {
          if (index.isOdd) {
            final completed = index ~/ 2 < current;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 3,
                decoration: BoxDecoration(
                  color: completed ? accent : muted.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            );
          }
          final step = index ~/ 2;
          final active = step == current;
          final completed = step < current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: active ? 34 : 28,
            height: active ? 34 : 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || completed
                  ? accent
                  : (dark ? const Color(0xFF26364E) : Colors.white),
              border: Border.all(
                color: active || completed ? accent : muted,
                width: active ? 2 : 1,
              ),
            ),
            child: Center(
              child: Icon(
                completed ? Icons.check_rounded : Icons.circle,
                size: completed ? 17 : (active ? 9 : 7),
                color: active || completed
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FieldCaption extends StatelessWidget {
  final String text;
  const _FieldCaption(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );
}
).hasMatch(username);
  }

  bool get _usernameFormatValid => _validUsername(_usernameController.text);

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    _usernameAvailable = null;
    if (value.trim().isEmpty) {
      setState(() => _usernameState = 'أدخل اسم مستخدم باللغة الإنجليزية');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(value.trim())) {
      setState(() {
        _usernameState = 'استخدم a-z و0-9 والشرطة السفلية فقط (3–20 حرفاً)';
      });
      return;
    }
    if (_user == null) {
      setState(() => _usernameState = 'سجّل عبر Google حتى نتحقق من التوفر');
      return;
    }
    setState(() {
      _usernameChecking = true;
      _usernameState = 'جارٍ التحقق من توفر الاسم...';
    });
    _usernameDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _checkUsername(),
    );
  }

  Future<bool> _checkUsername() async {
    final username = _usernameController.text.trim();
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username) || _user == null) {
      if (mounted) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = false;
          _usernameState = 'اسم المستخدم غير صالح أو يلزم تسجيل الدخول';
        });
      }
      return false;
    }
    final request = ++_usernameRequest;
    try {
      final available = await _client.rpc(
        'is_student_username_available_v1',
        params: {'p_username': username},
      ) as bool;
      if (!mounted || request != _usernameRequest ||
          username != _usernameController.text.trim()) {
        return false;
      }
      setState(() {
        _usernameChecking = false;
        _usernameAvailable = available;
        _usernameState = available
            ? 'اسم المستخدم متاح ✓'
            : 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
      });
      return available;
    } catch (_) {
      if (mounted && request == _usernameRequest) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = null;
          _usernameState = 'تعذر التحقق الآن. تحقق من الاتصال وحاول مجدداً';
        });
      }
      return false;
    }
  }

  Future<bool> _ensureGoogleAccount() async {
    if (_user != null) return true;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudentGoogleLoginScreen()),
    );
    if (!mounted) return false;
    final user = _user;
    if (user == null) return false;

    final metadata = user.userMetadata ?? {};
    if (_nameController.text.trim().isEmpty) {
      _nameController.text =
          (metadata['full_name'] ?? metadata['name'] ?? '').toString().trim();
    }
    _avatarUrl ??= metadata['picture']?.toString();
    setState(() {
      _usernameState = _usernameController.text.trim().isEmpty
          ? 'اكتب اسم المستخدم للتحقق من توفره'
          : 'جارٍ التحقق من توفر الاسم...';
    });
    if (_usernameController.text.trim().isNotEmpty) {
      return _checkUsername();
    }
    return true;
  }

  Future<void> _continueIdentity() async {
    if (_busy) return;
    if (!await _ensureGoogleAccount()) return;
    if (!mounted) return;
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 40) {
      _message('اكتب اسم العرض (من حرف إلى 40 حرفاً).');
      return;
    }
    if (!_usernameFormatValid) {
      _message('اسم المستخدم يجب أن يكون إنجليزياً من 3 إلى 20 حرفاً أو رقماً أو _.');
      return;
    }
    final available = _usernameAvailable == true
        ? true
        : await _checkUsername();
    if (!available || !mounted) return;
    _goTo(1);
  }

  void _continueAsGuest() {
    if (_busy) return;
    setState(() {
      _guest = true;
      _avatarBytes = null;
    });
    _goTo(2);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarUrl = null;
      });
    } catch (_) {
      if (mounted) _message('تعذر اختيار الصورة. حاول مرة ثانية.');
    }
  }

  Future<String?> _uploadAvatar(User user) async {
    final bytes = _avatarBytes;
    if (bytes == null) return _avatarUrl;
    final path = '${user.id}/onboarding-${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  AcademicStage _mappedAcademicStage() {
    switch (_stage) {
      case 'السادس الابتدائي':
        return AcademicStage.primarySixth;
      case 'الثالث المتوسط':
      case 'الثالث المتوسط المهني':
        return AcademicStage.intermediateThird;
      case 'السادس العلمي':
      case 'السادس الأدبي':
      case 'السادس المهني':
        return AcademicStage.preparatorySixth;
      default:
        return AcademicStage.intermediateThird;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final user = _guest ? null : _user;
    if (!_guest && user == null) {
      _message('سجّل الدخول عبر Google أولاً حتى نحفظ معلومات حسابك.');
      _goTo(0);
      return;
    }
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 10 || age > 80) {
      _message('اكتب عمراً صحيحاً بين 10 و80 سنة.');
      return;
    }
    if (!_guest) {
      if (_nameController.text.trim().isEmpty ||
          _nameController.text.trim().length > 40 ||
          !_usernameFormatValid) {
        _goTo(0);
        _message('راجع الاسم واسم المستخدم قبل الحفظ.');
        return;
      }
      final available = _usernameAvailable == true
          ? true
          : await _checkUsername();
      if (!available || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final age = int.tryParse(_ageController.text.trim());
      if (age == null || age < 10 || age > 80) {
        _message('اكتب عمراً صحيحاً بين 10 و80 سنة.');
        return;
      }
      await prefs.setString('dalilak_student_age_band_v1', age.toString());
      await prefs.setString('dalilak_student_gender_v1', _gender);
      await prefs.setString('dalilak_student_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_selected_academic_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_student_stage_label_v1', _stage);
      await AcademicStageController.select(_mappedAcademicStage());

      if (user != null) {
        final name = _nameController.text.trim();
        final avatar = await _uploadAvatar(user);
        await _client.from('profiles').upsert({
          'user_id': user.id,
          'display_name': name,
          'username': _usernameController.text.trim(),
          'age_band': age.toString(),
          'age': age,
          'gender': _gender,
          'stage': _stage,
          'avatar_url': avatar,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await prefs.setString('dalilak_student_display_name_v1', name);
        await prefs.setString(
          'dalilak_student_username_v1',
          _usernameController.text.trim(),
        );
      }
      await prefs.setBool('dalilak_student_onboarding_done_v1', true);
      await prefs.setBool('dalilak_home_welcome_seen_v1', true);
      if (!mounted) return;
      widget.onComplete();
    } on PostgrestException catch (error) {
      if (mounted) {
        if (error.code == '23505') {
          setState(() {
            _usernameAvailable = false;
            _usernameState = 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
            _page = 0;
          });
          await _pages.animateToPage(
            0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
          _message('هذا الاسم مستخدم من حساب آخر. اختَر اسماً مختلفاً.');
        } else {
          _message('تعذر حفظ البيانات: ${error.message}');
        }
      }
    } catch (_) {
      if (mounted) {
        _message('تعذر حفظ البيانات حالياً. تحقق من الاتصال وحاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goTo(int page) {
    if (!mounted) return;
    setState(() => _page = page);
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = scheme.primary;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: dark
                  ? const [Color(0xFF101B31), Color(0xFF172B49), Color(0xFF111827)]
                  : const [Color(0xFFEAF2FF), Color(0xFFF7F9FF), Color(0xFFE8F3F2)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      if (_page > 0)
                        IconButton.filledTonal(
                          tooltip: 'الخطوة السابقة',
                          onPressed: _busy
                              ? null
                              : () => _goTo(_page == 2 && _guest ? 0 : _page - 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      else
                        const SizedBox(width: 48),
                      const Spacer(),
                      Text(
                        'إعداد حساب الطالب',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                _StepIndicator(current: _page, accent: accent, dark: dark),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _identityStep(scheme, dark),
                      _avatarStep(scheme, dark),
                      _studyStep(scheme, dark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _identityStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.waving_hand_rounded,
            eyebrow: 'الخطوة 1 من 3',
            title: 'خلّينا نتعرّف عليك',
            subtitle: 'اختَر اسماً يميزك داخل مجتمع الطلبة.',
            scheme: scheme,
          ),
          const SizedBox(height: 22),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اسم العرض'),
                TextField(
                  controller: _nameController,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'اكتب اسمك الظاهر للطلاب',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                const _FieldCaption('اسم المستخدم بالإنجليزية'),
                TextField(
                  controller: _usernameController,
                  maxLength: 20,
                  autocorrect: false,
                  enableSuggestions: false,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  onChanged: _onUsernameChanged,
                  inputFormatters: const [],
                  decoration: InputDecoration(
                    hintText: 'مثال: student_2026',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    counterText: '',
                    suffixIcon: _usernameChecking
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameAvailable == true
                            ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                            : _usernameAvailable == false
                                ? const Icon(Icons.error_rounded, color: Colors.redAccent)
                                : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _usernameState,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: _usernameAvailable == true
                        ? Colors.green.shade700
                        : _usernameAvailable == false
                            ? Colors.redAccent
                            : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 10),
                Text(
                  'المسموح: أحرف إنجليزية صغيرة وأرقام وشرطة سفلية فقط، من 3 إلى 20 خانة.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _continueIdentity,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('متابعة'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _continueAsGuest,
            icon: const Icon(Icons.explore_outlined),
            label: const Text('الدخول كضيف ومتابعة التصفح'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'تقدر تتصفح الكتب والأدوات كضيف، وتحتاج حساب Google للمشاركة في الدردشة الجماعية.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _avatarStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.photo_camera_back_rounded,
            eyebrow: 'الخطوة 2 من 3',
            title: 'صورتك، بطريقتك',
            subtitle: 'أضف صورة تساعد زملاءك على تمييز حسابك. هذه الخطوة اختيارية.',
            scheme: scheme,
          ),
          const SizedBox(height: 26),
          _glassCard(
            dark: dark,
            child: Column(
              children: [
                Container(
                  width: 164,
                  height: 164,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: .20),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? NetworkImage(_avatarUrl!)
                            : null) as ImageProvider?,
                    child: _avatarBytes == null &&
                            (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? Icon(Icons.person_rounded, size: 72, color: scheme.onSurfaceVariant)
                        : null,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('المعرض'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('الكاميرا'),
                      ),
                    ),
                  ],
                ),
                if (_avatarBytes != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _avatarBytes = null),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('إزالة الصورة المختارة'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : () => _goTo(2),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
            child: const Text('متابعة'),
          ),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => _goTo(2),
              child: const Text('تخطي هذه الخطوة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studyStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.school_rounded,
            eyebrow: 'الخطوة 3 من 3',
            title: 'شنو صفّك الدراسي؟',
            subtitle: 'نرتّب المحتوى والمواد حسب مرحلتك.',
            scheme: scheme,
          ),
          const SizedBox(height: 18),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اختر صفك'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _stages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.35,
                  ),
                  itemBuilder: (context, index) {
                    final label = _stages[index];
                    final selected = label == _stage;
                    return InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () => setState(() => _stage = label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 190),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: selected
                              ? LinearGradient(
                                  colors: [scheme.primary, scheme.tertiary],
                                )
                              : null,
                          color: selected ? null : scheme.surface.withValues(alpha: .72),
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : scheme.outlineVariant.withValues(alpha: .8),
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected ? Icons.check_circle_rounded : Icons.school_outlined,
                              size: 20,
                              color: selected ? Colors.white : scheme.primary,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? Colors.white : scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const _FieldCaption('الفئة العمرية'),
                DropdownButtonFormField<String>(
                  initialValue: _age,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.cake_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'under_13', child: Text('أقل من 13 سنة')),
                    DropdownMenuItem(value: '13_15', child: Text('13–15 سنة')),
                    DropdownMenuItem(value: '16_17', child: Text('16–17 سنة')),
                    DropdownMenuItem(value: '18_plus', child: Text('18 سنة فأكثر')),
                  ],
                  onChanged: (value) => setState(() => _age = value ?? _age),
                ),
                const SizedBox(height: 14),
                const _FieldCaption('الجنس'),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded)),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('ذكر')),
                    DropdownMenuItem(value: 'female', child: Text('أنثى')),
                  ],
                  onChanged: (value) => setState(() => _gender = value ?? _gender),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_busy ? 'جارٍ حفظ بياناتك...' : 'إنهاء وحفظ البيانات'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _stepScroll({required Widget child}) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: child,
      );

  Widget _heroHeading({
    required IconData icon,
    required String eyebrow,
    required String title,
    required String subtitle,
    required ColorScheme scheme,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Text(
                eyebrow,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.6,
              fontSize: 13,
            ),
          ),
        ],
      );

  Widget _glassCard({required bool dark, required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: (dark ? const Color(0xFF1D2D45) : Colors.white)
              .withValues(alpha: dark ? .88 : .82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (dark ? Colors.white : const Color(0xFF8EA7CA))
                .withValues(alpha: dark ? .12 : .34),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .18 : .06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      );
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final Color accent;
  final bool dark;

  const _StepIndicator({
    required this.current,
    required this.accent,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      child: Row(
        children: List.generate(5, (index) {
          if (index.isOdd) {
            final completed = index ~/ 2 < current;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 3,
                decoration: BoxDecoration(
                  color: completed ? accent : muted.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            );
          }
          final step = index ~/ 2;
          final active = step == current;
          final completed = step < current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: active ? 34 : 28,
            height: active ? 34 : 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || completed
                  ? accent
                  : (dark ? const Color(0xFF26364E) : Colors.white),
              border: Border.all(
                color: active || completed ? accent : muted,
                width: active ? 2 : 1,
              ),
            ),
            child: Center(
              child: Icon(
                completed ? Icons.check_rounded : Icons.circle,
                size: completed ? 17 : (active ? 9 : 7),
                color: active || completed
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FieldCaption extends StatelessWidget {
  final String text;
  const _FieldCaption(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );
}
).hasMatch(username);
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    _usernameAvailable = null;
    if (value.trim().isEmpty) {
      setState(() => _usernameState = 'أدخل اسم مستخدم باللغة الإنجليزية');
      return;
    }
    if (!_validUsername(value)) {
      setState(() {
        _usernameState = 'استخدم 3–20 خانة من a-z و0-9 و_؛ المعرّف 1 للمطوّر فقط';
      });
      return;
    }
    if (_user == null) {
      setState(() => _usernameState = 'سجّل عبر Google حتى نتحقق من التوفر');
      return;
    }
    setState(() {
      _usernameChecking = true;
      _usernameState = 'جارٍ التحقق من توفر الاسم...';
    });
    _usernameDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _checkUsername(),
    );
  }

  Future<bool> _checkUsername() async {
    final username = _usernameController.text.trim();
    if (!_validUsername(username) || _user == null) {
      if (mounted) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = false;
          _usernameState = 'اسم المستخدم غير صالح أو يلزم تسجيل الدخول';
        });
      }
      return false;
    }
    final request = ++_usernameRequest;
    try {
      final available = await _client.rpc(
        'is_student_username_available_v1',
        params: {'p_username': username},
      ) as bool;
      if (!mounted || request != _usernameRequest ||
          username != _usernameController.text.trim()) {
        return false;
      }
      setState(() {
        _usernameChecking = false;
        _usernameAvailable = available;
        _usernameState = available
            ? 'اسم المستخدم متاح ✓'
            : 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
      });
      return available;
    } catch (_) {
      if (mounted && request == _usernameRequest) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = null;
          _usernameState = 'تعذر التحقق الآن. تحقق من الاتصال وحاول مجدداً';
        });
      }
      return false;
    }
  }

  Future<bool> _ensureGoogleAccount() async {
    if (_user != null) return true;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudentGoogleLoginScreen()),
    );
    if (!mounted) return false;
    final user = _user;
    if (user == null) return false;

    final metadata = user.userMetadata ?? {};
    if (_nameController.text.trim().isEmpty) {
      _nameController.text =
          (metadata['full_name'] ?? metadata['name'] ?? '').toString().trim();
    }
    _avatarUrl ??= metadata['picture']?.toString();
    setState(() {
      _usernameState = _usernameController.text.trim().isEmpty
          ? 'اكتب اسم المستخدم للتحقق من توفره'
          : 'جارٍ التحقق من توفر الاسم...';
    });
    if (_usernameController.text.trim().isNotEmpty) {
      return _checkUsername();
    }
    return true;
  }

  Future<void> _continueIdentity() async {
    if (_busy) return;
    if (!await _ensureGoogleAccount()) return;
    if (!mounted) return;
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 40) {
      _message('اكتب اسم العرض (من حرف إلى 40 حرفاً).');
      return;
    }
    if (!_usernameFormatValid) {
      _message('اسم المستخدم 3–20 خانة، أو 1 لحساب المطوّر المحدد فقط.');
      return;
    }
    final available = _usernameAvailable == true
        ? true
        : await _checkUsername();
    if (!available || !mounted) return;
    _goTo(1);
  }

  void _continueAsGuest() {
    if (_busy) return;
    setState(() {
      _guest = true;
      _avatarBytes = null;
    });
    _goTo(2);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarUrl = null;
      });
    } catch (_) {
      if (mounted) _message('تعذر اختيار الصورة. حاول مرة ثانية.');
    }
  }

  Future<String?> _uploadAvatar(User user) async {
    final bytes = _avatarBytes;
    if (bytes == null) return _avatarUrl;
    final path = '${user.id}/onboarding-${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  AcademicStage _mappedAcademicStage() {
    switch (_stage) {
      case 'السادس الابتدائي':
        return AcademicStage.primarySixth;
      case 'الثالث المتوسط':
      case 'الثالث المتوسط المهني':
        return AcademicStage.intermediateThird;
      case 'السادس العلمي':
      case 'السادس الأدبي':
      case 'السادس المهني':
        return AcademicStage.preparatorySixth;
      default:
        return AcademicStage.intermediateThird;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final user = _guest ? null : _user;
    if (!_guest && user == null) {
      _message('سجّل الدخول عبر Google أولاً حتى نحفظ معلومات حسابك.');
      _goTo(0);
      return;
    }
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 10 || age > 80) {
      _message('اكتب عمراً صحيحاً بين 10 و80 سنة.');
      return;
    }
    if (!_guest) {
      if (_nameController.text.trim().isEmpty ||
          _nameController.text.trim().length > 40 ||
          !_usernameFormatValid) {
        _goTo(0);
        _message('راجع الاسم واسم المستخدم قبل الحفظ.');
        return;
      }
      final available = _usernameAvailable == true
          ? true
          : await _checkUsername();
      if (!available || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dalilak_student_age_band_v1', age.toString());
      await prefs.setString('dalilak_student_gender_v1', _gender);
      await prefs.setString('dalilak_student_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_selected_academic_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_student_stage_label_v1', _stage);
      await AcademicStageController.select(_mappedAcademicStage());

      if (user != null) {
        final name = _nameController.text.trim();
        final avatar = await _uploadAvatar(user);
        await _client.from('profiles').upsert({
          'user_id': user.id,
          'display_name': name,
          'username': _usernameController.text.trim(),
          'age_band': age.toString(),
          'age': age,
          'gender': _gender,
          'stage': _stage,
          'avatar_url': avatar,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await prefs.setString('dalilak_student_display_name_v1', name);
        await prefs.setString(
          'dalilak_student_username_v1',
          _usernameController.text.trim(),
        );
      }
      await prefs.setBool('dalilak_student_onboarding_done_v1', true);
      await prefs.setBool('dalilak_home_welcome_seen_v1', true);
      if (!mounted) return;
      widget.onComplete();
    } on PostgrestException catch (error) {
      if (mounted) {
        if (error.code == '23505') {
          setState(() {
            _usernameAvailable = false;
            _usernameState = 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
            _page = 0;
          });
          await _pages.animateToPage(
            0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
          _message('هذا الاسم مستخدم من حساب آخر. اختَر اسماً مختلفاً.');
        } else {
          _message('تعذر حفظ البيانات: ${error.message}');
        }
      }
    } catch (_) {
      if (mounted) {
        _message('تعذر حفظ البيانات حالياً. تحقق من الاتصال وحاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goTo(int page) {
    if (!mounted) return;
    setState(() => _page = page);
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = scheme.primary;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: dark
                  ? const [Color(0xFF101B31), Color(0xFF172B49), Color(0xFF111827)]
                  : const [Color(0xFFEAF2FF), Color(0xFFF7F9FF), Color(0xFFE8F3F2)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      if (_page > 0)
                        IconButton.filledTonal(
                          tooltip: 'الخطوة السابقة',
                          onPressed: _busy
                              ? null
                              : () => _goTo(_page == 2 && _guest ? 0 : _page - 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      else
                        const SizedBox(width: 48),
                      const Spacer(),
                      Text(
                        'إعداد حساب الطالب',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                _StepIndicator(current: _page, accent: accent, dark: dark),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _identityStep(scheme, dark),
                      _avatarStep(scheme, dark),
                      _studyStep(scheme, dark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _identityStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.waving_hand_rounded,
            eyebrow: 'الخطوة 1 من 3',
            title: 'خلّينا نتعرّف عليك',
            subtitle: 'اختَر اسماً يميزك داخل مجتمع الطلبة.',
            scheme: scheme,
          ),
          const SizedBox(height: 22),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اسم العرض'),
                TextField(
                  controller: _nameController,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'اكتب اسمك الظاهر للطلاب',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                const _FieldCaption('اسم المستخدم بالإنجليزية'),
                TextField(
                  controller: _usernameController,
                  maxLength: 20,
                  autocorrect: false,
                  enableSuggestions: false,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  onChanged: _onUsernameChanged,
                  inputFormatters: const [],
                  decoration: InputDecoration(
                    hintText: 'مثال: student_2026',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    counterText: '',
                    suffixIcon: _usernameChecking
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameAvailable == true
                            ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                            : _usernameAvailable == false
                                ? const Icon(Icons.error_rounded, color: Colors.redAccent)
                                : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _usernameState,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: _usernameAvailable == true
                        ? Colors.green.shade700
                        : _usernameAvailable == false
                            ? Colors.redAccent
                            : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 10),
                Text(
                  'المسموح 3–20 خانة من a-z و0-9 و_، والرقم 1 مخصص لحساب المطوّر فقط.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _continueIdentity,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('متابعة'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _continueAsGuest,
            icon: const Icon(Icons.explore_outlined),
            label: const Text('الدخول كضيف ومتابعة التصفح'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'تقدر تتصفح الكتب والأدوات كضيف، وتحتاج حساب Google للمشاركة في الدردشة الجماعية.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _avatarStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.photo_camera_back_rounded,
            eyebrow: 'الخطوة 2 من 3',
            title: 'صورتك، بطريقتك',
            subtitle: 'أضف صورة تساعد زملاءك على تمييز حسابك. هذه الخطوة اختيارية.',
            scheme: scheme,
          ),
          const SizedBox(height: 26),
          _glassCard(
            dark: dark,
            child: Column(
              children: [
                Container(
                  width: 164,
                  height: 164,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: .20),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? NetworkImage(_avatarUrl!)
                            : null) as ImageProvider?,
                    child: _avatarBytes == null &&
                            (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? Icon(Icons.person_rounded, size: 72, color: scheme.onSurfaceVariant)
                        : null,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('المعرض'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('الكاميرا'),
                      ),
                    ),
                  ],
                ),
                if (_avatarBytes != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _avatarBytes = null),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('إزالة الصورة المختارة'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : () => _goTo(2),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
            child: const Text('متابعة'),
          ),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => _goTo(2),
              child: const Text('تخطي هذه الخطوة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studyStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.school_rounded,
            eyebrow: 'الخطوة 3 من 3',
            title: 'شنو صفّك الدراسي؟',
            subtitle: 'نرتّب المحتوى والمواد حسب مرحلتك.',
            scheme: scheme,
          ),
          const SizedBox(height: 18),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اختر صفك'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _stages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.35,
                  ),
                  itemBuilder: (context, index) {
                    final label = _stages[index];
                    final selected = label == _stage;
                    return InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () => setState(() => _stage = label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 190),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: selected
                              ? LinearGradient(
                                  colors: [scheme.primary, scheme.tertiary],
                                )
                              : null,
                          color: selected ? null : scheme.surface.withValues(alpha: .72),
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : scheme.outlineVariant.withValues(alpha: .8),
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected ? Icons.check_circle_rounded : Icons.school_outlined,
                              size: 20,
                              color: selected ? Colors.white : scheme.primary,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? Colors.white : scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const _FieldCaption('العمر الحقيقي'),
                TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 2,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.cake_outlined),
                    hintText: 'اكتب عمرك بالأرقام (10–80)',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                const _FieldCaption('الجنس'),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded)),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('ذكر')),
                    DropdownMenuItem(value: 'female', child: Text('أنثى')),
                  ],
                  onChanged: (value) => setState(() => _gender = value ?? _gender),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_busy ? 'جارٍ حفظ بياناتك...' : 'إنهاء وحفظ البيانات'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _stepScroll({required Widget child}) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: child,
      );

  Widget _heroHeading({
    required IconData icon,
    required String eyebrow,
    required String title,
    required String subtitle,
    required ColorScheme scheme,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Text(
                eyebrow,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.6,
              fontSize: 13,
            ),
          ),
        ],
      );

  Widget _glassCard({required bool dark, required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: (dark ? const Color(0xFF1D2D45) : Colors.white)
              .withValues(alpha: dark ? .88 : .82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (dark ? Colors.white : const Color(0xFF8EA7CA))
                .withValues(alpha: dark ? .12 : .34),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .18 : .06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      );
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final Color accent;
  final bool dark;

  const _StepIndicator({
    required this.current,
    required this.accent,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      child: Row(
        children: List.generate(5, (index) {
          if (index.isOdd) {
            final completed = index ~/ 2 < current;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 3,
                decoration: BoxDecoration(
                  color: completed ? accent : muted.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            );
          }
          final step = index ~/ 2;
          final active = step == current;
          final completed = step < current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: active ? 34 : 28,
            height: active ? 34 : 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || completed
                  ? accent
                  : (dark ? const Color(0xFF26364E) : Colors.white),
              border: Border.all(
                color: active || completed ? accent : muted,
                width: active ? 2 : 1,
              ),
            ),
            child: Center(
              child: Icon(
                completed ? Icons.check_rounded : Icons.circle,
                size: completed ? 17 : (active ? 9 : 7),
                color: active || completed
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FieldCaption extends StatelessWidget {
  final String text;
  const _FieldCaption(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );
}
).hasMatch(username);
  }

  bool get _usernameFormatValid => _validUsername(_usernameController.text);

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    _usernameAvailable = null;
    if (value.trim().isEmpty) {
      setState(() => _usernameState = 'أدخل اسم مستخدم باللغة الإنجليزية');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(value.trim())) {
      setState(() {
        _usernameState = 'استخدم a-z و0-9 والشرطة السفلية فقط (3–20 حرفاً)';
      });
      return;
    }
    if (_user == null) {
      setState(() => _usernameState = 'سجّل عبر Google حتى نتحقق من التوفر');
      return;
    }
    setState(() {
      _usernameChecking = true;
      _usernameState = 'جارٍ التحقق من توفر الاسم...';
    });
    _usernameDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _checkUsername(),
    );
  }

  Future<bool> _checkUsername() async {
    final username = _usernameController.text.trim();
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username) || _user == null) {
      if (mounted) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = false;
          _usernameState = 'اسم المستخدم غير صالح أو يلزم تسجيل الدخول';
        });
      }
      return false;
    }
    final request = ++_usernameRequest;
    try {
      final available = await _client.rpc(
        'is_student_username_available_v1',
        params: {'p_username': username},
      ) as bool;
      if (!mounted || request != _usernameRequest ||
          username != _usernameController.text.trim()) {
        return false;
      }
      setState(() {
        _usernameChecking = false;
        _usernameAvailable = available;
        _usernameState = available
            ? 'اسم المستخدم متاح ✓'
            : 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
      });
      return available;
    } catch (_) {
      if (mounted && request == _usernameRequest) {
        setState(() {
          _usernameChecking = false;
          _usernameAvailable = null;
          _usernameState = 'تعذر التحقق الآن. تحقق من الاتصال وحاول مجدداً';
        });
      }
      return false;
    }
  }

  Future<bool> _ensureGoogleAccount() async {
    if (_user != null) return true;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudentGoogleLoginScreen()),
    );
    if (!mounted) return false;
    final user = _user;
    if (user == null) return false;

    final metadata = user.userMetadata ?? {};
    if (_nameController.text.trim().isEmpty) {
      _nameController.text =
          (metadata['full_name'] ?? metadata['name'] ?? '').toString().trim();
    }
    _avatarUrl ??= metadata['picture']?.toString();
    setState(() {
      _usernameState = _usernameController.text.trim().isEmpty
          ? 'اكتب اسم المستخدم للتحقق من توفره'
          : 'جارٍ التحقق من توفر الاسم...';
    });
    if (_usernameController.text.trim().isNotEmpty) {
      return _checkUsername();
    }
    return true;
  }

  Future<void> _continueIdentity() async {
    if (_busy) return;
    if (!await _ensureGoogleAccount()) return;
    if (!mounted) return;
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 40) {
      _message('اكتب اسم العرض (من حرف إلى 40 حرفاً).');
      return;
    }
    if (!_usernameFormatValid) {
      _message('اسم المستخدم يجب أن يكون إنجليزياً من 3 إلى 20 حرفاً أو رقماً أو _.');
      return;
    }
    final available = _usernameAvailable == true
        ? true
        : await _checkUsername();
    if (!available || !mounted) return;
    _goTo(1);
  }

  void _continueAsGuest() {
    if (_busy) return;
    setState(() {
      _guest = true;
      _avatarBytes = null;
    });
    _goTo(2);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _avatarBytes = bytes;
        _avatarUrl = null;
      });
    } catch (_) {
      if (mounted) _message('تعذر اختيار الصورة. حاول مرة ثانية.');
    }
  }

  Future<String?> _uploadAvatar(User user) async {
    final bytes = _avatarBytes;
    if (bytes == null) return _avatarUrl;
    final path = '${user.id}/onboarding-${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  AcademicStage _mappedAcademicStage() {
    switch (_stage) {
      case 'السادس الابتدائي':
        return AcademicStage.primarySixth;
      case 'الثالث المتوسط':
      case 'الثالث المتوسط المهني':
        return AcademicStage.intermediateThird;
      case 'السادس العلمي':
      case 'السادس الأدبي':
      case 'السادس المهني':
        return AcademicStage.preparatorySixth;
      default:
        return AcademicStage.intermediateThird;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final user = _guest ? null : _user;
    if (!_guest && user == null) {
      _message('سجّل الدخول عبر Google أولاً حتى نحفظ معلومات حسابك.');
      _goTo(0);
      return;
    }
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 10 || age > 80) {
      _message('اكتب عمراً صحيحاً بين 10 و80 سنة.');
      return;
    }
    if (!_guest) {
      if (_nameController.text.trim().isEmpty ||
          _nameController.text.trim().length > 40 ||
          !_usernameFormatValid) {
        _goTo(0);
        _message('راجع الاسم واسم المستخدم قبل الحفظ.');
        return;
      }
      final available = _usernameAvailable == true
          ? true
          : await _checkUsername();
      if (!available || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final age = int.tryParse(_ageController.text.trim());
      if (age == null || age < 10 || age > 80) {
        _message('اكتب عمراً صحيحاً بين 10 و80 سنة.');
        return;
      }
      await prefs.setString('dalilak_student_age_band_v1', age.toString());
      await prefs.setString('dalilak_student_gender_v1', _gender);
      await prefs.setString('dalilak_student_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_selected_academic_stage_v1', _mappedAcademicStage().name);
      await prefs.setString('dalilak_student_stage_label_v1', _stage);
      await AcademicStageController.select(_mappedAcademicStage());

      if (user != null) {
        final name = _nameController.text.trim();
        final avatar = await _uploadAvatar(user);
        await _client.from('profiles').upsert({
          'user_id': user.id,
          'display_name': name,
          'username': _usernameController.text.trim(),
          'age_band': age.toString(),
          'age': age,
          'gender': _gender,
          'stage': _stage,
          'avatar_url': avatar,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        await prefs.setString('dalilak_student_display_name_v1', name);
        await prefs.setString(
          'dalilak_student_username_v1',
          _usernameController.text.trim(),
        );
      }
      await prefs.setBool('dalilak_student_onboarding_done_v1', true);
      await prefs.setBool('dalilak_home_welcome_seen_v1', true);
      if (!mounted) return;
      widget.onComplete();
    } on PostgrestException catch (error) {
      if (mounted) {
        if (error.code == '23505') {
          setState(() {
            _usernameAvailable = false;
            _usernameState = 'اسم المستخدم مستخدم مسبقاً، اختر اسماً آخر';
            _page = 0;
          });
          await _pages.animateToPage(
            0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
          _message('هذا الاسم مستخدم من حساب آخر. اختَر اسماً مختلفاً.');
        } else {
          _message('تعذر حفظ البيانات: ${error.message}');
        }
      }
    } catch (_) {
      if (mounted) {
        _message('تعذر حفظ البيانات حالياً. تحقق من الاتصال وحاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goTo(int page) {
    if (!mounted) return;
    setState(() => _page = page);
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = scheme.primary;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: dark
                  ? const [Color(0xFF101B31), Color(0xFF172B49), Color(0xFF111827)]
                  : const [Color(0xFFEAF2FF), Color(0xFFF7F9FF), Color(0xFFE8F3F2)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      if (_page > 0)
                        IconButton.filledTonal(
                          tooltip: 'الخطوة السابقة',
                          onPressed: _busy
                              ? null
                              : () => _goTo(_page == 2 && _guest ? 0 : _page - 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      else
                        const SizedBox(width: 48),
                      const Spacer(),
                      Text(
                        'إعداد حساب الطالب',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                _StepIndicator(current: _page, accent: accent, dark: dark),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _identityStep(scheme, dark),
                      _avatarStep(scheme, dark),
                      _studyStep(scheme, dark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _identityStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.waving_hand_rounded,
            eyebrow: 'الخطوة 1 من 3',
            title: 'خلّينا نتعرّف عليك',
            subtitle: 'اختَر اسماً يميزك داخل مجتمع الطلبة.',
            scheme: scheme,
          ),
          const SizedBox(height: 22),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اسم العرض'),
                TextField(
                  controller: _nameController,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'اكتب اسمك الظاهر للطلاب',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                const _FieldCaption('اسم المستخدم بالإنجليزية'),
                TextField(
                  controller: _usernameController,
                  maxLength: 20,
                  autocorrect: false,
                  enableSuggestions: false,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  onChanged: _onUsernameChanged,
                  inputFormatters: const [],
                  decoration: InputDecoration(
                    hintText: 'مثال: student_2026',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    counterText: '',
                    suffixIcon: _usernameChecking
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameAvailable == true
                            ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                            : _usernameAvailable == false
                                ? const Icon(Icons.error_rounded, color: Colors.redAccent)
                                : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _usernameState,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: _usernameAvailable == true
                        ? Colors.green.shade700
                        : _usernameAvailable == false
                            ? Colors.redAccent
                            : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 10),
                Text(
                  'المسموح: أحرف إنجليزية صغيرة وأرقام وشرطة سفلية فقط، من 3 إلى 20 خانة.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _continueIdentity,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('متابعة'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _continueAsGuest,
            icon: const Icon(Icons.explore_outlined),
            label: const Text('الدخول كضيف ومتابعة التصفح'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'تقدر تتصفح الكتب والأدوات كضيف، وتحتاج حساب Google للمشاركة في الدردشة الجماعية.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _avatarStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.photo_camera_back_rounded,
            eyebrow: 'الخطوة 2 من 3',
            title: 'صورتك، بطريقتك',
            subtitle: 'أضف صورة تساعد زملاءك على تمييز حسابك. هذه الخطوة اختيارية.',
            scheme: scheme,
          ),
          const SizedBox(height: 26),
          _glassCard(
            dark: dark,
            child: Column(
              children: [
                Container(
                  width: 164,
                  height: 164,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: .20),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    backgroundImage: _avatarBytes != null
                        ? MemoryImage(_avatarBytes!)
                        : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? NetworkImage(_avatarUrl!)
                            : null) as ImageProvider?,
                    child: _avatarBytes == null &&
                            (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? Icon(Icons.person_rounded, size: 72, color: scheme.onSurfaceVariant)
                        : null,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('المعرض'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickAvatar(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('الكاميرا'),
                      ),
                    ),
                  ],
                ),
                if (_avatarBytes != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _avatarBytes = null),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('إزالة الصورة المختارة'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : () => _goTo(2),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
            child: const Text('متابعة'),
          ),
          Center(
            child: TextButton(
              onPressed: _busy ? null : () => _goTo(2),
              child: const Text('تخطي هذه الخطوة'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studyStep(ColorScheme scheme, bool dark) {
    return _stepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroHeading(
            icon: Icons.school_rounded,
            eyebrow: 'الخطوة 3 من 3',
            title: 'شنو صفّك الدراسي؟',
            subtitle: 'نرتّب المحتوى والمواد حسب مرحلتك.',
            scheme: scheme,
          ),
          const SizedBox(height: 18),
          _glassCard(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FieldCaption('اختر صفك'),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _stages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.35,
                  ),
                  itemBuilder: (context, index) {
                    final label = _stages[index];
                    final selected = label == _stage;
                    return InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () => setState(() => _stage = label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 190),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: selected
                              ? LinearGradient(
                                  colors: [scheme.primary, scheme.tertiary],
                                )
                              : null,
                          color: selected ? null : scheme.surface.withValues(alpha: .72),
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : scheme.outlineVariant.withValues(alpha: .8),
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected ? Icons.check_circle_rounded : Icons.school_outlined,
                              size: 20,
                              color: selected ? Colors.white : scheme.primary,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? Colors.white : scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const _FieldCaption('الفئة العمرية'),
                DropdownButtonFormField<String>(
                  initialValue: _age,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.cake_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'under_13', child: Text('أقل من 13 سنة')),
                    DropdownMenuItem(value: '13_15', child: Text('13–15 سنة')),
                    DropdownMenuItem(value: '16_17', child: Text('16–17 سنة')),
                    DropdownMenuItem(value: '18_plus', child: Text('18 سنة فأكثر')),
                  ],
                  onChanged: (value) => setState(() => _age = value ?? _age),
                ),
                const SizedBox(height: 14),
                const _FieldCaption('الجنس'),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded)),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('ذكر')),
                    DropdownMenuItem(value: 'female', child: Text('أنثى')),
                  ],
                  onChanged: (value) => setState(() => _gender = value ?? _gender),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_busy ? 'جارٍ حفظ بياناتك...' : 'إنهاء وحفظ البيانات'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _stepScroll({required Widget child}) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: child,
      );

  Widget _heroHeading({
    required IconData icon,
    required String eyebrow,
    required String title,
    required String subtitle,
    required ColorScheme scheme,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [scheme.primary, scheme.tertiary]),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Text(
                eyebrow,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.6,
              fontSize: 13,
            ),
          ),
        ],
      );

  Widget _glassCard({required bool dark, required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: (dark ? const Color(0xFF1D2D45) : Colors.white)
              .withValues(alpha: dark ? .88 : .82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (dark ? Colors.white : const Color(0xFF8EA7CA))
                .withValues(alpha: dark ? .12 : .34),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .18 : .06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      );
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final Color accent;
  final bool dark;

  const _StepIndicator({
    required this.current,
    required this.accent,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
      child: Row(
        children: List.generate(5, (index) {
          if (index.isOdd) {
            final completed = index ~/ 2 < current;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 3,
                decoration: BoxDecoration(
                  color: completed ? accent : muted.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            );
          }
          final step = index ~/ 2;
          final active = step == current;
          final completed = step < current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: active ? 34 : 28,
            height: active ? 34 : 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || completed
                  ? accent
                  : (dark ? const Color(0xFF26364E) : Colors.white),
              border: Border.all(
                color: active || completed ? accent : muted,
                width: active ? 2 : 1,
              ),
            ),
            child: Center(
              child: Icon(
                completed ? Icons.check_rounded : Icons.circle,
                size: completed ? 17 : (active ? 9 : 7),
                color: active || completed
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FieldCaption extends StatelessWidget {
  final String text;
  const _FieldCaption(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );
}

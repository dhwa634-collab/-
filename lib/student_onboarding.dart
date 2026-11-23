import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'academic_stages.dart';
import 'student_community.dart';

/// First-install welcome and student setup. Existing installations bypass it
/// when their local app preferences already exist.
class StudentOnboardingGate extends StatefulWidget {
  final Widget child;
  const StudentOnboardingGate({super.key, required this.child});

  @override
  State<StudentOnboardingGate> createState() => _StudentOnboardingGateState();
}

class _StudentOnboardingGateState extends State<StudentOnboardingGate> {
  bool? _needsSetup;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('dalilak_student_onboarding_done_v1') ?? false;
    // Do not interrupt people who already used the app before this update.
    final hasExistingAppData = prefs.getKeys().isNotEmpty;
    if (!completed && hasExistingAppData) {
      await prefs.setBool('dalilak_student_onboarding_done_v1', true);
    }
    if (mounted) setState(() => _needsSetup = !completed && !hasExistingAppData);
  }

  void _finish() {
    if (mounted) setState(() => _needsSetup = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_needsSetup == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_needsSetup == true) {
      return StudentFirstRunSetup(onComplete: _finish);
    }
    return widget.child;
  }
}

class StudentFirstRunSetup extends StatefulWidget {
  final VoidCallback onComplete;
  const StudentFirstRunSetup({super.key, required this.onComplete});

  @override
  State<StudentFirstRunSetup> createState() => _StudentFirstRunSetupState();
}

class _StudentFirstRunSetupState extends State<StudentFirstRunSetup>
    with SingleTickerProviderStateMixin {
  String _age = '13_15';
  String _gender = 'male';
  AcademicStage _stage = AcademicStage.intermediateThird;
  bool _busy = false;
  late final AnimationController _animation = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 850),
  )..forward();

  Future<void> _save({required bool signIn}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dalilak_student_age_band_v1', _age);
      await prefs.setString('dalilak_student_gender_v1', _gender);
      await prefs.setString('dalilak_student_stage_v1', _stage.name);
      await AcademicStageController.select(_stage);

      if (signIn) {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => const StudentGoogleLoginScreen(),
        ));
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          if (mounted) setState(() => _busy = false);
          return;
        }
        final metadata = user.userMetadata ?? {};
        final name = (metadata['full_name'] ?? metadata['name'] ?? 'طالب')
            .toString().trim();
        await Supabase.instance.client.from('profiles').upsert({
          'user_id': user.id,
          'display_name': name.isEmpty ? 'طالب' : name.substring(0, name.length.clamp(0, 40)),
          'age_band': _age,
          'gender': _gender,
          'stage': _stage.label,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      await prefs.setBool('dalilak_student_onboarding_done_v1', true);
      widget.onComplete();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر حفظ البيانات حالياً. تحقق من الاتصال وحاول مجدداً.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _animation, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .08), end: Offset.zero,
              ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic)),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 34, 22, 24),
                children: [
                  Center(child: Container(
                    width: 92, height: 92,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF17427E), Color(0xFF347FE8)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 48),
                  )),
                  const SizedBox(height: 22),
                  const Text('أهلاً وسهلاً بيك! 🌟',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('خلّينا نتعرّف عليك حتى نرتّب تجربتك الدراسية بما يناسب مرحلتك.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant, height: 1.6)),
                  const SizedBox(height: 28),
                  DropdownButtonFormField<String>(
                    initialValue: _age,
                    decoration: const InputDecoration(labelText: 'الفئة العمرية'),
                    items: const [
                      DropdownMenuItem(value: 'under_13', child: Text('أقل من 13 سنة')),
                      DropdownMenuItem(value: '13_15', child: Text('13–15 سنة')),
                      DropdownMenuItem(value: '16_17', child: Text('16–17 سنة')),
                      DropdownMenuItem(value: '18_plus', child: Text('18 سنة فأكثر')),
                    ],
                    onChanged: (v) => setState(() => _age = v ?? _age),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(labelText: 'الجنس'),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('ذكر')),
                      DropdownMenuItem(value: 'female', child: Text('أنثى')),
                    ],
                    onChanged: (v) => setState(() => _gender = v ?? _gender),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<AcademicStage>(
                    initialValue: _stage,
                    decoration: const InputDecoration(labelText: 'الصف الدراسي'),
                    items: AcademicStage.values.map((s) =>
                      DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                    onChanged: (v) => setState(() => _stage = v ?? _stage),
                  ),
                  const SizedBox(height: 26),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _save(signIn: true),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(_busy ? 'جارٍ الحفظ...' : 'المتابعة باستخدام Google'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _save(signIn: false),
                    child: const Text('الدخول كضيف ومتابعة التصفح'),
                  ),
                  const SizedBox(height: 10),
                  Text('تقدر تتصفح الكتب والأدوات كضيف، وتحتاج حساب Google للمشاركة في الدردشة الجماعية.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant, height: 1.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

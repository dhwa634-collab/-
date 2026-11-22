import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'notification_messages.dart';
import 'package:third_intermediate_iraq/student_tools.dart' show ExamDates;

/// تذكيرات محلية فقط؛ لا ترسل بيانات الطالب إلى أي خادم.
class StudyNotificationService {
  StudyNotificationService._();
  static final StudyNotificationService instance = StudyNotificationService._();
  static const _enabledKey = 'smart_study_reminders_enabled_v1';
  static const _recentMessagesKey = 'smart_study_reminders_recent_messages_v1';
  static const _lastOpenedKey = 'smart_study_reminders_last_opened_v1';
  static const int _firstNotificationId = 4100;
  static const int _testNotificationId = 4199;
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Baghdad'));
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings,
        onDidReceiveNotificationResponse: _onNotificationTap);
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_enabledKey) ?? true;
      _initialized = true;
    } catch (error) {
      debugPrint('Study notifications initialization failed: $error');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    // يفتح Android التطبيق عبر MainActivity؛ لا نحتاج مساراً خاصاً.
  }

  Future<bool> requestPermission() async {
    if (!_initialized) await initialize();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final androidGranted = await android?.requestNotificationsPermission();
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final iosGranted = await ios?.requestPermissions(alert: true, badge: true, sound: true);
      return androidGranted ?? iosGranted ?? true;
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return false;
    }
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    if (!value) {
      await cancelAll();
      return;
    }
    await requestPermission();
    await rescheduleFromNow();
  }

  Future<void> cancelAll() async {
    try { await _plugin.cancelAll(); }
    catch (error) { debugPrint('Cancel notifications failed: $error'); }
  }

  /// عند عودة الطالب للتطبيق نلغي كل المواعيد حتى لا تصله تذكيرات وهو يستخدمه.
  Future<void> onAppResumed() async {
    if (!_initialized) await initialize();
    if (!_initialized) return;
    await cancelAll();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastOpenedKey, DateTime.now().toIso8601String());
    } catch (error) {
      debugPrint('Saving last opened time failed: $error');
    }
  }

  /// تبدأ سلسلة الغياب من لحظة خروج التطبيق إلى الخلفية.
  Future<void> onAppPaused() => rescheduleFromNow();

  int? get _daysUntilNextExam {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final dates = <DateTime?>[ExamDates.preparatory, ExamDates.ministerial]
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .where((date) => !date.isBefore(start))
        .toList()..sort();
    return dates.isEmpty ? null : dates.first.difference(start).inDays;
  }

  String _renderBody(String template) => template.replaceAll(
    '{days}', _daysUntilNextExam?.toString() ?? 'لم يُعلن موعده بعد');

  Future<void> rescheduleFromNow() async {
    if (!_initialized) await initialize();
    if (!_initialized || !enabled.value) return;
    try {
      await _plugin.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastOpenedKey, DateTime.now().toIso8601String());
      final recent = (prefs.getStringList(_recentMessagesKey) ?? const <String>[])
          .map(int.tryParse).whereType<int>().toSet();
      var indices = List<int>.generate(studyReminderMessages.length, (i) => i)
          .where((index) => !recent.contains(index)).toList();
      if (indices.length < 4) {
        indices = List<int>.generate(studyReminderMessages.length, (i) => i);
      }
      indices.shuffle(Random());
      const intervals = <Duration>[Duration(hours: 24), Duration(hours: 48), Duration(days: 4), Duration(days: 7)];
      for (var i = 0; i < intervals.length; i++) {
        final messageIndex = indices[i];
        final message = studyReminderMessages[messageIndex];
        final scheduled = _nextAllowedTime(tz.TZDateTime.now(tz.local).add(intervals[i]));
        await _plugin.zonedSchedule(
          _firstNotificationId + i, message.title, _renderBody(message.body), scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'study_retention_reminders', 'تذكيرات السچ والدراسة',
              channelDescription: 'تذكيرات دراسية محلية خفيفة عند الغياب عن التطبيق',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              category: AndroidNotificationCategory.reminder,
              playSound: true, enableVibration: true,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'study-reminder',
        );
      }
      await prefs.setStringList(_recentMessagesKey,
          indices.take(intervals.length).map((index) => index.toString()).toList());
    } catch (error) {
      debugPrint('Scheduling study reminders failed: $error');
    }
  }

  tz.TZDateTime _nextAllowedTime(tz.TZDateTime candidate) {
    final minutes = candidate.hour * 60 + candidate.minute;
    if (minutes < 600) {
      return tz.TZDateTime(tz.local, candidate.year, candidate.month, candidate.day, 10);
    }
    if (minutes > 1290) {
      final tomorrow = candidate.add(const Duration(days: 1));
      return tz.TZDateTime(tz.local, tomorrow.year, tomorrow.month, tomorrow.day, 10);
    }
    return candidate;
  }

  Future<void> showTestNotification() async {
    if (!_initialized) await initialize();
    if (!_initialized) return;
    final message = studyReminderMessages[Random().nextInt(studyReminderMessages.length)];
    await _plugin.show(
      _testNotificationId, message.title, _renderBody(message.body),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_retention_reminders', 'تذكيرات السچ والدراسة',
          channelDescription: 'تذكيرات دراسية محلية خفيفة عند الغياب عن التطبيق',
          importance: Importance.high, priority: Priority.high,
          category: AndroidNotificationCategory.reminder, playSound: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'study-reminder-test',
    );
  }
}
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';
import 'settings_service.dart';
import 'streak_service.dart';

/// Background entry point: Android's WorkManager runs this at ~21:45Z.
@pragma('vm:entry-point')
void streakCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await StreakReminder.runBackgroundCheck();
    } catch (e) {
      debugPrint('Streak check failed: $e');
    }
    return true;
  });
}

/// "Your streak ends at 00:00 UTC" warning, a little over 2 hours ahead.
///
/// The check is set for 21:45Z because Android batches background work and
/// may start it some minutes late; the notification states the actual time
/// left.
///
/// Android: a background task wakes at ~21:45Z, checks Wavelog (and contacts
/// logged on this phone) and only notifies when there's no QSO today.
/// iPhone: background runs aren't dependable, so a notification is scheduled
/// for 21:45Z whenever the app sees the streak at risk, and cancelled once it
/// sees a QSO today.
class StreakReminder {
  static const String uniqueName = 'streak-check';
  static const String taskName = 'streakCheck';
  static const int notificationId = 4201;
  static const int warnHourUtc = 21;
  static const int warnMinuteUtc = 45;
  static const String keyPermissionAsked = 'streak_permission_asked';

  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _notificationsReady = false;

  /// Next 21:45Z at or after [nowUtc] (today's if it's still ahead).
  static DateTime nextCheck(DateTime nowUtc) {
    final today = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, warnHourUtc, warnMinuteUtc);
    return nowUtc.isBefore(today) ? today : today.add(const Duration(days: 1));
  }

  static String title(int days) => days == 1
      ? 'Your 1-day streak ends at 00:00 UTC'
      : 'Your $days-day streak ends at 00:00 UTC';

  /// "No contacts logged today (UTC). 2h 15m left to make one and keep it going."
  static String body(Duration left) {
    final h = left.inHours, m = left.inMinutes.remainder(60);
    final when = h > 0 ? '${h}h ${m}m' : '${m}m';
    return 'No contacts logged today (UTC). $when left to make one and keep it going.';
  }

  static bool get _android => !kIsWeb && Platform.isAndroid;
  static bool get _ios => !kIsWeb && Platform.isIOS;

  /// Call once at app start, before [schedule].
  static Future<void> initialize() async {
    if (_android) await Workmanager().initialize(streakCallbackDispatcher);
  }

  static Future<void> _initNotifications() async {
    if (_notificationsReady) return;
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_streak'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _notificationsReady = true;
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'streak',
      'Streak reminders',
      channelDescription: 'Warns at 21:45 UTC when the daily QSO streak is about to end',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<bool> _enabledWithV2Key() async {
    if (!await AppSettings.getStreakReminderEnabled()) return false;
    return await StreakService.v2Endpoint() != null;
  }

  /// Lets [schedule] ask for notification permission again (the user just
  /// switched the reminder on).
  static Future<void> allowPermissionPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyPermissionAsked);
  }

  /// Asks for notification permission once; Android and iOS remember the answer.
  static Future<void> _requestPermission() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(keyPermissionAsked) ?? false) return;
    await prefs.setBool(keyPermissionAsked, true);
    await _initNotifications();
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  }

  /// (Re)plans the reminder from the app: called at start, after the setting
  /// changes, and (iPhone) whenever the streak is refreshed.
  static Future<void> schedule({StreakStatus? status}) async {
    try {
      if (!await _enabledWithV2Key()) {
        await cancel();
        return;
      }
      await _requestPermission();
      final now = DateTime.now().toUtc();
      if (_android) {
        await Workmanager().registerOneOffTask(
          uniqueName,
          taskName,
          initialDelay: nextCheck(now).difference(now),
          existingWorkPolicy: ExistingWorkPolicy.replace,
        );
      } else if (_ios && status != null) {
        await _scheduleIos(status, now);
      }
    } catch (e) {
      debugPrint('Could not schedule streak reminder: $e');
    }
  }

  static Future<void> _scheduleIos(StreakStatus status, DateTime now) async {
    final warnAt = DateTime.utc(now.year, now.month, now.day, warnHourUtc, warnMinuteUtc);
    if (!status.atRisk || !now.isBefore(warnAt)) {
      await _notifications.cancel(id: notificationId);
      return;
    }
    tzdata.initializeTimeZones();
    await _notifications.zonedSchedule(
      id: notificationId,
      scheduledDate: tz.TZDateTime.from(warnAt, tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title(status.days),
      body: body(StreakStatus(days: status.days, qsoToday: false, nowUtc: warnAt).timeLeft),
    );
  }

  /// Switches the reminder off (setting disabled, or no v2 key).
  static Future<void> cancel() async {
    if (_android) await Workmanager().cancelByUniqueName(uniqueName);
    await _initNotifications();
    await _notifications.cancel(id: notificationId);
  }

  /// Shows the warning right away, as it would look at 21:45Z with the
  /// current streak (development builds only, to check its look).
  static Future<void> showTest() async {
    await allowPermissionPrompt();
    await _requestPermission();
    final status = await StreakService.current(offline: true);
    final days = (status?.days ?? 0) > 0 ? status!.days : 1;
    await _notifications.show(
      id: notificationId,
      title: title(days),
      body: body(const Duration(hours: 2, minutes: 15)),
      notificationDetails: _details,
    );
  }

  /// Runs in the background at ~21:45Z (Android).
  static Future<void> runBackgroundCheck() async {
    if (!await _enabledWithV2Key()) return;
    final offline = (await AppSettings.getString(AppSettings.keyOfflineMode)) == 'true';
    final status = await StreakService.current(offline: offline);
    if (status != null && status.atRisk) {
      await _initNotifications();
      await _notifications.show(
        id: notificationId,
        title: title(status.days),
        body: body(status.timeLeft),
        notificationDetails: _details,
      );
    }
    // Tomorrow's check. Appended after this run rather than replacing it.
    final now = DateTime.now().toUtc();
    await Workmanager().registerOneOffTask(
      uniqueName,
      taskName,
      initialDelay: nextCheck(now.add(const Duration(minutes: 1))).difference(now),
      existingWorkPolicy: ExistingWorkPolicy.update,
    );
  }
}

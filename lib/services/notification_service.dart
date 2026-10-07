import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/med_plan_entry.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int _weekdayIdMultiplier = 10;
  static const int _notificationIdNamespace = 1000000000;
  bool _permissionsRequested = false;

  Future<void> init() async {
    tz_data.initializeTimeZones();
    await _setDeviceTimeZone();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _setDeviceTimeZone() async {
    try {
      final localTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimeZone.identifier));
    } catch (error) {
      // Keep the app usable on platforms where the native timezone plugin is
      // unavailable. Reminder scheduling should be verified on supported
      // devices before a release.
      debugPrint('Lokale Zeitzone konnte nicht gelesen werden: $error');
    }
  }

  Future<void> _requestPermissionsIfNeeded() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;

    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } catch (error) {
      debugPrint('Android-Erinnerungsberechtigung nicht verfügbar: $error');
    }

    final ios = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    try {
      await ios?.requestPermissions(alert: true, badge: false, sound: true);
    } catch (error) {
      debugPrint('iOS-Erinnerungsberechtigung nicht verfügbar: $error');
    }
  }

  Future<void> scheduleMedicationReminder(MedPlanEntry entry) async {
    final id = entry.id;
    if (id == null) {
      throw ArgumentError('Ein Medikament benötigt vor dem Reminder eine ID.');
    }

    await cancelReminder(id);
    if (!entry.isActive || !entry.isReminderActive) return;
    await _requestPermissionsIfNeeded();

    final timeParts = entry.time.split(':');
    if (timeParts.length != 2) {
      throw FormatException('Ungültige Erinnerungszeit: ${entry.time}');
    }
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 ||
        minute < 0 || minute > 59) {
      throw FormatException('Ungültige Erinnerungszeit: ${entry.time}');
    }

    final weekdays = entry.selectedDays
        .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
        .toSet()
        .toList()
      ..sort();

    if (weekdays.isEmpty) return;

    final now = tz.TZDateTime.now(tz.local);
    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final canUseExactAlarms =
        await android?.canScheduleExactNotifications() ?? false;
    final scheduleMode = canUseExactAlarms
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final title = 'Erinnerung: ${entry.drugName}';
    final body = entry.instructions.trim().isEmpty
        ? 'Dosis: ${entry.dosage}'
        : 'Dosis: ${entry.dosage} (${entry.instructions})';

    for (final weekday in weekdays) {
      final daysUntil = (weekday - now.weekday + DateTime.daysPerWeek) %
          DateTime.daysPerWeek;
      var firstOccurrence = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + daysUntil,
        hour,
        minute,
      );
      if (!firstOccurrence.isAfter(now)) {
        firstOccurrence = tz.TZDateTime(
          tz.local,
          firstOccurrence.year,
          firstOccurrence.month,
          firstOccurrence.day + DateTime.daysPerWeek,
          hour,
          minute,
        );
      }

      await _notificationsPlugin.zonedSchedule(
        _notificationId(id, weekday),
        title,
        body,
        firstOccurrence,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_channel',
            'Medikamente',
            channelDescription: 'Erinnerungen für Medikamente',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  int _notificationId(int medicationId, int weekday) =>
      _notificationIdNamespace + medicationId * _weekdayIdMultiplier + weekday;

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelReminder(int medicationId) async {
    // Cancel the old single-reminder ID for upgrades, then each weekday slot.
    await _notificationsPlugin.cancel(medicationId);
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      await _notificationsPlugin.cancel(_notificationId(medicationId, weekday));
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}

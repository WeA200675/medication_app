import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/med_plan_entry.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // v17 Syntax: Positional Argument
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // v17 Syntax: Positional Arguments
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // Methode für den Aufruf mit savedEntry aus med_plan_screen.dart
  Future<void> scheduleMedicationReminder(MedPlanEntry entry) async {
    if (!entry.isReminderActive) return;

    final int id = entry.id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final String title = 'Erinnerung: ${entry.drugName}';
    final String body = 'Dosis: ${entry.dosage} (${entry.instructions})';

    DateTime scheduledDate = DateTime.now();
    try {
      final parts = entry.time.split(':');
      final now = DateTime.now();
      scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
    } catch (_) {}

    await scheduleNotification(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
    );
  }

  Future<void> cancelNotification(int id) async {
    // v17 Syntax: Positional Argument
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelReminder(int id) async {
    await cancelNotification(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
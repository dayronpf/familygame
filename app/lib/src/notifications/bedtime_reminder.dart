import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Recordatorio diario de la hora del cuento (para el adulto, nunca para el niño). Lo programa el teléfono: no
/// hace falta servidor ni conexión.
abstract class BedtimeReminder {
  /// Pide permiso (Android 13+, iOS) y programa el aviso cada día a [time]. `false` si no dieron permiso.
  Future<bool> schedule(TimeOfDay time);

  Future<void> cancel();
}

/// El de verdad, con las notificaciones locales del teléfono.
class LocalBedtimeReminder implements BedtimeReminder {
  LocalBedtimeReminder([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int _id = 2026;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Sin zona conocida se usa UTC; mejor un aviso a otra hora que ninguno.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  Future<bool> _askPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    return true;
  }

  @override
  Future<bool> schedule(TimeOfDay time) async {
    await _init();
    if (!await _askPermission()) return false;
    await _plugin.cancel(id: _id);
    await _plugin.zonedSchedule(
      id: _id,
      title: '🌙 Es la hora del cuento',
      body: '¿Qué cuento leemos esta noche?',
      scheduledDate: nextInstanceOf(time, tz.TZDateTime.now(tz.local)),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'hora_del_cuento',
          'Hora del cuento',
          channelDescription: 'Un aviso al día a la hora del cuento',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Sin alarma exacta: no hace falta el permiso especial y unos minutos de margen no importan.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return true;
  }

  @override
  Future<void> cancel() async {
    await _init();
    await _plugin.cancel(id: _id);
  }
}

/// La próxima vez que el reloj marque [time] a partir de [now] (hoy si aún no pasó; si no, mañana).
tz.TZDateTime nextInstanceOf(TimeOfDay time, tz.TZDateTime now) {
  var at = tz.TZDateTime(
      now.location, now.year, now.month, now.day, time.hour, time.minute);
  if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
  return at;
}

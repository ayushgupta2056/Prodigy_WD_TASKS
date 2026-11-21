import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/dates.dart';
import '../core/format.dart';
import '../core/models.dart';

/// Android only: a reminder at 1 pm on check-out day for every stay that has
/// no in-hand amount yet ("How much did you get in hand?").
class InHandReminders {
  InHandReminders._();
  static final instance = InHandReminders._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String _lastSignature = '';

  bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (!_supported || _ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    _ready = true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('in_hand', 'In-hand reminders',
        channelDescription: 'Asks how much you received after each stay', importance: Importance.defaultImportance),
  );

  Future<void> schedule(List<Booking> bookings) async {
    if (!_supported || !_ready) return;
    final upcoming = bookings.where((b) => b.isActive && b.pendingInHand && b.checkOut.isAfter(today())).toList();
    final signature = upcoming.map((b) => '${b.id}:${toIso(b.checkOut)}').join(',');
    if (signature == _lastSignature) return;
    _lastSignature = signature;
    await _plugin.cancelAll();
    for (final b in upcoming.take(40)) {
      final at = tz.TZDateTime(tz.local, b.checkOut.year, b.checkOut.month, b.checkOut.day, 13);
      if (at.isBefore(tz.TZDateTime.now(tz.local))) continue;
      await _plugin.zonedSchedule(
        id: b.id.hashCode & 0x7fffffff,
        scheduledDate: at,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: '${shortName(b.guestName)} checks out today',
        body: 'How much did you receive in hand for ${plural(b.nights, 'night')} via ${b.platform}?',
        payload: b.id,
      );
    }
  }
}

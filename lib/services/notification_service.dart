import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/models.dart';
import '../utils/session_date_format.dart';

String buildNewSessionNotificationPreview(List<Session> sessions) => sessions
    .take(3)
    .map(
      (session) =>
          '${formatSessionDate(session.date)} ${session.time} ${session.hall}',
    )
    .join('；');

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize({bool requestPermission = false}) async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      ohos: OhosInitializationSettings('icon'),
    );
    await _plugin.initialize(settings);
    _initialized = true;
    if (requestPermission) await requestPermissions();
  }

  Future<bool?> requestPermissions() async {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      return _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (Platform.isMacOS) {
      return _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.operatingSystem == 'ohos') {
      return _plugin
          .resolvePlatformSpecificImplementation<
              OhosFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    return null;
  }

  Future<bool?> areNotificationsEnabled() async {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      return _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
    }
    if (Platform.operatingSystem == 'ohos') {
      return _plugin
          .resolvePlatformSpecificImplementation<
              OhosFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
    }
    return null;
  }

  Future<void> showNewSessions(
    MovieSubscription subscription,
    List<Session> sessions,
  ) async {
    await initialize();
    final preview = buildNewSessionNotificationPreview(sessions);
    await _plugin.show(
      subscription.key.hashCode & 0x7fffffff,
      '${subscription.movieName} 新增 ${sessions.length} 个场次',
      '${subscription.cinema.name}｜$preview',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'schedule_changes',
          '排片变更',
          channelDescription: '订阅影片出现新场次时提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
        ohos: OhosNotificationDetails(
          OhosNotificationSlotType.CONTENT_INFORMATION,
          slotDesc: '订阅影片出现新场次时提醒',
          importance: OhosImportance.high,
        ),
      ),
      payload: subscription.key,
    );
  }
}

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Strings needed outside of a widget tree (background isolate, notifications).
const Map<String, Map<String, String>> _strings = {
  'en': {
    'newMessage': 'New message',
    'newMessageFrom': 'New message from {name}',
    'incomingCall': 'Incoming call',
    'incomingCallFrom': '{name} is calling',
    'serviceTitle': 'Arcana is connected',
    'serviceText': 'Ready to receive messages',
    'channelMessages': 'Messages',
    'channelCalls': 'Calls',
  },
  'de': {
    'newMessage': 'Neue Nachricht',
    'newMessageFrom': 'Neue Nachricht von {name}',
    'incomingCall': 'Eingehender Anruf',
    'incomingCallFrom': '{name} ruft an',
    'serviceTitle': 'Arcana ist verbunden',
    'serviceText': 'Bereit, Nachrichten zu empfangen',
    'channelMessages': 'Nachrichten',
    'channelCalls': 'Anrufe',
  },
  'ru': {
    'newMessage': 'Новое сообщение',
    'newMessageFrom': 'Новое сообщение от {name}',
    'incomingCall': 'Входящий звонок',
    'incomingCallFrom': '{name} звонит',
    'serviceTitle': 'Arcana подключена',
    'serviceText': 'Готова получать сообщения',
    'channelMessages': 'Сообщения',
    'channelCalls': 'Звонки',
  },
};

Future<String> currentLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('locale');
  final lang = (saved == null || saved.isEmpty) ? Platform.localeName.split(RegExp('[_-]')).first : saved;
  return _strings.containsKey(lang) ? lang : 'en';
}

Future<String> tr(String key, [Map<String, String> args = const {}]) async {
  var s = _strings[await currentLanguage()]![key] ?? _strings['en']![key] ?? key;
  args.forEach((k, v) => s = s.replaceAll('{$k}', v));
  return s;
}

class Notifications {
  static final plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static void Function(String? payload)? onTap;
  static const callNotificationId = 777001;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
    );
  }

  static Future<String?> launchPayload() async {
    final d = await plugin.getNotificationAppLaunchDetails();
    return (d?.didNotificationLaunchApp ?? false) ? d?.notificationResponse?.payload : null;
  }

  static Future<void> requestPermission() async {
    await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static int idFor(String chat) => chat.hashCode & 0x7fffffff;

  static Future<void> showMessage({required String chat, required String title, required String body}) async {
    await init();
    await plugin.show(
      id: idFor(chat),
      title: title,
      body: body,
      payload: chat,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'messages',
          await tr('channelMessages'),
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.private,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> showIncomingCall({required String chat, required String title, required String body}) async {
    await init();
    await plugin.show(
      id: callNotificationId,
      title: title,
      body: body,
      payload: 'call:$chat',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'calls',
          await tr('channelCalls'),
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
          ongoing: true,
          timeoutAfter: 45000,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        ),
        iOS: const DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
      ),
    );
  }

  static Future<void> cancelChat(String chat) => plugin.cancel(id: idFor(chat));
  static Future<void> cancelCall() => plugin.cancel(id: callNotificationId);
}

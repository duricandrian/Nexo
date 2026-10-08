import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/firebase_config.dart';
import 'notifications.dart';

/// Foreground service that keeps the microphone available while a call is
/// running in the background. New messages are announced through FCM.
class BackgroundService {
  static Future<void> init() async {
    await PushService.init();
    if (!Platform.isAndroid) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'connection',
        channelName: 'Connection',
        channelDescription: 'Keeps an ongoing call connected',
        channelImportance: NotificationChannelImportance.MIN,
        priority: NotificationPriority.MIN,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Starts the call service when [microphone] is true, otherwise stops it.
  static Future<void> start({bool microphone = false}) async {
    if (!Platform.isAndroid) return;
    if (!microphone) {
      if (await FlutterForegroundTask.isRunningService) await FlutterForegroundTask.stopService();
      return;
    }
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 4711,
      serviceTypes: [ForegroundServiceTypes.microphone],
      notificationTitle: await tr('serviceTitle'),
      notificationText: await tr('serviceText'),
      notificationIcon: const NotificationIcon(metaDataName: 'ch.nexo.messenger.NOTIFICATION_ICON'),
      callback: backgroundEntry,
    );
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await FlutterForegroundTask.stopService();
  }
}

@pragma('vm:entry-point')
void backgroundEntry() {
  FlutterForegroundTask.setTaskHandler(_CallTaskHandler());
}

class _CallTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();
}

/// Content-free FCM wake-ups: the push only says "something from ID X"; the
/// app fetches and decrypts the envelope itself.
class PushService {
  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
  }

  static StreamSubscription<String>? _refresh;

  /// Stores this device's FCM token so the backend can wake it up.
  static Future<void> register(String id) async {
    if (FirebaseConfig.emulatorHost.isNotEmpty) return;
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      Future<void> save(String? token) async {
        if (token == null) return;
        await FirebaseFirestore.instance.doc('private/$id').set({
          'fcm': FieldValue.arrayUnion([token])
        }, SetOptions(merge: true));
      }

      await save(await fm.getToken());
      _refresh ??= fm.onTokenRefresh.listen(save);
    } catch (e) {
      debugPrint('push register: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  final d = message.data;
  if (d['t'] != 'notify' || d['from'] == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  await Notifications.init();
  final from = d['from'] as String;
  final name = await _contactName(from);
  if (d['kind'] == 'call') {
    await Notifications.showIncomingCall(
        chat: 'c:$from', title: await tr('incomingCall'), body: await tr('incomingCallFrom', {'name': name}));
  } else {
    await Notifications.showMessage(chat: 'c:$from', title: name, body: await tr('newMessage'));
  }
}

Future<String> _contactName(String id) async {
  try {
    final db = await openDatabase(p.join(await getDatabasesPath(), 'nexo.db'), readOnly: true, singleInstance: false);
    final rows = await db.query('contacts', columns: ['name', 'nick'], where: 'id = ?', whereArgs: [id]);
    await db.close();
    if (rows.isNotEmpty) {
      final name = rows.first['name'] as String?;
      final nick = rows.first['nick'] as String?;
      if (name != null && name.isNotEmpty) return name;
      if (nick != null && nick.isNotEmpty) return '~$nick';
    }
  } catch (_) {}
  return id;
}

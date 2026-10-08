import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../core/config.dart';
import 'connection.dart';
import 'identity.dart';
import 'notifications.dart';

/// Keeps a lightweight "notify" connection open while the UI is not running so
/// new messages and calls can be announced. Message content stays on the
/// server until the app itself connects and decrypts it.
class BackgroundService {
  static Future<void> init() async {
    if (!Platform.isAndroid) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'connection',
        channelName: 'Connection',
        channelDescription: 'Keeps the encrypted connection open',
        channelImportance: NotificationChannelImportance.MIN,
        priority: NotificationPriority.MIN,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start({bool microphone = false}) async {
    if (!Platform.isAndroid) return;
    final types = [ForegroundServiceTypes.remoteMessaging, if (microphone) ForegroundServiceTypes.microphone];
    if (await FlutterForegroundTask.isRunningService) {
      if (!microphone && _micActive == false) return;
      await FlutterForegroundTask.stopService();
    }
    _micActive = microphone;
    await FlutterForegroundTask.startService(
      serviceId: 4711,
      serviceTypes: types,
      notificationTitle: await tr('serviceTitle'),
      notificationText: await tr('serviceText'),
      notificationIcon: const NotificationIcon(metaDataName: 'ch.arcana.messenger.NOTIFICATION_ICON'),
      callback: backgroundEntry,
    );
  }

  static bool _micActive = false;

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await FlutterForegroundTask.stopService();
  }
}

@pragma('vm:entry-point')
void backgroundEntry() {
  FlutterForegroundTask.setTaskHandler(_NotifyHandler());
}

class _NotifyHandler extends TaskHandler {
  Connection? _conn;
  StreamSubscription? _sub;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    final identity = await Identity.load();
    if (identity == null) return;
    await Notifications.init();
    _conn = Connection(url: await AppConfig.serverUrl(), id: identity.id, secretKey: identity.secretKey, mode: 'notify');
    _sub = _conn!.messages.listen(_onMessage);
    _conn!.start();
  }

  Future<String> _name(String id) async {
    try {
      final db = await openDatabase(p.join(await getDatabasesPath(), 'arcana.db'), readOnly: true, singleInstance: false);
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

  Future<void> _onMessage(Map<String, dynamic> m) async {
    if (m['t'] != 'notify') return;
    final from = m['from'] as String;
    final name = await _name(from);
    if (m['kind'] == 'call') {
      await Notifications.showIncomingCall(
          chat: 'c:$from', title: await tr('incomingCall'), body: await tr('incomingCallFrom', {'name': name}));
    } else {
      await Notifications.showMessage(chat: 'c:$from', title: name, body: await tr('newMessage'));
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) => _conn?.kick();

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _sub?.cancel();
    await _conn?.close();
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();
}

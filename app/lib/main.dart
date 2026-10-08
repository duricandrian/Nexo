import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'core/firebase_config.dart';
import 'core/l10n.dart';
import 'core/settings.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'services/background.dart';
import 'services/call_service.dart';
import 'services/identity.dart';
import 'services/messenger.dart';
import 'services/notifications.dart';
import 'ui/screens/call_screen.dart';
import 'ui/screens/chat_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/onboarding_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseConfig.init();
  FlutterForegroundTask.initCommunicationPort();
  await Notifications.init();
  await BackgroundService.init();
  final settings = await AppSettings.load();
  final identity = await Identity.load();
  runApp(NexoApp(settings: settings, identity: identity));
}

class NexoApp extends StatefulWidget {
  final AppSettings settings;
  final Identity? identity;
  const NexoApp({super.key, required this.settings, this.identity});

  @override
  State<NexoApp> createState() => _NexoAppState();
}

class _NexoAppState extends State<NexoApp> with WidgetsBindingObserver {
  Messenger? _messenger;
  CallService? _calls;
  bool _locked = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = widget.settings.appLock;
    Notifications.onTap = _onNotificationTap;
    if (widget.identity != null) _startSession(widget.identity!);
  }

  Future<void> _startSession(Identity identity) async {
    final m = await Messenger.create(identity);
    m.start();
    final calls = CallService(m);
    calls.onCallUi = _showCallScreen;
    setState(() {
      _messenger = m;
      _calls = calls;
    });
    // The navigator keeps its initial route across the rebuild, so replace
    // onboarding/splash explicitly once the providers are in place.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    });
    BackgroundService.start().catchError((_) {});
    final payload = await Notifications.launchPayload();
    if (payload != null) _onNotificationTap(payload);
  }

  void _onNotificationTap(String? payload) {
    if (payload == null || _messenger == null) return;
    if (payload.startsWith('call:')) {
      _showCallScreen();
      return;
    }
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ChatScreen(chatKey: payload)));
  }

  bool _callScreenOpen = false;
  void _showCallScreen() {
    if (_callScreenOpen || _calls == null || !_calls!.busy) return;
    _callScreenOpen = true;
    navigatorKey.currentState
        ?.push(MaterialPageRoute(builder: (_) => const CallScreen(), fullscreenDialog: true))
        .then((_) => _callScreenOpen = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final m = _messenger;
    if (state == AppLifecycleState.resumed) {
      m?.inForeground = true;
      m?.conn.kick();
      if (m?.activeChat != null) m!.markRead(m.activeChat!);
      if (widget.settings.appLock &&
          _pausedAt != null &&
          DateTime.now().difference(_pausedAt!).inSeconds >= widget.settings.lockTimeoutSec &&
          !(_calls?.busy ?? false)) {
        setState(() => _locked = true);
      }
      _pausedAt = null;
    } else if (state == AppLifecycleState.paused) {
      m?.inForeground = false;
      _pausedAt = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.settings,
      child: Consumer<AppSettings>(builder: (context, s, _) {
        final app = MaterialApp(
          navigatorKey: navigatorKey,
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: s.themeMode,
          locale: s.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Stack(children: [
            child!,
            if (_locked) LockScreen(onUnlocked: () => setState(() => _locked = false)),
          ]),
          home: _messenger == null
              ? (widget.identity == null ? OnboardingScreen(onDone: _startSession) : const _Splash())
              : const HomeScreen(),
        );
        if (_messenger == null) return app;
        return MultiProvider(providers: [
          ChangeNotifierProvider.value(value: _messenger!),
          ChangeNotifierProvider.value(value: _calls!),
        ], child: app);
      }),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _auth = LocalAuthentication();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    _busy = true;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        widget.onUnlocked();
        return;
      }
      if (!mounted) return;
      final ok = await _auth.authenticate(localizedReason: context.l.unlockReason, persistAcrossBackgrounding: true);
      if (ok) widget.onUnlocked();
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 72, color: brandColor),
          const SizedBox(height: 16),
          Text(context.l.appLocked, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _unlock, icon: const Icon(Icons.fingerprint), label: Text(context.l.unlock)),
        ]),
      ),
    );
  }
}

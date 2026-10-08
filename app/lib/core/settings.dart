import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  Locale? locale;
  ThemeMode themeMode = ThemeMode.system;
  bool appLock = false;
  int lockTimeoutSec = 30;
  bool enterSends = false;
  double fontScale = 1.0;

  static Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final s = AppSettings();
    final l = p.getString('locale');
    s.locale = (l == null || l.isEmpty) ? null : Locale(l);
    s.themeMode = ThemeMode.values[p.getInt('theme') ?? 0];
    s.appLock = p.getBool('app_lock') ?? false;
    s.lockTimeoutSec = p.getInt('lock_timeout') ?? 30;
    s.enterSends = p.getBool('enter_sends') ?? false;
    return s;
  }

  Future<void> setLocale(String? code) async {
    locale = code == null ? null : Locale(code);
    (await SharedPreferences.getInstance()).setString('locale', code ?? '');
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    (await SharedPreferences.getInstance()).setInt('theme', m.index);
    notifyListeners();
  }

  Future<void> setAppLock(bool v) async {
    appLock = v;
    (await SharedPreferences.getInstance()).setBool('app_lock', v);
    notifyListeners();
  }

  Future<void> setLockTimeout(int v) async {
    lockTimeoutSec = v;
    (await SharedPreferences.getInstance()).setInt('lock_timeout', v);
    notifyListeners();
  }

  Future<void> setEnterSends(bool v) async {
    enterSends = v;
    (await SharedPreferences.getInstance()).setBool('enter_sends', v);
    notifyListeners();
  }
}

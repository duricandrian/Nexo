import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const defaultServer = String.fromEnvironment('SERVER_URL', defaultValue: 'wss://chat.kandacodelab.com/ws');
  static const appName = 'Nexo';
  static const privacyUrl = String.fromEnvironment('PRIVACY_URL', defaultValue: 'https://chat.kandacodelab.com/privacy');

  static Future<String> serverUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_url') ?? defaultServer;
  }

  static Uri blobBase(String wsUrl) {
    final u = Uri.parse(wsUrl);
    return u.replace(scheme: u.scheme == 'wss' ? 'https' : 'http', path: '');
  }
}

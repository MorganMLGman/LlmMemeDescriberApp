import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _urlKey = 'backend_url';
  static const String _tokenKey = 'access_token';

  static Future<void> saveSettings(String url, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url);
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_urlKey);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await prefs.remove(_tokenKey);
  }
}
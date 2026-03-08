import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  static const _tokenKey = 'auth_token';
  static const _usernameKey = 'username';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Future<void> saveContributions(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('github_data_json', json);
  }

  Future<void> saveLayout(Map<String, double> offsets, String font) async {
    final prefs = await SharedPreferences.getInstance();
    offsets.forEach((key, value) async {
      await prefs.setDouble('layout_y_$key', value);
    });
    await prefs.setString('font_family', font);
  }

  Future<Map<String, double>> getLayoutOffsets() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'date': prefs.getDouble('layout_y_date') ?? 0.0,
      'map': prefs.getDouble('layout_y_map') ?? 0.0,
      'total': prefs.getDouble('layout_y_total') ?? 0.0,
      'user': prefs.getDouble('layout_y_user') ?? 0.0,
      'info': prefs.getDouble('layout_y_info') ?? 0.0,
    };
  }

  Future<String> getFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('font_family') ?? 'sans-serif';
  }

  Future<void> saveCredentials(
    String clientId,
    String clientSecret,
    String redirectUri,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('github_client_id', clientId);
    await prefs.setString('github_client_secret', clientSecret);
    await prefs.setString('github_redirect_uri', redirectUri);
  }

  Future<Map<String, String>> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'clientId': prefs.getString('github_client_id') ?? '',
      'clientSecret': prefs.getString('github_client_secret') ?? '',
      'redirectUri': prefs.getString('github_redirect_uri') ?? '',
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove('github_data_json');
    await prefs.remove('github_client_id');
    await prefs.remove('github_client_secret');
    await prefs.remove('github_redirect_uri');
  }
}

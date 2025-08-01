import 'package:shared_preferences/shared_preferences.dart';

class AdminAuthService {
  static const String _adminPasswordKey = 'admin_password';
  static const String _isAdminKey = 'is_admin_authenticated';
  static const String _loginTimeKey = 'admin_login_time';

  // Default admin password - change this in production!
  static const String _defaultPassword = 'admin123';

  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isAdminKey) ?? false;

    if (!isLoggedIn) return false;

    // Check for session timeout (8 hours)
    final loginTime = prefs.getString(_loginTimeKey);
    if (loginTime != null) {
      final loginDateTime = DateTime.parse(loginTime);
      final now = DateTime.now();
      final difference = now.difference(loginDateTime);

      // Session expires after 8 hours
      if (difference.inHours >= 8) {
        await logout();
        return false;
      }
    }

    return true;
  }

  static Future<bool> authenticate(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPassword =
        prefs.getString(_adminPasswordKey) ?? _defaultPassword;

    // Check for admin credentials
    if ((email == 'admin@admin.com' || email == 'admin') && 
        password == storedPassword) {
      await prefs.setBool(_isAdminKey, true);
      await prefs.setString(_loginTimeKey, DateTime.now().toIso8601String());
      return true;
    }
    return false;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isAdminKey, false);
    await prefs.remove(_loginTimeKey);
  }

  static Future<void> changePassword(String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adminPasswordKey, newPassword);
  }

  static Future<bool> isPasswordSet() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPassword = prefs.getString(_adminPasswordKey);
    return storedPassword != null && storedPassword.isNotEmpty;
  }
}

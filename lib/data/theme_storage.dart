// ignore_for_file: deprecated_member_use

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class ThemeStorage {
  static const _darkKey = 'dark_mode';
  static const _colorKey = 'theme_color';

  static Future<void> saveTheme(bool darkMode, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkKey, darkMode);
    await prefs.setInt(_colorKey, color.value);
  }

  static Future<bool> loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkKey) ?? false;
  }

  static Future<Color> loadThemeColor() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_colorKey);
    if (value != null) return Color(value);
    return const Color(0xFF7C83FD);
  }
}

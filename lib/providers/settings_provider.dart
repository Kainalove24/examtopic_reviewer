import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sound_service.dart';

class SettingsProvider extends ChangeNotifier {
  // Settings keys
  static const String _aiExplanationsEnabledKey = 'ai_explanations_enabled';
  static const String _autoSaveProgressKey = 'auto_save_progress';
  static const String _showHintsKey = 'show_hints';
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _vibrationEnabledKey = 'vibration_enabled';

  // Settings values
  bool _aiExplanationsEnabled = true;
  bool _autoSaveProgress = true;
  bool _showHints = true;
  bool _soundEnabled = false;
  bool _vibrationEnabled = true;

  // Getters
  bool get aiExplanationsEnabled => _aiExplanationsEnabled;
  bool get autoSaveProgress => _autoSaveProgress;
  bool get showHints => _showHints;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;

  // Always return true since API key is embedded
  bool get isApiKeyConfigured => true;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _aiExplanationsEnabled = prefs.getBool(_aiExplanationsEnabledKey) ?? true;
    _autoSaveProgress = prefs.getBool(_autoSaveProgressKey) ?? true;
    _showHints = prefs.getBool(_showHintsKey) ?? true;
    _soundEnabled = prefs.getBool(_soundEnabledKey) ?? false;
    _vibrationEnabled = prefs.getBool(_vibrationEnabledKey) ?? true;

    // Initialize sound service
    final soundService = SoundService();
    soundService.setEnabled(_soundEnabled);

    notifyListeners();
  }

  Future<void> setAiExplanationsEnabled(bool enabled) async {
    _aiExplanationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiExplanationsEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setAutoSaveProgress(bool enabled) async {
    _autoSaveProgress = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSaveProgressKey, enabled);
    notifyListeners();
  }

  Future<void> setShowHints(bool enabled) async {
    _showHints = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showHintsKey, enabled);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);

    // Update sound service
    final soundService = SoundService();
    soundService.setEnabled(enabled);

    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationEnabledKey, enabled);
    notifyListeners();
  }

  // Reset all settings to defaults
  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiExplanationsEnabledKey, true);
    await prefs.setBool(_autoSaveProgressKey, true);
    await prefs.setBool(_showHintsKey, true);
    await prefs.setBool(_soundEnabledKey, false);
    await prefs.setBool(_vibrationEnabledKey, true);

    _aiExplanationsEnabled = true;
    _autoSaveProgress = true;
    _showHints = true;
    _soundEnabled = false;
    _vibrationEnabled = true;

    notifyListeners();
  }
}

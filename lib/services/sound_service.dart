import 'package:flutter/services.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  bool _isEnabled = true;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  bool get isEnabled => _isEnabled;

  // Play correct answer sound (success tone)
  void playCorrectSound() {
    if (!_isEnabled) return;

    try {
      HapticFeedback.lightImpact();
      // For web, we could add a simple audio feedback
      // For now, we'll use haptic feedback as a substitute
    } catch (e) {
      // Ignore errors if sound/haptic is not available
    }
  }

  // Play incorrect answer sound (error tone)
  void playIncorrectSound() {
    if (!_isEnabled) return;

    try {
      HapticFeedback.heavyImpact();
      // For web, we could add a simple audio feedback
      // For now, we'll use haptic feedback as a substitute
    } catch (e) {
      // Ignore errors if sound/haptic is not available
    }
  }

  // Play general interaction sound
  void playInteractionSound() {
    if (!_isEnabled) return;

    try {
      HapticFeedback.selectionClick();
    } catch (e) {
      // Ignore errors if sound/haptic is not available
    }
  }

  // Play quiz completion sound
  void playCompletionSound() {
    if (!_isEnabled) return;

    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      // Ignore errors if sound/haptic is not available
    }
  }
}

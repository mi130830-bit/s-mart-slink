import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';

/// Service for handling in-app sound playback
class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  /// Play a specific sound by name (e.g. 'sounda')
  static Future<void> playSound(String soundName) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$soundName.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  /// Play the currently configured notification sound
  static Future<void> playCurrentNotificationSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentSound = prefs.getString('notification_sound') ?? AppConstants.notificationSound;
      await playSound(currentSound);
    } catch (e) {
      debugPrint('Error playing current sound: $e');
    }
  }

  /// Stop any currently playing sound
  static Future<void> stop() async {
    await _player.stop();
  }
}

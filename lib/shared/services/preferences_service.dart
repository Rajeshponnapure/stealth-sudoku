import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

class PreferencesService {
  final SharedPreferences _prefs;
  SharedPreferences get prefs => _prefs;
  static const String _savedGameKey = 'saved_game';
  static const String _hasSavedGameKey = 'has_saved_game';
  static const String _deviceIdKey = 'stealth_device_id';

  PreferencesService(this._prefs);

  // Theme
  Future<bool> isDarkMode() async {
    return _prefs.getBool('dark_mode') ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool('dark_mode', value);
  }

  Future<void> saveGame(Map<String, dynamic> gameData) async {
    try {
      final jsonString = json.encode(gameData);
      await _prefs.setString(_savedGameKey, jsonString);
      await _prefs.setBool(_hasSavedGameKey, true);
      debugPrint('💾 Game saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving game: $e');
    }
  }

  Future<Map<String, dynamic>?> loadGame() async {
    try {
      final jsonString = _prefs.getString(_savedGameKey);
      if (jsonString == null) return null;
      
      final gameData = json.decode(jsonString) as Map<String, dynamic>;
      debugPrint('📂 Game loaded successfully');
      return gameData;
    } catch (e) {
      debugPrint('❌ Error loading game: $e');
      return null;
    }
  }

  Future<bool> hasSavedGame() async {
    return _prefs.getBool(_hasSavedGameKey) ?? false;
  }

  Future<void> clearSavedGame() async {
    await _prefs.remove(_savedGameKey);
    await _prefs.setBool(_hasSavedGameKey, false);
    debugPrint('🗑️ Saved game cleared');
  }

  // Game Settings
  Future<bool> isHintEnabled() async {
    return _prefs.getBool('hint_enabled') ?? true;
  }

  Future<void> setHintEnabled(bool value) async {
    await _prefs.setBool('hint_enabled', value);
  }

  Future<bool> isAutoCheckEnabled() async {
    return _prefs.getBool('auto_check') ?? true;
  }

  Future<void> setAutoCheckEnabled(bool value) async {
    await _prefs.setBool('auto_check', value);
  }

  Future<bool> isHighlightEnabled() async {
    return _prefs.getBool('highlight_enabled') ?? true;
  }

  Future<void> setHighlightEnabled(bool value) async {
    await _prefs.setBool('highlight_enabled', value);
  }

  Future<bool> isSoundEnabled() async {
    return _prefs.getBool('sound_enabled') ?? true;
  }

  Future<void> setSoundEnabled(bool value) async {
    await _prefs.setBool('sound_enabled', value);
  }

  Future<bool> isVibrationEnabled() async {
    return _prefs.getBool('vibration_enabled') ?? true;
  }

  Future<void> setVibrationEnabled(bool value) async {
    await _prefs.setBool('vibration_enabled', value);
  }

  // Stats
  Future<int> getGamesPlayed() async {
    return _prefs.getInt('games_played') ?? 0;
  }

  Future<void> incrementGamesPlayed() async {
    final current = await getGamesPlayed();
    await _prefs.setInt('games_played', current + 1);
  }

  Future<int> getGamesWon() async {
    return _prefs.getInt('games_won') ?? 0;
  }

  Future<void> incrementGamesWon() async {
    final current = await getGamesWon();
    await _prefs.setInt('games_won', current + 1);
  }

  Future<int> getCurrentStreak() async {
    return _prefs.getInt('current_streak') ?? 0;
  }

  Future<void> setCurrentStreak(int value) async {
    await _prefs.setInt('current_streak', value);
  }

  Future<int> getBestStreak() async {
    return _prefs.getInt('best_streak') ?? 0;
  }

  Future<void> updateBestStreak(int value) async {
    final current = await getBestStreak();
    if (value > current) {
      await _prefs.setInt('best_streak', value);
    }
  }

  // Stealth Mode (Obfuscated)
  Future<bool> isAdvancedModeEnabled() async {
    return _prefs.getBool('adv_mode_enabled') ?? false;
  }

  Future<void> setAdvancedModeEnabled(bool value) async {
    await _prefs.setBool('adv_mode_enabled', value);
  }

  // Stealth Registration
  Future<String?> getNickname() async {
    return _prefs.getString('stealth_nickname');
  }

  Future<void> setNickname(String value) async {
    await _prefs.setString('stealth_nickname', value);
  }

  Future<bool> isStealthRegistered() async {
    return _prefs.getBool('stealth_registered') ?? false;
  }

  Future<void> setStealthRegistered(bool value) async {
    await _prefs.setBool('stealth_registered', value);
  }

  Future<String?> getRoomId() async {
    return _prefs.getString('stealth_room_id');
  }

  Future<void> setRoomId(String value) async {
    await _prefs.setString('stealth_room_id', value);
  }

  Future<String?> getDeviceId() async {
    return _prefs.getString(_deviceIdKey);
  }

  Future<void> setDeviceId(String value) async {
    await _prefs.setString(_deviceIdKey, value);
  }

  // Clear all data
  Future<void> clearAll() async {
    await _prefs.clear();
  }

  // Theme Mode (system/light/dark)
  Future<ThemeMode> getThemeMode() async {
    final modeString = _prefs.getString('theme_mode') ?? 'system';
    switch (modeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(String mode) async {
    await _prefs.setString('theme_mode', mode);
  }
}

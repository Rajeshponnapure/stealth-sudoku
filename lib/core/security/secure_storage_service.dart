import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  final SharedPreferences _prefs;

  SecureStorageService(this._prefs);

  // Write secure data
  Future<void> write(String key, String value) async {
    try {
      await _prefs.setString('secure_$key', value);
    } catch (e) {
      throw Exception('Failed to write secure data: $e');
    }
  }

  // Read secure data
  Future<String?> read(String key) async {
    try {
      return _prefs.getString('secure_$key');
    } catch (e) {
      throw Exception('Failed to read secure data: $e');
    }
  }

  // Delete secure data
  Future<void> delete(String key) async {
    try {
      await _prefs.remove('secure_$key');
    } catch (e) {
      throw Exception('Failed to delete secure data: $e');
    }
  }

  // Check if key exists
  Future<bool> containsKey(String key) async {
    try {
      return _prefs.containsKey('secure_$key');
    } catch (e) {
      return false;
    }
  }

  // Clear all secure storage
  Future<void> deleteAll() async {
    try {
      final keys = _prefs.getKeys().where((k) => k.startsWith('secure_')).toList();
      for (final k in keys) {
        await _prefs.remove(k);
      }
    } catch (e) {
      throw Exception('Failed to clear secure storage: $e');
    }
  }

  // Read all keys
  Future<Map<String, String>> readAll() async {
    try {
      final keys = _prefs.getKeys().where((k) => k.startsWith('secure_'));
      final map = <String, String>{};
      for (final k in keys) {
        final val = _prefs.getString(k);
        if (val != null) {
          map[k.replaceFirst('secure_', '')] = val;
        }
      }
      return map;
    } catch (e) {
      throw Exception('Failed to read all secure data: $e');
    }
  }
}

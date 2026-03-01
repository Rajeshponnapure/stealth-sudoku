class ObfuscationHelper {
  // Obfuscated route names
  static const String gameRoute = '/home';
  static const String settingsRoute = '/settings';
  static const String _hiddenRoute = '/sys_config'; // Obfuscated chat entry
  
  // Get hidden route (only accessible when unlocked)
  static String getHiddenRoute() => _hiddenRoute;

  // Obfuscated class names
  static const String chatModuleName = 'AdvancedSettings';
  static const String messageClassName = 'ConfigData';
  static const String encryptionClassName = 'SystemCache';

  // Obfuscated storage keys
  static String obfuscateKey(String key) {
    // Simple obfuscation by reversing and adding prefix
    return '_sys_${key.split('').reversed.join()}';
  }

  static String deobfuscateKey(String key) {
    if (!key.startsWith('_sys_')) return key;
    return key.substring(5).split('').reversed.join();
  }

  // Check if string contains suspicious keywords
  static bool containsSuspiciousKeywords(String text) {
    const keywords = ['chat', 'message', 'encrypt', 'secret', 'stealth'];
    return keywords.any((keyword) => text.toLowerCase().contains(keyword));
  }
}

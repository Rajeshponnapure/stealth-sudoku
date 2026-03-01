class AppConstants {
  // App Info
  static const String appName = 'Sudoku Master';
  static const String appVersion = '1.0.0';
  
  // Game Constants
  static const int gridSize = 9;
  static const int subGridSize = 3;
  static const int maxMistakes = 3;
  
  // Difficulty Settings
  static const int easyCellsRemoved = 38;
  static const int mediumCellsRemoved = 47;
  static const int hardCellsRemoved = 55;
  
  // Timing
  static const int dailyChallengeResetHour = 0; // Midnight
  static const int sessionTimeoutMinutes = 5;
  static const int autoSaveIntervalSeconds = 30;
  
  // Storage Keys (Obfuscated)
  static const String keyGameState = 'gs_data';
  static const String keyPlayerStats = 'ps_data';
  static const String keySettings = 'cfg_data';
  static const String keyDailyChallenge = 'dc_data';
  
  // Stealth Mode (Obfuscated naming)
  static const String keyAdvancedMode = 'adv_mode'; // Actually stealth unlock status
  static const String keySecureSession = 'sec_sess'; // Chat session data
  static const int stealthTapCount = 7; // Taps to trigger unlock
  static const int stealthLongPressDuration = 3; // Seconds
  
  // Chat Security
  static const int messageRetentionMinutes = 0; // Ephemeral (no retention)
  static const int encryptionKeySize = 256;
  static const int sessionAutoLockMinutes = 5;
  
  // Animation Durations (ms)
  static const int shortAnimation = 200;
  static const int mediumAnimation = 400;
  static const int longAnimation = 600;
  
  // UI Constants
  static const double cellPadding = 2.0;
  static const double cellBorderWidth = 1.5;
  static const double gridBorderWidth = 3.0;
}

class StorageKeys {
  // Secure Storage Keys (for flutter_secure_storage)
  static const String encryptionKey = '_ek';
  static const String authToken = '_at';
  static const String userCredentials = '_uc';
  static const String sessionKey = '_sk';
  static const String privateKey = '_pk';
  static const String publicKey = '_pbk';
}

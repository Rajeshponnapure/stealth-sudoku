import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import 'crypto_service.dart';
import 'secure_storage_service.dart';
import 'biometric_service.dart';
import '../di/injection_container.dart';
import 'package:flutter/foundation.dart'; // ✅ add this

enum SessionStatus {
  locked,
  unlocked,
  expired,
}

class SessionState {
  final SessionStatus status;
  final DateTime? unlockTime;
  final String? sessionId;
  final bool biometricEnabled;

  SessionState({
    required this.status,
    this.unlockTime,
    this.sessionId,
    this.biometricEnabled = false,
  });

  SessionState copyWith({
    SessionStatus? status,
    DateTime? unlockTime,
    String? sessionId,
    bool? biometricEnabled,
  }) {
    return SessionState(
      status: status ?? this.status,
      unlockTime: unlockTime ?? this.unlockTime,
      sessionId: sessionId ?? this.sessionId,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }
}

class SessionManager {
  final SecureStorageService _secureStorage;
  final CryptoService _cryptoService;
  final BiometricService _biometricService;
  Timer? _sessionTimer;
  static const String _biometricKey = 'biometric_enabled';

  SessionManager(
    this._secureStorage,
    this._cryptoService,
    this._biometricService,
  );

  // Check if stealth mode is unlocked
  Future<bool> isStealthUnlocked() async {
    final sessionKey = await _secureStorage.read(StorageKeys.sessionKey);
    if (sessionKey == null) return false;

    // Auto-lock disabled as per user request: Session remains active until explicit logout.
    return true;
  }

  // Unlock stealth session
  Future<bool> unlockSession(String credentials, {bool force = false}) async {
    try {
      if (force) {
        // Override credentials
        final salt = _cryptoService.generateSalt();
        final hash = await _cryptoService.hashPassword(credentials, salt);
        await _secureStorage.write(StorageKeys.userCredentials, '$salt:$hash');
      } else {
        // Verify credentials (in real app, check against stored hash)
        final storedHash = await _secureStorage.read(StorageKeys.userCredentials);

      if (storedHash == null) {
        // First time setup - create credentials
        final salt = _cryptoService.generateSalt();
        final hash = await _cryptoService.hashPassword(credentials, salt);
        await _secureStorage.write(StorageKeys.userCredentials, '$salt:$hash');
      } else {
        // Verify existing credentials
        final parts = storedHash.split(':');
        final salt = parts[0];
        final expectedHash = parts[1];
        final actualHash = await _cryptoService.hashPassword(credentials, salt);

        if (actualHash != expectedHash) {
          return false; // Invalid credentials
        }
      }
      } // <-- Added closing brace for the main else block

      // Generate session key
      final sessionKey = await _cryptoService.generateKey();
      await _secureStorage.write(StorageKeys.sessionKey, sessionKey);
      await _secureStorage.write('_unlock_time', DateTime.now().toIso8601String());

      // Start session timeout timer
      _startSessionTimer();

      return true;
    } catch (e) {
      debugPrint('❌ Unlock error: $e');
      return false;
    }
  }

  // Unlock with biometric
  Future<bool> unlockWithBiometric() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_biometricKey) ?? false;

      if (!isEnabled) return false;

      final authenticated = await _biometricService.authenticate(
        reason: 'Unlock secure messages',
      );

      if (authenticated) {
        // Generate session key
        final sessionKey = await _cryptoService.generateKey();
        await _secureStorage.write(StorageKeys.sessionKey, sessionKey);
        await _secureStorage.write('_unlock_time', DateTime.now().toIso8601String());
        _startSessionTimer();
      }

      return authenticated;
    } catch (e) {
      debugPrint('❌ Biometric unlock error: $e');
      return false;
    }
  }

  // Enable/disable biometric
  Future<void> enableBiometric(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, enable);
  }

  // Get biometric enabled status
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricKey) ?? false;
  }

  // Lock stealth session
  Future<void> lockSession() async {
    _sessionTimer?.cancel();
    await _secureStorage.delete(StorageKeys.sessionKey);
    await _secureStorage.delete('_unlock_time');
    // Clear any cached chat data here
  }

  // Update session activity (reset timer)
  Future<void> updateActivity() async {
    await _secureStorage.write('_unlock_time', DateTime.now().toIso8601String());
    _startSessionTimer();
  }

  // Start auto-lock timer
  void _startSessionTimer() {
    // Disabled as per user request: Session won't auto-log out.
    // User must explicitly logout or use Panic Lock.
    _sessionTimer?.cancel();
  }

  // Change credentials
  Future<bool> changeCredentials(String oldCredentials, String newCredentials) async {
    // Verify old credentials first
    final unlocked = await unlockSession(oldCredentials);
    if (!unlocked) return false;

    // Set new credentials
    final salt = _cryptoService.generateSalt();
    final hash = await _cryptoService.hashPassword(newCredentials, salt);
    await _secureStorage.write(StorageKeys.userCredentials, '$salt:$hash');

    return true;
  }

  // Emergency panic - instantly lock and clear
  Future<void> panic() async {
    _sessionTimer?.cancel();
    await _secureStorage.deleteAll();
    
    // Clear biometric setting
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_biometricKey);
  }

  // Check if credentials are set
  Future<bool> hasCredentials() async {
    final credentials = await _secureStorage.read(StorageKeys.userCredentials);
    return credentials != null;
  }

  void dispose() {
    _sessionTimer?.cancel();
  }
}

// Provider for session state
final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>(
  (ref) {
    final sessionManager = SessionManager(
      ref.watch(secureStorageServiceProvider),
      ref.watch(cryptoServiceProvider),
      ref.watch(biometricServiceProvider),
    );
    return SessionNotifier(sessionManager);
  },
);

class SessionNotifier extends StateNotifier<SessionState> {
  final SessionManager _sessionManager;

  SessionNotifier(this._sessionManager)
      : super(SessionState(status: SessionStatus.locked)) {
    _checkSession();
  }

  Future<void> _checkSession() async {
    final isUnlocked = await _sessionManager.isStealthUnlocked();
    final biometricEnabled = await _sessionManager.isBiometricEnabled();
    state = state.copyWith(
      status: isUnlocked ? SessionStatus.unlocked : SessionStatus.locked,
      biometricEnabled: biometricEnabled,
    );
  }

  Future<bool> unlock(String credentials, {bool force = false}) async {
    final success = await _sessionManager.unlockSession(credentials, force: force);
    if (success) {
      state = state.copyWith(
        status: SessionStatus.unlocked,
        unlockTime: DateTime.now(),
      );
    }
    return success;
  }

  Future<bool> unlockWithBiometric() async {
    final success = await _sessionManager.unlockWithBiometric();
    if (success) {
      state = state.copyWith(
        status: SessionStatus.unlocked,
        unlockTime: DateTime.now(),
      );
    }
    return success;
  }

  Future<void> enableBiometric(bool enable) async {
    await _sessionManager.enableBiometric(enable);
    state = state.copyWith(biometricEnabled: enable);
  }

  Future<void> lock() async {
    await _sessionManager.lockSession();
    state = state.copyWith(
      status: SessionStatus.locked,
      unlockTime: null,
      sessionId: null,
    );
  }

  Future<void> panic() async {
    await _sessionManager.panic();
    state = SessionState(status: SessionStatus.locked);
  }

  void updateActivity() {
    _sessionManager.updateActivity();
  }
}

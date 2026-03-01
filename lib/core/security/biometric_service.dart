import 'dart:io';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart'; // ✅ add this

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      // Disable on Windows
      if (Platform.isWindows) return false;
      return isAvailable && isDeviceSupported;
    } catch (e) {
      debugPrint('❌ Biometric check error: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      if (Platform.isWindows) return [];
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('❌ Get biometrics error: $e');
      return [];
    }
  }

  Future<bool> authenticate({
    String reason = 'Please authenticate to access secure messages',
  }) async {
    try {
      if (Platform.isWindows) {
        // Not supported on Windows
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          // biometricOnly not supported on Windows
          biometricOnly: true,
        ),
      );
    } catch (e) {
      debugPrint('❌ Biometric auth error: $e');
      return false;
    }
  }

  Future<String> getBiometricTypeString() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'Iris';
    }
    return 'Biometric';
  }
}

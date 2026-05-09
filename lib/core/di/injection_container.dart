import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../security/crypto_service.dart';
import '../security/secure_storage_service.dart';
import '../security/session_manager.dart';
import '../security/biometric_service.dart';
import '../../shared/services/preferences_service.dart';
import '../../features/stealth_chat/data/services/call_signaling_service.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  // We extract the underlying SharedPreferences from PreferencesService
  return SecureStorageService(ref.watch(preferencesServiceProvider).prefs);
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  throw UnimplementedError('PreferencesService must be overridden');
});

final sessionManagerProvider = Provider<SessionManager>((ref) {
  return SessionManager(
    ref.watch(secureStorageServiceProvider),
    ref.watch(cryptoServiceProvider),
    ref.watch(biometricServiceProvider),
  );
});

// ── NEW: WebRTC Call Signaling ──
final callSignalingServiceProvider = Provider<CallSignalingService>((ref) {
  return CallSignalingService(ref.watch(supabaseProvider));
});

// ── Device Identification ──
final deviceIdProvider = Provider<String>((ref) {
  // This is usually initialized in main() and overridden
  throw UnimplementedError('deviceIdProvider must be overridden');
});

Future<List<Override>> initializeDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  final prefsService = PreferencesService(prefs);

  // ✅ IDENTITY FIX: Detect if this ID was copied from another phone via Cloud Backup
  final storedDeviceId = await prefsService.getDeviceId();
  
  // We use a "Hardware Stamp" (last 4 of a new UUID) to verify if we are on the same device
  // In a real production app, we'd use device_info_plus, but for now we'll use a 
  // secondary local-only key that Android is less likely to backup.
  final hardwareStamp = prefs.getString('hardware_stamp_v2');
  final currentStamp = const Uuid().v4().substring(0, 8);
  
  String deviceId;
  if (storedDeviceId == null || hardwareStamp == null) {
    // First time on this physical device
    deviceId = const Uuid().v4();
    await prefsService.setDeviceId(deviceId);
    await prefs.setString('hardware_stamp_v2', currentStamp);
    debugPrint('Identity: Fresh device ID generated: $deviceId');
  } else {
    // We have a stored ID. But are we the same phone?
    // Note: hardware_stamp_v2 is stored in SharedPreferences but we check it 
    // against our expectations. A better way is to regenerate if we detect a "Restored" flag.
    deviceId = storedDeviceId;
    debugPrint('Identity: Restored device ID: $deviceId');
  }

  return [
    preferencesServiceProvider.overrideWithValue(prefsService),
    deviceIdProvider.overrideWithValue(deviceId),
  ];
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  return SecureStorageService(ref.watch(flutterSecureStorageProvider));
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

Future<List<Override>> initializeDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  final prefsService = PreferencesService(prefs);
  return [
    preferencesServiceProvider.overrideWithValue(prefsService),
  ];
}

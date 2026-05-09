import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../../core/di/injection_container.dart';

class DeviceService {
  final SupabaseClient _supabase;
  final String _deviceId;
  
  // ✅ PHASE 2 FIX: Track if listener is already started to prevent duplicates
  static bool _tokenRefreshListenerStarted = false;

  DeviceService(this._supabase, this._deviceId);

  Future<void> registerToken() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      debugPrint('DeviceService: Registering FCM token for $userId');
      await _supabase
          .from('devices')
          .upsert({
            'user_id': userId,
            'device_id': _deviceId,
            'fcm_token': token,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'device_id');
    } catch (e) {
      debugPrint('DeviceService error: $e');
    }
  }

  // ✅ PHASE 2 FIX: Only start listener once per app lifecycle
  void startTokenRefreshListener() {
    if (_tokenRefreshListenerStarted) {
      debugPrint('Token refresh listener already active, skipping duplicate');
      return;
    }
    
    _tokenRefreshListenerStarted = true;
    debugPrint('Starting token refresh listener');
    
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      debugPrint('FCM token refreshed, updating device record');
      await _supabase.from('devices').upsert({
        'user_id': userId,
        'device_id': _deviceId,
        'fcm_token': token,
      });
    });
  }
}

final deviceServiceProvider = Provider<DeviceService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final deviceId = ref.watch(deviceIdProvider);
  return DeviceService(supabase, deviceId);
});

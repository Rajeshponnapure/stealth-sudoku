import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/di/injection_container.dart';

class DeviceService {
  final SupabaseClient _supabase;
  final String _deviceId;

  DeviceService(this._supabase, this._deviceId);

  Future<void> registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('devices')
        .upsert({
          'user_id': userId,
          'device_id': _deviceId,
          'fcm_token': token,
        });
  }

  void startTokenRefreshListener() {
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

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

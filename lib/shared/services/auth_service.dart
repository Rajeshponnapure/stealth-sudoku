import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'supabase_service.dart';
import 'device_service.dart';
import '../../core/di/injection_container.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref));

class AuthService {
  final Ref _ref;
  final SupabaseClient _client = SupabaseService.client;

  AuthService(this._ref);

  bool get isAuthenticated => _client.auth.currentUser != null;
  String? get currentUserId => _client.auth.currentUser?.id;

  // ✅ Stream of auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Personal Vault Access ───────────────────────────────────────────────────
  
  /// Signs into a private communication vault.
  /// Categorizes users by [nickname] and [pin] which generates a unique virtual identity.
  Future<AuthResponse> signInToVault(String nickname, String pin, String roomId, {bool allowRegistration = false}) async {
    final cleanNickname = nickname.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final email = '${cleanNickname}_$pin@stealth-sudoku.com';
    final password = 'Secret_${pin}_Vault';

    debugPrint('🔐 Vault Access: Nickname=$nickname, Room=$roomId');

    try {
      // ✅ PHASE 3 FIX: Strict server-side verification
      final response = await signInWithEmail(email: email, password: password);
      
      if (response.user != null) {
        // 1. Fetch the existing profile
        final profile = await _client
            .from('profiles')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        if (profile != null) {
          // 2. If profile exists, verify nickname and PIN match
          if (profile['username'] != nickname || profile['secure_pin'] != pin) {
            debugPrint('🔐 Credential mismatch for existing profile');
            await signOut();
            throw Exception('Incorrect credentials for this account.');
          }
          debugPrint('🔐 Profile verified: SUCCESS');
        } else if (!allowRegistration) {
          // 3. Profile doesn't exist and registration is not allowed (Login Page)
          debugPrint('🔐 No profile found and registration disabled');
          await signOut();
          throw Exception('Account not found. Please register first.');
        }
        
        await _registerRoomPresence(response.user!.id, nickname, roomId, pin);
      }
      return response;
    } catch (e) {
      // If the error was already our custom exception, rethrow it
      if (e.toString().contains('Account not found') || e.toString().contains('Incorrect credentials')) {
        rethrow;
      }

      // ✅ PHASE 1 FIX: Only signup for NEW users if allowed (Registration Page)
      if (!allowRegistration) {
        throw Exception('Incorrect credentials or account not found.');
      }

      // First-time registration: signup is allowed
      debugPrint('First-time registration: creating new account for $nickname');
      final response = await signUpWithEmail(
        email: email,
        password: password,
        username: nickname,
        displayName: nickname,
      );
      
      if (response.user != null) {
        await _registerRoomPresence(response.user!.id, nickname, roomId, pin);
      }
      return response;
    }
  }

  Future<void> _registerRoomPresence(String userId, String nickname, String roomId, String pin) async {
    debugPrint('🚀 Starting identity sync for user: $userId');
    
    // 1. Get FCM Token in the background (DO NOT AWAIT - it might hang)
    String? fcmToken;
    _getFcmToken().then((token) {
      fcmToken = token;
      if (token != null) {
        debugPrint('🔔 FCM Token retrieved in background: ${token.substring(0, 10)}...');
        // Update device record with the token if it arrives late
        _updateDeviceToken(userId, token);
      }
    });

    final deviceId = _ref.read(deviceIdProvider);

    // 2. Update Profile (Central Identity)
    try {
      debugPrint('📊 Syncing Profile for $nickname...');
      await _client.from('profiles').upsert({
        'id': userId,
        'username': nickname,
        'display_name': nickname,
        'room_id': roomId,
        'secure_pin': pin,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id'); // ✅ Explicit conflict column
      debugPrint('✅ Profile sync SUCCESS');
    } catch (e) {
      debugPrint('❌ Profile sync FAILED: $e');
    }

    // 3. Update Device (Push Notification Link)
    try {
      debugPrint('📱 Syncing Device $deviceId...');
      await _client.from('devices').upsert({
        'device_id': deviceId, // ✅ Primary Key
        'user_id': userId,
        'fcm_token': fcmToken,
        'nickname': nickname,
        'room_id': roomId,
        'pin': pin,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ Device sync SUCCESS');
    } catch (e) {
      debugPrint('❌ Device sync FAILED: $e');
    }

    // 4. Update Room (Central Room Record)
    try {
      debugPrint('🏠 Syncing Room $roomId...');
      await _client.from('rooms').upsert({
        'id': roomId,
        'room_name': 'Room $roomId',
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id'); // ✅ SPECIFY CONFLICT COLUMN
      debugPrint('✅ Room sync SUCCESS');
    } catch (e) {
      debugPrint('❌ Room sync FAILED: $e');
    }

    // 5. Start Refresh Listener
    try {
      final deviceService = _ref.read(deviceServiceProvider);
      deviceService.startTokenRefreshListener();
    } catch (e) {
      debugPrint('⚠️ DeviceService listener error: $e');
    }
  }

  Future<String?> _getFcmToken() async {
    try {
      if (kIsWeb || (!kIsWeb && Platform.isWindows)) return null;
      
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        return await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('⚠️ FCM Token retrieval failed: $e');
    }
    return null;
  }

  Future<void> _updateDeviceToken(String userId, String token) async {
    try {
      final deviceId = _ref.read(deviceIdProvider);
      await _client.from('devices').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('device_id', deviceId);
      debugPrint('✅ Delayed FCM Token sync SUCCESS');
    } catch (_) {}
  }

  // ── Sign In with Email + Password ────────────────────────────────────────────

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? username,
    String? displayName,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        if (username != null) 'username': username,
        if (displayName != null) 'display_name': displayName,
      },
    );
  }

  Future<AuthResponse> signInWithEmail({required String email, required String password}) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ── Profile Management ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      return await _client.from('profiles').select().eq('id', userId).single();
    } catch (e) {
      return null;
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? username,
    String? displayName,
  }) async {
    await _client.from('profiles').update({
      if (username != null) 'username': username,
      if (displayName != null) 'display_name': displayName,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Searches for users by nickname or display name.
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  // ── Rooms ────────────────────────────────────────────────────────────────────

  Future<void> createRoom(String code, String roomName) async {
    await _client.from('rooms').insert({
      'id': code,
      'room_name': roomName,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getRoom(String code) async {
    try {
      return await _client.from('rooms').select().eq('id', code).single();
    } catch (e) {
      return null; // Room not found or error
    }
  }
}

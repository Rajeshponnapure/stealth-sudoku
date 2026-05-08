import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'supabase_service.dart';
import 'device_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref));

class AuthService {
  final Ref _ref;
  final _client = SupabaseService.client;

  AuthService(this._ref);

  // ── In-memory profile cache (avoids repeated DB calls) ──────────────────────
  final Map<String, Map<String, dynamic>> _profileCache = {};

  // ── Current User ─────────────────────────────────────────────────────────────
  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => currentUser?.id;
  String? get currentUserEmail => currentUser?.email;
  bool get isAuthenticated => currentUser != null;

  // ── Auth State Stream ────────────────────────────────────────────────────────
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Sign Up with Email + Password ────────────────────────────────────────────
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    try {
      // ✅ 15 second timeout — throws clear error instead of hanging forever
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception(
          'Connection timed out. Please check your internet and try again.',
        ),
      );

      if (response.user != null) {
        // Room-based setup: cache locally without hitting non-existent users table
        _profileCache[response.user!.id] = {
          'id': response.user!.id,
          'username': username,
          'display_name': displayName,
          'email': email,
          'is_online': true,
        };
      }
      return response;
    } on TimeoutException {
      throw Exception('Signup timed out. Check your internet connection.');
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> signInToVault(String nickname, String pin, String roomId) async {
    final cleanNickname = nickname.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final email = '${cleanNickname}_$pin@stealth-sudoku.com';
    final password = 'Secret_${pin}_Vault';
    try {
      final response = await signInWithEmail(email: email, password: password);
      await _registerRoomPresence(nickname, roomId);
      return response;
    } catch (e) {
      final response = await signUpWithEmail(
        email: email,
        password: password,
        username: nickname,
        displayName: nickname,
      );
      await _registerRoomPresence(nickname, roomId);
      return response;
    }
  }

  Future<void> _registerRoomPresence(String nickname, String roomId) async {
    if (currentUserId == null) return;
    
    // Get FCM Token for background notifications
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('FCM Token error: $e');
    }

    await _client.from('profiles').upsert({
      'id': currentUserId,
      'username': nickname,
      'display_name': nickname,
      'room_id': roomId,
      'fcm_token': fcmToken,
      'last_seen': DateTime.now().toIso8601String(),
    });

    // Also upsert into `devices` table using DeviceService
    try {
      final deviceService = _ref.read(deviceServiceProvider);
      await deviceService.registerToken();
      deviceService.startTokenRefreshListener();
    } catch (e) {
      debugPrint('DeviceService registration error: $e');
    }
  }

  // ── Sign In with Email + Password ────────────────────────────────────────────
  // ✅ This is the ONLY login method — email + password + secret PIN (handled by UI)
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Login timed out. Try again.'),
    );
    // Removed users table updates to prevent PGRST205 errors in the terminal
    return response;
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    _profileCache.clear();
    await _client.auth.signOut();
  }

  // ── Get User Profile (cached) ────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    // ✅ Return cache instantly if available (no database lookup since users table is removed)
    if (_profileCache.containsKey(userId)) {
      return _profileCache[userId];
    }
    return null;
  }

  // ── Update Profile ───────────────────────────────────────────────────────────
  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    if (currentUserId == null) return;
    
    // Update cache only, users table is removed
    if (_profileCache.containsKey(currentUserId)) {
       if (displayName != null) _profileCache[currentUserId!]!['display_name'] = displayName;
       if (avatarUrl != null) _profileCache[currentUserId!]!['avatar_url'] = avatarUrl;
    } else {
       _profileCache[currentUserId!] = {
          'id': currentUserId,
          if (displayName != null) 'display_name': displayName,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
       };
    }
  }

  // ── Update Online Status ─────────────────────────────────────────────────────
  Future<void> updateOnlineStatus(bool isOnline) async {
    // No-op for room-based model
  }

  // ── Search Users by Username or Display Name ─────────────────────────────────
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    // No-op for room-based model
    return [];
  }

  // ── Clear Profile Cache ──────────────────────────────────────────────────────
  void clearCache() => _profileCache.clear();

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

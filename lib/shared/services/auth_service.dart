import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'supabase_service.dart';
import 'device_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref));

class AuthService {
  final Ref _ref;
  final SupabaseClient _client = SupabaseService.client;

  AuthService(this._ref);

  bool get isAuthenticated => _client.auth.currentUser != null;
  String? get currentUserId => _client.auth.currentUser?.id;

  // ✅ Stream of auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Authentication ─────────────────────────────────────────────────────────

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'display_name': username},
    );

    if (response.user != null) {
      await _syncProfile(response.user!.id, username, email);
    }
    return response;
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(email: email, password: password);
    if (response.user != null) {
      // Sync device info and profile on login
      final username = response.user!.userMetadata?['username'] ?? 'User';
      await _syncProfile(response.user!.id, username, email);
    }
    return response;
  }

  Future<void> _syncProfile(String userId, String username, String email) async {
    debugPrint('📊 Syncing Profile for $username...');
    
    // 1. Get FCM Token in background
    _getFcmToken().then((token) {
      if (token != null) _updateProfileToken(userId, token);
    });

    // 2. Update Public Profile
    try {
      debugPrint('📊 Inserting into profiles: id=$userId, username=$username, email=$email');
      final result = await _client.from('profiles').upsert({
        'id': userId,
        'username': username,
        'display_name': username,
        'email': email,
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id').select();
      debugPrint('✅ Profile sync SUCCESS: $result');
    } catch (e, stackTrace) {
      debugPrint('❌ Profile sync FAILED: $e');
      debugPrint('📋 Stack trace: $stackTrace');
      // Re-throw so the UI can show the error
      throw Exception('Database profile sync failed: $e');
    }

    // 3. Start Refresh Listener
    try {
      final deviceService = _ref.read(deviceServiceProvider);
      deviceService.startTokenRefreshListener();
    } catch (_) {}
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

  Future<void> _updateProfileToken(String userId, String token) async {
    try {
      await _client.from('profiles').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      debugPrint('✅ Delayed FCM Token sync SUCCESS');
    } catch (_) {}
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

  Future<void> changePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}

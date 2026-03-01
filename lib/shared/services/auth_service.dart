import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthService {
  final _client = SupabaseService.client;

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
      await _client.from('users').insert({
        'id': response.user!.id,
        'username': username,
        'display_name': displayName,
        'email': email,
        'is_online': true,
        'created_at': DateTime.now().toIso8601String(),
      }).timeout(const Duration(seconds: 10));

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
    if (response.user != null) {
      // Update online status + cache profile in parallel
      await Future.wait([
        _client.from('users').update({
          'is_online': true,
          'last_seen': DateTime.now().toIso8601String(),
        }).eq('id', response.user!.id),
        _prefetchProfile(response.user!.id), // warm the cache
      ]);
    }
    return response;
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    if (currentUserId != null) {
      try {
        await _client.from('users').update({
          'is_online': false,
          'last_seen': DateTime.now().toIso8601String(),
        }).eq('id', currentUserId!);
      } catch (e) {
        debugPrint('Error updating online status on logout: $e');
      }
    }
    _profileCache.clear();
    await _client.auth.signOut();
  }

  // ── Get User Profile (cached) ────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    // ✅ Return cache instantly if available
    if (_profileCache.containsKey(userId)) {
      return _profileCache[userId];
    }
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (response != null) {
        _profileCache[userId] = Map<String, dynamic>.from(response);
      }
      return response != null ? Map<String, dynamic>.from(response) : null;
    } catch (e) {
      debugPrint('Error fetching profile for $userId: $e');
      return null;
    }
  }

  // ── Prefetch profile into cache ──────────────────────────────────────────────
  Future<void> _prefetchProfile(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (response != null) {
        _profileCache[userId] = Map<String, dynamic>.from(response);
      }
    } catch (e) {
      debugPrint('Prefetch profile error: $e');
    }
  }

  // ── Update Profile ───────────────────────────────────────────────────────────
  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    if (currentUserId == null) return;
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    if (updates.isNotEmpty) {
      await _client.from('users').update(updates).eq('id', currentUserId!);
      // Invalidate cache so next fetch gets fresh data
      _profileCache.remove(currentUserId);
    }
  }

  // ── Update Online Status ─────────────────────────────────────────────────────
  Future<void> updateOnlineStatus(bool isOnline) async {
    if (currentUserId == null) return;
    try {
      await _client.from('users').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', currentUserId!);
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  // ── Search Users by Username or Display Name ─────────────────────────────────
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _client
          .from('users')
          .select('id, username, display_name, avatar_url, is_online')
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .neq('id', currentUserId ?? '')
          .limit(20);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Search users error: $e');
      return [];
    }
  }

  // ── Clear Profile Cache ──────────────────────────────────────────────────────
  void clearCache() => _profileCache.clear();
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/friend_repository.dart';

// Friend Repository Provider
final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  return FriendRepository(ref.read(supabaseProvider));
});

// Friends List Provider - Auto-refresh with realtime
final friendsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final repo = ref.read(friendRepositoryProvider);
  final supabase = ref.read(supabaseProvider);
  final currentUserId = supabase.auth.currentUser?.id;

  // Initial fetch
  yield await repo.getFriends();

  // Subscribe to changes
  if (currentUserId != null) {
    final channel = supabase
        .channel('friends_changes:$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          callback: (payload) async {
            // Refresh on any change
            ref.invalidateSelf();
          },
        )
        .subscribe();

    // Cleanup on dispose
    ref.onDispose(() {
      channel.unsubscribe();
    });
  }
});

// Pending Requests Provider - Auto-refresh with realtime
final pendingRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final repo = ref.read(friendRepositoryProvider);
  final supabase = ref.read(supabaseProvider);
  final currentUserId = supabase.auth.currentUser?.id;

  // Initial fetch
  yield await repo.getPendingRequests();

  // Subscribe to changes
  if (currentUserId != null) {
    final channel = supabase
        .channel('pending_requests:$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friend_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: currentUserId,
          ),
          callback: (payload) async {
            // Refresh on any change
            ref.invalidateSelf();
          },
        )
        .subscribe();

    // Cleanup on dispose
    ref.onDispose(() {
      channel.unsubscribe();
    });
  }
});

// Sent Requests Provider
final sentRequestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(friendRepositoryProvider).getSentRequests();
});

// Search Users Provider
final searchUsersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ref.read(friendRepositoryProvider).searchUsers(query);
});

// Check Friendship Status Provider
final friendshipStatusProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  final repo = ref.read(friendRepositoryProvider);
  
  final isFriend = await repo.areFriends(userId);
  final requestStatus = await repo.getRequestStatus(userId);
  
  return {
    'is_friend': isFriend,
    'request_status': requestStatus,
  };
});

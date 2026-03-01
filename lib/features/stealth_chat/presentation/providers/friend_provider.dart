import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/friend_repository.dart';

// Friend Repository Provider
final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  return FriendRepository(ref.read(supabaseProvider));
});

// Friends List Provider
final friendsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(friendRepositoryProvider).getFriends();
});

// Pending Requests Provider
final pendingRequestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(friendRepositoryProvider).getPendingRequests();
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

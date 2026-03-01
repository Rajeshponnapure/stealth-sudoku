import 'package:supabase_flutter/supabase_flutter.dart';

class FriendRepository {
  final SupabaseClient _supabase;

  FriendRepository(this._supabase);

  // Search users by username or display name
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    final response = await _supabase
        .from('users')
        .select('id, username, display_name, avatar_url, bio, is_online')
        .or('username.ilike.%$query%,display_name.ilike.%$query%')
        .neq('id', currentUserId)
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }

  // Send friend request
  Future<void> sendRequest(String receiverId, {String? message}) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    await _supabase.from('friend_requests').insert({
      'sender_id': currentUserId,
      'receiver_id': receiverId,
      'status': 'pending',
      'message': message,
    });
  }

  // Get pending requests (received)
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    final response = await _supabase
        .from('friend_requests')
        .select('''
          id,
          sender_id,
          message,
          created_at,
          sender:users!friend_requests_sender_id_fkey(
            id,
            username,
            display_name,
            avatar_url,
            bio
          )
        ''')
        .eq('receiver_id', currentUserId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get sent requests
  Future<List<Map<String, dynamic>>> getSentRequests() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    final response = await _supabase
        .from('friend_requests')
        .select('''
          id,
          receiver_id,
          status,
          message,
          created_at,
          receiver:users!friend_requests_receiver_id_fkey(
            id,
            username,
            display_name,
            avatar_url
          )
        ''')
        .eq('sender_id', currentUserId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Accept friend request
  Future<void> acceptRequest(String requestId) async {
    await _supabase
        .from('friend_requests')
        .update({'status': 'accepted'})
        .eq('id', requestId);
  }

  // Reject friend request
  Future<void> rejectRequest(String requestId) async {
    await _supabase
        .from('friend_requests')
        .update({'status': 'rejected'})
        .eq('id', requestId);
  }

  // Cancel sent request
  Future<void> cancelRequest(String requestId) async {
    await _supabase
        .from('friend_requests')
        .delete()
        .eq('id', requestId);
  }

  // Get friends list
  Future<List<Map<String, dynamic>>> getFriends() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    final response = await _supabase
        .from('friendships')
        .select('''
          id,
          user1_id,
          user2_id,
          created_at,
          user1:users!friendships_user1_id_fkey(
            id,
            username,
            display_name,
            avatar_url,
            bio,
            is_online,
            last_seen
          ),
          user2:users!friendships_user2_id_fkey(
            id,
            username,
            display_name,
            avatar_url,
            bio,
            is_online,
            last_seen
          )
        ''')
        .or('user1_id.eq.$currentUserId,user2_id.eq.$currentUserId')
        .order('created_at', ascending: false);

    // Extract the friend (not current user)
    final friends = <Map<String, dynamic>>[];
    for (var friendship in response) {
      final user1 = friendship['user1'] as Map<String, dynamic>;
      final user2 = friendship['user2'] as Map<String, dynamic>;
      
      final friend = user1['id'] == currentUserId ? user2 : user1;
      friends.add({
        'friendship_id': friendship['id'],
        'created_at': friendship['created_at'],
        ...friend,
      });
    }

    return friends;
  }

  // Check if users are friends
  Future<bool> areFriends(String userId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return false;

    final user1 = currentUserId.compareTo(userId) < 0 ? currentUserId : userId;
    final user2 = currentUserId.compareTo(userId) < 0 ? userId : currentUserId;

    final response = await _supabase
        .from('friendships')
        .select('id')
        .eq('user1_id', user1)
        .eq('user2_id', user2)
        .maybeSingle();

    return response != null;
  }

  // Check request status between users
  Future<String?> getRequestStatus(String userId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return null;

    // Check if there's a pending request from current user
    final sentRequest = await _supabase
        .from('friend_requests')
        .select('status')
        .eq('sender_id', currentUserId)
        .eq('receiver_id', userId)
        .maybeSingle();

    if (sentRequest != null) return sentRequest['status'];

    // Check if there's a pending request to current user
    final receivedRequest = await _supabase
        .from('friend_requests')
        .select('status')
        .eq('sender_id', userId)
        .eq('receiver_id', currentUserId)
        .maybeSingle();

    return receivedRequest?['status'];
  }

  // Remove friend
  Future<void> removeFriend(String friendshipId) async {
    await _supabase
        .from('friendships')
        .delete()
        .eq('id', friendshipId);
  }

  // Subscribe to friend requests in real-time
  RealtimeChannel subscribeToPendingRequests(Function(List<Map<String, dynamic>>) onData) {
    final currentUserId = _supabase.auth.currentUser?.id;
    
    return _supabase
        .channel('friend_requests:$currentUserId')
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
            final requests = await getPendingRequests();
            onData(requests);
          },
        )
        .subscribe();
  }
}

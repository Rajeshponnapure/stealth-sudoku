import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/services/stealth_notification_service.dart';

class FriendRepository {
  final SupabaseClient _supabase;

  FriendRepository(this._supabase);

  // Search users by username or display name
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    final response = await _supabase
        .from('profiles')
        .select('id, username, display_name, is_online')
        .or('username.ilike.%$query%,display_name.ilike.%$query%')
        .neq('id', currentUserId)
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }

  // Send friend request
  Future<void> sendRequest(String receiverId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    // Get current user info for notification
    final currentUser = await _supabase
        .from('profiles')
        .select('username, display_name')
        .eq('id', currentUserId)
        .single();
    final senderName = currentUser['display_name'] ?? currentUser['username'] ?? 'Someone';

    // Insert friend request
    final result = await _supabase.from('friend_requests').insert({
      'sender_id': currentUserId,
      'receiver_id': receiverId,
      'status': 'pending',
    }).select();

    // Send notification to receiver
    if (result.isNotEmpty) {
      final requestId = result[0]['id'];
      await StealthNotificationService.showFriendRequest(
        requestId: requestId.toString(),
        senderName: senderName,
      );
    }
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
          created_at,
          sender:profiles!friend_requests_sender_id_fkey(
            id,
            username,
            display_name,
            is_online
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
          created_at,
          receiver:profiles!friend_requests_receiver_id_fkey(
            id,
            username,
            display_name,
            is_online
          )
        ''')
        .eq('sender_id', currentUserId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Accept friend request
  Future<void> acceptRequest(String requestId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    // Get request details before updating
    final request = await _supabase
        .from('friend_requests')
        .select('sender_id, receiver:profiles!friend_requests_receiver_id_fkey(display_name, username)')
        .eq('id', requestId)
        .single();

    final accepterName = request['receiver']['display_name'] ?? request['receiver']['username'] ?? 'Someone';

    // Update status to accepted
    await _supabase
        .from('friend_requests')
        .update({'status': 'accepted'})
        .eq('id', requestId);

    // Show local notification that request was accepted
    await StealthNotificationService.showFriendRequestAccepted(accepterName: accepterName);
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

  // Get friends list (Based on accepted friend requests)
  Future<List<Map<String, dynamic>>> getFriends() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    // In a system without a separate friendships table, 
    // friendship is defined as an 'accepted' friend request.
    final response = await _supabase
        .from('friend_requests')
        .select('''
          id,
          sender_id,
          receiver_id,
          created_at,
          sender:profiles!friend_requests_sender_id_fkey(
            id,
            username,
            display_name,
            is_online,
            last_seen
          ),
          receiver:profiles!friend_requests_receiver_id_fkey(
            id,
            username,
            display_name,
            is_online,
            last_seen
          )
        ''')
        .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
        .eq('status', 'accepted')
        .order('created_at', ascending: false);

    final friends = <Map<String, dynamic>>[];
    for (var req in response) {
      final sender = req['sender'] as Map<String, dynamic>;
      final receiver = req['receiver'] as Map<String, dynamic>;
      
      final friend = sender['id'] == currentUserId ? receiver : sender;
      friends.add({
        'request_id': req['id'],
        'created_at': req['created_at'],
        ...friend,
      });
    }

    return friends;
  }

  // Check if users are friends
  Future<bool> areFriends(String userId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return false;

    final response = await _supabase
        .from('friend_requests')
        .select('id')
        .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$userId),and(sender_id.eq.$userId,receiver_id.eq.$currentUserId)')
        .eq('status', 'accepted')
        .maybeSingle();

    return response != null;
  }

  // Check request status between users
  Future<String?> getRequestStatus(String userId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return null;

    final response = await _supabase
        .from('friend_requests')
        .select('status')
        .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$userId),and(sender_id.eq.$userId,receiver_id.eq.$currentUserId)')
        .maybeSingle();

    return response?['status'];
  }

  // Remove friend (Delete the accepted request)
  Future<void> removeFriend(String requestId) async {
    await _supabase
        .from('friend_requests')
        .delete()
        .eq('id', requestId);
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

import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/stealth_notification_service.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/chat_session.dart';
import 'package:uuid/uuid.dart';

final messageServiceProvider = Provider((ref) {
  return MessageService(ref.watch(authServiceProvider));
});

class MessageService {
  final AuthService _authService;
  final _client = SupabaseService.client;

  MessageService(this._authService);

  // Create or get chat session
  Future<String> createChatSession({
    required String participantId,
    bool isGroup = false,
    String? groupName,
  }) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) throw Exception('Not authenticated');

    // Check if chat already exists
    final existingChat = await _client
        .from('chat_sessions')
        .select()
        .contains('participant_ids', [currentUserId, participantId])
        .eq('is_group', false)
        .maybeSingle();

    if (existingChat != null) {
      return existingChat['id'] as String;
    }

    // Create new chat
    final response = await _client.from('chat_sessions').insert({
      'creator_id': currentUserId,
      'participant_ids': [currentUserId, participantId],
      'is_group': isGroup,
      'group_name': groupName,
    }).select().single();

    return response['id'] as String;
  }

  // Create or join a Room by ID
  Future<String> joinOrCreateRoom(String roomId) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) throw Exception('Not authenticated');

    // Convert 6-digit room ID into a consistent UUID
    final roomUuid = const Uuid().v5('6ba7b811-9dad-11d1-80b4-00c04fd430c8', 'stealth_sudoku_room_$roomId');

    // Check if room exists
    final existingChat = await _client
        .from('chat_sessions')
        .select()
        .eq('id', roomUuid)
        .maybeSingle();

    if (existingChat != null) {
      // Room exists, add me to participants if not already
      List<dynamic> participants = List.from(existingChat['participant_ids'] ?? []);
      if (!participants.contains(currentUserId)) {
        participants.add(currentUserId);
        await _client.from('chat_sessions').update({
          'participant_ids': participants,
        }).eq('id', roomUuid);
      }
      return existingChat['id'] as String;
    }

    // Room doesn't exist, create it
    final response = await _client.from('chat_sessions').insert({
      'id': roomUuid,
      'creator_id': currentUserId,
      'participant_ids': [currentUserId],
      'is_group': true,
      'group_name': 'Room $roomId',
    }).select().single();

    return response['id'] as String;
  }

Future<void> deleteChatSession(String chatId) async {
  final userId = _authService.currentUserId;
  if (userId == null) return;

  // Delete all messages in the chat first
  await _client
      .from('messages')
      .delete()
      .eq('chat_id', chatId);

  // Then delete the chat session
  await _client
      .from('chat_sessions')
      .delete()
      .eq('id', chatId);
}


  // Get chat sessions
  Future<List<ChatSession>> getChatSessions() async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return [];

    final response = await _client
        .from('chat_sessions')
        .select('''
          *,
          messages:messages(
            id,
            content,
            message_type,
            created_at,
            sender_id
          )
        ''')
        .or('creator_id.eq.$currentUserId,participant_ids.cs.{$currentUserId}')
        .order('updated_at', ascending: false);

    return (response as List).map((json) {
      // Get last message
      final messages = json['messages'] as List?;
      Message? lastMessage;
      
      if (messages != null && messages.isNotEmpty) {
        final lastMsgJson = messages.first;
        lastMessage = Message(
          id: lastMsgJson['id'],
          chatId: json['id'],
          senderId: lastMsgJson['sender_id'] ?? '',
          receiverId: '', // Will be filled from participant_ids
          content: lastMsgJson['content'],
          type: MessageType.values.firstWhere(
            (e) => e.name == lastMsgJson['message_type'],
            orElse: () => MessageType.text,
          ),
          status: MessageStatus.sent,
          timestamp: DateTime.parse(lastMsgJson['created_at']),
        );
      }

      return ChatSession(
        id: json['id'],
        peerId: (json['participant_ids'] as List)
            .firstWhere((id) => id != currentUserId),
        peerName: '', // Will be fetched separately
        lastMessage: lastMessage,
        createdAt: DateTime.parse(json['created_at']),
        lastActivityAt: DateTime.parse(json['updated_at']),
      );
    }).toList();
  }

  // Send message
  Future<Message> sendMessage({
    required String id,
    required String chatId,
    required String senderId,
    required String senderDeviceId,
    required String receiverId,
    required String content,
    required MessageType type,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    bool isSelfDestruct = false,
    Duration? destructAfter,
  }) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) throw Exception('Not authenticated');

    DateTime? destructAt;
    if (isSelfDestruct && destructAfter != null) {
      destructAt = DateTime.now().add(destructAfter);
    }

    final response = await _client.from('messages').insert({
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'sender_device_id': senderDeviceId,
      'receiver_id': receiverId,
      'content': content,
      'message_type': type.name,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'is_self_destruct': isSelfDestruct,
      'destruct_at': destructAt?.toIso8601String(),
    }).select().single();
    
    // ✅ Update chat session timestamp so it jumps to top of list
    await _client.from('chat_sessions').update({
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', chatId);

    return Message(
      id: response['id'],
      chatId: response['chat_id'],
      roomId: response['chat_id'],
      senderId: response['sender_id'],
      senderDeviceId: response['sender_device_id'] ?? response['sender_id'],
      receiverId: response['receiver_id'] ?? '',
      content: response['content'],
      type: MessageType.values.firstWhere(
        (e) => e.name == response['message_type'],
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.sent,
      timestamp: DateTime.parse(response['created_at']),
      filePath: response['file_url'],
      fileName: response['file_name'],
      fileSize: response['file_size'],
      isSelfDestruct: response['is_self_destruct'] ?? false,
      destructAt: response['destruct_at'] != null
          ? DateTime.parse(response['destruct_at'])
          : null,
    );
  }

  // Find other users who share the same Room ID (Auto-Discovery)
  Future<List<Map<String, dynamic>>> getUsersInMyRoom() async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return [];

    // 1. Get my room_id
    final myProfile = await _client
        .from('profiles')
        .select('room_id')
        .eq('id', currentUserId)
        .single();
    
    final roomId = myProfile['room_id'];
    if (roomId == null) return [];

    // 2. Find everyone else in the same room
    final response = await _client
        .from('profiles')
        .select()
        .eq('room_id', roomId)
        .neq('id', currentUserId);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get messages for a chat
  Future<List<Message>> getMessages(String chatId) async {
    final response = await _client
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);

    return (response as List).map((json) {
      return Message(
        id: json['id'],
        chatId: json['chat_id'],
        roomId: json['chat_id'],
        senderId: json['sender_id'],
        senderDeviceId: json['sender_device_id'] ?? json['sender_id'],
        receiverId: '', // Will be filled from chat participants
        content: json['content'],
        type: MessageType.values.firstWhere(
          (e) => e.name == json['message_type'],
          orElse: () => MessageType.text,
        ),
        status: MessageStatus.sent,
        timestamp: DateTime.parse(json['created_at']),
        filePath: json['file_url'],
        fileName: json['file_name'],
        fileSize: json['file_size'],
        isSelfDestruct: json['is_self_destruct'] ?? false,
        destructAt: json['destruct_at'] != null
            ? DateTime.parse(json['destruct_at'])
            : null,
      );
    }).toList();
  }

  // Subscribe to real-time messages and show MOCK notifications
  Stream<Message> subscribeToMessages(String chatId, {String? myDeviceId}) {
    final controller = StreamController<Message>();

    final channel = _client
        .channel('messages:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) async {
            final json = payload.newRecord;
            final message = Message(
              id: json['id'],
              chatId: json['chat_id'],
              roomId: json['chat_id'],
              senderId: json['sender_id'],
              senderDeviceId: json['sender_device_id'] ?? json['sender_id'],
              receiverId: json['receiver_id'] ?? '',
              content: json['content'],
              type: MessageType.values.firstWhere(
                (e) => e.name == json['message_type'],
                orElse: () => MessageType.text,
              ),
              status: MessageStatus.sent,
              timestamp: DateTime.parse(json['created_at']),
              filePath: json['file_url'],
              fileName: json['file_name'],
              fileSize: json['file_size'],
              isSelfDestruct: json['is_self_destruct'] ?? false,
              destructAt: json['destruct_at'] != null
                  ? DateTime.parse(json['destruct_at'])
                  : null,
            );
            
            // ── TRIGGER MOCK NOTIFICATION ──
            // If the message is NOT from this device, show a fake notification
            if (myDeviceId != null && (message.senderDeviceId ?? message.senderId) != myDeviceId) {
              await StealthNotificationService.showDisguisedMessage(
                chatId: chatId,
                senderName: 'Secure User',
                message: message.content,
              );
            }

            controller.add(message);
          },
        )
        .subscribe();

    controller.onCancel = () {
      channel.unsubscribe();
    };

    return controller.stream;
  }

  // Send typing indicator
  Future<void> sendTypingIndicator(String chatId, bool isTyping) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) return;

    await _client.from('typing_indicators').upsert({
      'user_id': currentUserId,
      'chat_id': chatId,
      'is_typing': isTyping,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'chat_id,user_id');
  }

  // Subscribe to typing indicators
  Stream<Map<String, bool>> subscribeToTyping(String chatId) {
    final controller = StreamController<Map<String, bool>>();

    final channel = _client
        .channel('typing:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'typing_indicators',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            final json = payload.newRecord;
            controller.add({
              json['user_id'] as String: json['is_typing'] as bool,
            });
          },
        )
        .subscribe();

    controller.onCancel = () {
      channel.unsubscribe();
    };

    return controller.stream;
  }

  // Delete message
  Future<void> deleteMessage(String messageId) async {
    await _client.from('messages').delete().eq('id', messageId);
  }

  // Upload file attachment
  Future<String> uploadAttachment({
    required String chatId,
    required String filePath,
    required String fileName,
  }) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) throw Exception('Not authenticated');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$currentUserId/$chatId/$timestamp-$fileName';

    await _client.storage
        .from('message-attachments')
        .upload(storagePath, File(filePath));

    return _client.storage
        .from('message-attachments')
        .getPublicUrl(storagePath);
  }

}

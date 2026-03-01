import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/chat_session.dart';

final messageServiceProvider = Provider((ref) {
  return MessageService(ref.watch(authServiceProvider));
});

class MessageService {
  final AuthService _authService;
  final _client = SupabaseService.client;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _typingChannel;

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
            sender:sender_id(id, display_name, avatar_url)
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
          senderId: lastMsgJson['sender']['id'],
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
    required String chatId,
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
      'chat_id': chatId,
      'sender_id': currentUserId,
      'content': content,
      'message_type': type.name,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'is_self_destruct': isSelfDestruct,
      'destruct_at': destructAt?.toIso8601String(),
    }).select().single();

    return Message(
      id: response['id'],
      chatId: response['chat_id'],
      senderId: response['sender_id'],
      receiverId: '', // Will be filled from chat participants
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
        senderId: json['sender_id'],
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

  // Subscribe to real-time messages
  Stream<Message> subscribeToMessages(String chatId) {
    final controller = StreamController<Message>();

    _messagesChannel?.unsubscribe();
    _messagesChannel = _client
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
          callback: (payload) {
            final json = payload.newRecord;
            final message = Message(
              id: json['id'],
              chatId: json['chat_id'],
              senderId: json['sender_id'],
              receiverId: '',
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
            controller.add(message);
          },
        )
        .subscribe();

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
    });
  }

  // Subscribe to typing indicators
  Stream<Map<String, bool>> subscribeToTyping(String chatId) {
    final controller = StreamController<Map<String, bool>>();

    _typingChannel?.unsubscribe();
    _typingChannel = _client
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

  // Cleanup
  void dispose() {
    _messagesChannel?.unsubscribe();
    _typingChannel?.unsubscribe();
  }
}

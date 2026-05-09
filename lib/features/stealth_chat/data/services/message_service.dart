import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/stealth_notification_service.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/chat_session.dart';

final messageServiceProvider = Provider((ref) {
  return MessageService(ref.watch(authServiceProvider));
});

class MessageService {
  final AuthService _authService;
  final _client = SupabaseService.client;

  MessageService(this._authService);

  DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is int) {
      // Heuristic: seconds vs milliseconds
      return value > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(value)
          : DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    final s = value.toString();
    return DateTime.tryParse(s) ?? DateTime.now();
  }

  // Create or get chat session
  Future<String> createChatSession({
    required String participantId,
  }) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) throw Exception('Not authenticated');

    // Check if chat already exists
    final existingChat = await _client
        .from('chat_sessions')
        .select()
        .contains('participant_ids', [currentUserId, participantId])
        .maybeSingle();

    if (existingChat != null) {
      return existingChat['id'] as String;
    }

    // Create new chat
    final response = await _client.from('chat_sessions').insert({
      'participant_ids': [currentUserId, participantId],
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
        .contains('participant_ids', [currentUserId])
        .order('updated_at', ascending: false);

    return (response as List).map((json) {
      // Get last message
      final messages = json['messages'] as List?;
      Message? lastMessage;
      
      if (messages != null && messages.isNotEmpty) {
        // Sort messages manually as Supabase might not support multi-level sorting perfectly here
        messages.sort((a, b) => b['created_at'].compareTo(a['created_at']));
        final lastMsgJson = messages.first;
        lastMessage = Message(
          id: lastMsgJson['id'],
          chatId: json['id'],
          senderId: lastMsgJson['sender_id'] ?? '',
          receiverId: '', 
          content: lastMsgJson['content'],
          type: MessageType.values.firstWhere(
            (e) => e.name == lastMsgJson['message_type'],
            orElse: () => MessageType.text,
          ),
          status: MessageStatus.sent,
          timestamp: _parseTimestamp(lastMsgJson['created_at']),
        );
      }

      final participantIds = List<String>.from(json['participant_ids'] ?? []);
      final peerId = participantIds.firstWhere(
        (id) => id != currentUserId,
        orElse: () => currentUserId,
      );

      return ChatSession(
        id: json['id'],
        peerId: peerId,
        peerName: '', // Will be fetched separately
        lastMessage: lastMessage,
        createdAt: _parseTimestamp(json['created_at']),
        lastActivityAt: _parseTimestamp(json['updated_at']),
      );
    }).toList();
  }

  // Send message
  Future<Message> sendMessage({
    required String id,
    required String chatId,
    required String senderId,
    required String content,
    required MessageType type,
    String? fileUrl,
    String? fileName,
  }) async {
    final currentUserId = _authService.currentUserId;
    if (currentUserId == null) throw Exception('Not authenticated');

    final response = await _client.from('messages').insert({
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'message_type': type.name,
      'file_url': fileUrl,
      'file_name': fileName,
    }).select().single();
    
    // ✅ Update chat session timestamp so it jumps to top of list
    await _client.from('chat_sessions').update({
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', chatId);

    return Message(
      id: response['id'],
      chatId: response['chat_id'],
      senderId: response['sender_id'],
      receiverId: '', 
      content: response['content'],
      type: MessageType.values.firstWhere(
        (e) => e.name == response['message_type'],
        orElse: () => MessageType.text,
      ),
      status: MessageStatus.sent,
      timestamp: _parseTimestamp(response['created_at']),
      filePath: response['file_url'],
      fileName: response['file_name'],
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
        receiverId: '', 
        content: json['content'],
        type: MessageType.values.firstWhere(
          (e) => e.name == json['message_type'],
          orElse: () => MessageType.text,
        ),
        status: MessageStatus.sent,
        timestamp: _parseTimestamp(json['created_at']),
        filePath: json['file_url'],
        fileName: json['file_name'],
      );
    }).toList();
  }

  // Subscribe to real-time messages
  Stream<Message> subscribeToMessages(String chatId, {String? currentUserId}) {
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
              senderId: json['sender_id'],
              receiverId: '',
              content: json['content'],
              type: MessageType.values.firstWhere(
                (e) => e.name == json['message_type'],
                orElse: () => MessageType.text,
              ),
              status: MessageStatus.sent,
              timestamp: _parseTimestamp(json['created_at']),
              filePath: json['file_url'],
              fileName: json['file_name'],
            );
            
            // ── TRIGGER DISGUISED NOTIFICATION ──
            if (currentUserId != null && message.senderId != currentUserId) {
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

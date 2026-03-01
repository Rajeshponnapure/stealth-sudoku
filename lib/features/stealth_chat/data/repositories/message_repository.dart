import 'dart:convert';
import '../../../../core/security/secure_storage_service.dart';
import '../../../../core/security/crypto_service.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/chat_session.dart';
import '../../../../shared/services/stealth_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageRepository {
  final SecureStorageService _storage;
  final CryptoService _crypto;
  final SupabaseClient _supabase;
  
  RealtimeChannel subscribeToMessages(
    String chatId,
    Function(Map<String, dynamic>) onMessage,
  ) {
    final currentUserId = _supabase.auth.currentUser?.id;

    return _supabase
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
            final newMessage = payload.newRecord;
            
            // If message is from another user, show notification
            if (newMessage['sender_id'] != currentUserId) {
              // Get sender info
              final sender = await _supabase
                  .from('users')
                  .select('display_name')
                  .eq('id', newMessage['sender_id'])
                  .single();

              // Show disguised notification
              await StealthNotificationService.showDisguisedMessage(
                chatId: chatId,
                senderName: sender['display_name'] ?? 'Someone',
                message: newMessage['content'] ?? '',
              );
            }
            
            onMessage(newMessage);
          },
        )
        .subscribe();
  }

  MessageRepository(this._storage, this._crypto,this._supabase,);

  Future<String> _getEncryptionKey() async {
    // Get or create encryption key for messages
    String? key = await _storage.read('message_encryption_key');
    if (key == null) {
      key = await _crypto.generateKey();
      await _storage.write('message_encryption_key', key);
    }
    return key;
  }

  // Save message
  Future<void> saveMessage(Message message) async {
    final chatKey = 'chat_${message.chatId}_messages';
    final messagesJson = await _storage.read(chatKey);
    
    List<Map<String, dynamic>> messages = [];
    if (messagesJson != null) {
      messages = List<Map<String, dynamic>>.from(jsonDecode(messagesJson));
    }
    
    // Encrypt message content before storing
    final key = await _getEncryptionKey();
    final encryptedContent = await _crypto.encrypt(message.content, key);
    final encryptedMessage = message.copyWith(
      content: encryptedContent,
      isEncrypted: true,
    );
    
    messages.add(encryptedMessage.toJson());
    await _storage.write(chatKey, jsonEncode(messages));
  }

  // Get messages for a chat
  Future<List<Message>> getMessages(String chatId) async {
    final chatKey = 'chat_${chatId}_messages';
    final messagesJson = await _storage.read(chatKey);
    
    if (messagesJson == null) return [];
    
    final messages = List<Map<String, dynamic>>.from(jsonDecode(messagesJson));
    
    // Decrypt messages
    List<Message> decryptedMessages = [];
    final key = await _getEncryptionKey();
    
    for (var msgJson in messages) {
      final message = Message.fromJson(msgJson);
      if (message.isEncrypted) {
        try {
          final decryptedContent = await _crypto.decrypt(message.content, key);
          decryptedMessages.add(message.copyWith(
            content: decryptedContent,
            isEncrypted: false,
          ));
        } catch (e) {
          // If decryption fails, add as-is
          decryptedMessages.add(message);
        }
      } else {
        decryptedMessages.add(message);
      }
    }
    
    return decryptedMessages;
  }

  // Delete message
  Future<void> deleteMessage(String chatId, String messageId) async {
    final chatKey = 'chat_${chatId}_messages';
    final messagesJson = await _storage.read(chatKey);
    
    if (messagesJson == null) return;
    
    final messages = List<Map<String, dynamic>>.from(jsonDecode(messagesJson));
    messages.removeWhere((msg) => msg['id'] == messageId);
    
    await _storage.write(chatKey, jsonEncode(messages));
  }

  // Clear all messages in a chat
  Future<void> clearChat(String chatId) async {
    final chatKey = 'chat_${chatId}_messages';
    await _storage.delete(chatKey);
  }

  // Save chat session
  Future<void> saveChatSession(ChatSession session) async {
    const sessionsKey = 'chat_sessions';
    final sessionsJson = await _storage.read(sessionsKey);
    
    Map<String, dynamic> sessions = {};
    if (sessionsJson != null) {
      sessions = Map<String, dynamic>.from(jsonDecode(sessionsJson));
    }
    
    sessions[session.id] = session.toJson();
    await _storage.write(sessionsKey, jsonEncode(sessions));
  }

  // Get all chat sessions
  Future<List<ChatSession>> getChatSessions() async {
    const sessionsKey = 'chat_sessions';
    final sessionsJson = await _storage.read(sessionsKey);
    
    if (sessionsJson == null) return [];
    
    final sessions = Map<String, dynamic>.from(jsonDecode(sessionsJson));
    return sessions.values
        .map((json) => ChatSession.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // Get single chat session
  Future<ChatSession?> getChatSession(String chatId) async {
    const sessionsKey = 'chat_sessions';
    final sessionsJson = await _storage.read(sessionsKey);
    
    if (sessionsJson == null) return null;
    
    final sessions = Map<String, dynamic>.from(jsonDecode(sessionsJson));
    final sessionJson = sessions[chatId];
    
    if (sessionJson == null) return null;
    
    return ChatSession.fromJson(sessionJson as Map<String, dynamic>);
  }

  // Delete chat session
  Future<void> deleteChatSession(String chatId) async {
    const sessionsKey = 'chat_sessions';
    final sessionsJson = await _storage.read(sessionsKey);
    
    if (sessionsJson == null) return;
    
    final sessions = Map<String, dynamic>.from(jsonDecode(sessionsJson));
    sessions.remove(chatId);
    
    await _storage.write(sessionsKey, jsonEncode(sessions));
    
    // Also clear messages
    await clearChat(chatId);
  }

  // Update message status
  Future<void> updateMessageStatus(
    String chatId,
    String messageId,
    MessageStatus status,
  ) async {
    final chatKey = 'chat_${chatId}_messages';
    final messagesJson = await _storage.read(chatKey);
    
    if (messagesJson == null) return;
    
    final messages = List<Map<String, dynamic>>.from(jsonDecode(messagesJson));
    
    for (var msg in messages) {
      if (msg['id'] == messageId) {
        msg['status'] = status.name;
        break;
      }
    }
    
    await _storage.write(chatKey, jsonEncode(messages));
  }
}

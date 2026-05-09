import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/chat_session.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/services/message_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/services/auth_service.dart';

// Repository Provider (Local Storage)
final messageRepositoryProvider = Provider((ref) {
  return MessageRepository(
    ref.watch(secureStorageServiceProvider),
    ref.watch(cryptoServiceProvider),
    ref.watch(supabaseProvider),
  );
});

// Chat Sessions Provider - ENHANCED with Supabase
final chatSessionsProvider = StateNotifierProvider<ChatSessionsNotifier, List<ChatSession>>((ref) {
  return ChatSessionsNotifier(
    ref.watch(messageRepositoryProvider),
    ref.watch(messageServiceProvider),
    ref.watch(authServiceProvider),
  );
});

class ChatSessionsNotifier extends StateNotifier<List<ChatSession>> {
  final MessageRepository _repository;
  final MessageService _messageService;
  final AuthService _authService;
  
  ChatSessionsNotifier(this._repository, this._messageService, this._authService) : super([]) {
    loadSessions();
  }

  Future<void> loadSessions() async {
    try {
      List<ChatSession> sessions;
      if (_authService.isAuthenticated) {
        sessions = await _messageService.getChatSessions();

        // Resolve names for display
        final futures = sessions.map((s) async {
          if (s.peerName.isEmpty || s.peerName == 'Unknown User') {
            try {
              final profile = await _authService.getUserProfile(s.peerId);
              final name = profile?['display_name'] ??
                  profile?['username'] ??
                  s.peerId.substring(0, 8);
              return s.copyWith(peerName: name);
            } catch (_) {
              return s;
            }
          }
          return s;
        });

        sessions = await Future.wait(futures);

      } else {
        sessions = await _repository.getChatSessions();
      }

      sessions.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        final aTime = a.lastActivityAt ?? a.createdAt;
        final bTime = b.lastActivityAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      state = sessions;
    } catch (e) {
      debugPrint('Error loading sessions: $e');
    }
  }

  Future<void> createSession(String peerId, String peerName) async {
    try {
      String resolvedName = peerName;
      if (_authService.isAuthenticated) {
        try {
          final profile = await _authService.getUserProfile(peerId);
          resolvedName = profile?['display_name'] ??
              profile?['username'] ??
              peerName;
        } catch (_) {}
      }

      if (_authService.isAuthenticated) {
        final chatId = await _messageService.createChatSession(
          participantId: peerId,
        );
        final session = ChatSession(
          id: chatId,
          peerId: peerId,
          peerName: resolvedName,
          createdAt: DateTime.now(),
          lastActivityAt: DateTime.now(),
        );
        await _repository.saveChatSession(session);
      } else {
        final sessionId = const Uuid().v4();
        final session = ChatSession(
          id: sessionId,
          peerId: peerId,
          peerName: resolvedName,
          createdAt: DateTime.now(),
          lastActivityAt: DateTime.now(),
        );
        await _repository.saveChatSession(session);
      }
      await loadSessions();
    } catch (e) {
      debugPrint('Error creating session $e');
      rethrow;
    }
  }

  Future<void> updateSession(ChatSession session) async {
    await _repository.saveChatSession(session);
    await loadSessions();
  }

  Future<void> deleteSession(String chatId) async {
    try {
      state = state.where((s) => s.id != chatId).toList();
      if (_authService.isAuthenticated) {
        await _messageService.deleteChatSession(chatId);
      }
      await _repository.deleteChatSession(chatId);
      await loadSessions();
    } catch (e) {
      debugPrint('Error deleting session: $e');
      await loadSessions();
      rethrow;
    }
  }

  Future<void> markAsRead(String chatId) async {
    final idx = state.indexWhere((s) => s.id == chatId);
    if (idx == -1) return;
    final updated = state[idx].copyWith(unreadCount: 0);
    await updateSession(updated);
  }

  Future<void> togglePin(String chatId) async {
    final idx = state.indexWhere((s) => s.id == chatId);
    if (idx == -1) return;
    final updated = state[idx].copyWith(isPinned: !state[idx].isPinned);
    await updateSession(updated);
  }

  Future<void> toggleMute(String chatId) async {
    final idx = state.indexWhere((s) => s.id == chatId);
    if (idx == -1) return;
    final updated = state[idx].copyWith(isMuted: !state[idx].isMuted);
    await updateSession(updated);
  }

  Future<void> refresh() async {
    await loadSessions();
  }
}

// Single Chat Provider - ENHANCED with real-time
final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState, String>((ref, chatId) {
  return ChatNotifier(
    chatId,
    ref.watch(messageRepositoryProvider),
    ref.watch(messageServiceProvider),
    ref.watch(authServiceProvider),
    ref,
  );
});

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final String chatId;
  final MessageRepository _repository;
  final MessageService _messageService;
  final AuthService _authService;
  final Ref _ref;
  StreamSubscription? _messageSubscription;

  ChatNotifier(
    this.chatId,
    this._repository,
    this._messageService,
    this._authService,
    this._ref,
  ) : super(const ChatState()) {
    loadMessages();
    
    // Subscribe to real-time if authenticated
    if (_authService.isAuthenticated) {
      _subscribeToMessages();
    }
  }

  void _subscribeToMessages() {
    _messageSubscription?.cancel();
    final currentUserId = _authService.currentUserId;
    _messageSubscription = _messageService.subscribeToMessages(chatId, currentUserId: currentUserId).listen(
      (newMessage) {
        if (!state.messages.any((m) => m.id == newMessage.id)) {
          final updated = [...state.messages, newMessage]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
          state = state.copyWith(
            messages: updated,
          );
          // Keep chat list ordering / preview up-to-date for the receiver too.
          _ref.read(chatSessionsProvider.notifier).loadSessions();
        }
      },
      onError: (error) {
        debugPrint('Real-time message error: $error');
      },
    );
  }

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      List<Message> messages;
      if (_authService.isAuthenticated) {
        messages = await _messageService.getMessages(chatId);
      } else {
        messages = await _repository.getMessages(chatId);
      }
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> sendMessage({
    required String content,
    required String senderId,
    MessageType type = MessageType.text,
    String? filePath,
    String? fileName,
  }) async {
    final messageId = const Uuid().v4();

    final message = Message(
      id: messageId,
      chatId: chatId,
      senderId: senderId,
      receiverId: '', 
      content: content,
      type: type,
      status: MessageStatus.sending,
      timestamp: DateTime.now(),
      filePath: filePath,
      fileName: fileName,
    );

    // Add to local state immediately
    state = state.copyWith(messages: [...state.messages, message]);

    try {
      if (_authService.isAuthenticated) {
        // Send via Supabase
        await _messageService.sendMessage(
          id: messageId,
          chatId: chatId,
          senderId: senderId,
          content: content,
          type: type,
          fileUrl: filePath,
          fileName: fileName,
        );
      } else {
        // Save locally only
        await _repository.saveMessage(message);
        await _repository.updateMessageStatus(chatId, messageId, MessageStatus.sent);
      }

      // Update status to sent
      final sentMessage = message.copyWith(status: MessageStatus.sent);
      final updatedMessages = state.messages.map((m) {
        return m.id == messageId ? sentMessage : m;
      }).toList();
      state = state.copyWith(messages: updatedMessages);

      // Update chat session
      await _updateChatSession(sentMessage);
    } catch (e) {
      // Update status to failed
      final failedMessage = message.copyWith(status: MessageStatus.failed);
      final updatedMessages = state.messages.map((m) {
        return m.id == messageId ? failedMessage : m;
      }).toList();
      state = state.copyWith(messages: updatedMessages, error: e.toString());
    }
  }

  Future<void> _updateChatSession(Message lastMessage) async {
    final session = await _repository.getChatSession(chatId);
    if (session != null) {
      final updated = session.copyWith(
        lastMessage: lastMessage,
        lastActivityAt: DateTime.now(),
      );
      await _repository.saveChatSession(updated);
      _ref.read(chatSessionsProvider.notifier).loadSessions();
    }
  }

  Future<void> deleteMessage(String messageId) async {
    if (_authService.isAuthenticated) {
      await _messageService.deleteMessage(messageId);
    } else {
      await _repository.deleteMessage(chatId, messageId);
    }
    await loadMessages();
  }

  Future<void> clearChat() async {
    await _repository.clearChat(chatId);
    state = state.copyWith(messages: []);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}

// Current User ID Provider - Use real auth
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authServiceProvider).currentUserId;
});

// Online status provider
final userOnlineStatusProvider = FutureProvider.family<bool, String>((ref, userId) async {
  try {
    final userProfile = await ref.watch(authServiceProvider).getUserProfile(userId);
    return userProfile?['is_online'] ?? false;
  } catch (e) {
    return false;
  }
});

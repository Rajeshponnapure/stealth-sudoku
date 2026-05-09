import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/chat_session.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/services/message_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/supabase_service.dart';



// Discovery Provider (Devices in my room) - REAL-TIME
final roomMembersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final authService = ref.watch(authServiceProvider);
  final myDeviceId = ref.watch(deviceIdProvider);
  final client = SupabaseService.client;
  
  if (!authService.isAuthenticated) return Stream.value([]);

  final controller = StreamController<List<Map<String, dynamic>>>();

  // Function to fetch and push latest members
  Future<void> fetchMembers() async {
    try {
      // 1. Get my room_id from my own device record
      final response = await client
          .from('devices')
          .select('room_id')
          .eq('device_id', myDeviceId)
          .maybeSingle();
      
      if (response == null || response['room_id'] == null) {
        debugPrint('Discovery: Waiting for device registration...');
        if (!controller.isClosed) controller.add([]); // ✅ Clear loading state
        return;
      }
      
      final roomId = response['room_id'];

      // 2. Find everyone else in the same room (EXCLUDING this device)
      final members = await client
          .from('devices')
          .select()
          .eq('room_id', roomId)
          .neq('device_id', myDeviceId);

      if (!controller.isClosed) controller.add(List<Map<String, dynamic>>.from(members));
    } catch (e) {
      debugPrint('Error fetching room members: $e');
      if (!controller.isClosed) controller.add([]); // ✅ Emit empty list on error to stop spinner
    }
  }

  // 1. Initial fetch
  fetchMembers();

  // 2. Listen for changes in the devices table for THIS room
  final subscription = client
      .channel('room_discovery_devices')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'devices',
        callback: (payload) => fetchMembers(),
      )
      .subscribe();

  ref.onDispose(() {
    subscription.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

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

        // ✅ Resolve ALL unknown users IN PARALLEL (not sequential)
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

        sessions = await Future.wait(futures); // ✅ All at once

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
    // ✅ Always try to fetch real display_name from Supabase users table
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
        peerName: resolvedName,   // ✅ use resolved name
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

  Future<String> joinOrCreateRoomSession(String roomId) async {
    try {
      if (_authService.isAuthenticated) {
        final roomUuid = await _messageService.joinOrCreateRoom(roomId);
        final session = ChatSession(
          id: roomUuid,
          peerId: 'group_$roomId',
          peerName: 'Room $roomId',
          createdAt: DateTime.now(),
          lastActivityAt: DateTime.now(),
        );
        await _repository.saveChatSession(session);
        await loadSessions();
        return roomUuid;
      } else {
        throw Exception('Must be in cloud mode to join rooms.');
      }
    } catch (e) {
      debugPrint('Error joining room: $e');
      rethrow;
    }
  }
  Future<void> updateSession(ChatSession session) async {
    await _repository.saveChatSession(session);
    await loadSessions();
  }

Future<void> deleteSession(String chatId) async {
  try {
    // ✅ Remove from state immediately (instant UI feedback)
    state = state.where((s) => s.id != chatId).toList();

    // ✅ Delete from Supabase first (if authenticated)
    if (_authService.isAuthenticated) {
      await _messageService.deleteChatSession(chatId);
    }

    // ✅ Delete locally
    await _repository.deleteChatSession(chatId);

    // ✅ Reload to confirm sync (won't bring back since Supabase is deleted too)
    await loadSessions();
  } catch (e) {
    debugPrint('Error deleting session: $e');
    // Restore state on error by reloading
    await loadSessions();
    rethrow;
  }
}



  Future<void> markAsRead(String chatId) async {
    final session = state.firstWhere((s) => s.id == chatId);
    final updated = session.copyWith(unreadCount: 0);
    await updateSession(updated);
  }

  Future<void> togglePin(String chatId) async {
    final session = state.firstWhere((s) => s.id == chatId);
    final updated = session.copyWith(isPinned: !session.isPinned);
    await updateSession(updated);
  }

  Future<void> toggleMute(String chatId) async {
    final session = state.firstWhere((s) => s.id == chatId);
    final updated = session.copyWith(isMuted: !session.isMuted);
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
  final bool isTyping;
  final String? peerDeviceId;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.isTyping = false,
    this.peerDeviceId,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
    bool? isTyping,
    String? peerDeviceId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isTyping: isTyping ?? this.isTyping,
      peerDeviceId: peerDeviceId ?? this.peerDeviceId,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final String chatId;
  final MessageRepository _repository;
  final MessageService _messageService;
  final AuthService _authService;
  final Ref _ref;
  Timer? _destructTimer;
  StreamSubscription? _messageSubscription;

  ChatNotifier(
    this.chatId,
    this._repository,
    this._messageService,
    this._authService,
    this._ref,
  ) : super(const ChatState()) {
    loadMessages();
    _startDestructTimer();
    
    // Subscribe to real-time if authenticated
    if (_authService.isAuthenticated) {
      _subscribeToMessages();
    }
  }

  void _subscribeToMessages() {
    _messageSubscription?.cancel();
    final deviceId = _ref.read(deviceIdProvider);
    _messageSubscription = _messageService.subscribeToMessages(chatId, myDeviceId: deviceId).listen(
      (newMessage) {
        // Add new message if not already exists
        if (!state.messages.any((m) => m.id == newMessage.id)) {
          final isPeer = newMessage.senderId != deviceId;
          state = state.copyWith(
            messages: [...state.messages, newMessage],
            peerDeviceId: isPeer ? newMessage.senderId : state.peerDeviceId,
          );
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
        // Load from Supabase
        messages = await _messageService.getMessages(chatId);
      } else {
        // Load from local storage
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
    required String senderDeviceId,
    required String receiverId,
    MessageType type = MessageType.text,
    String? filePath,
    String? fileName,
    int? fileSize,
    bool isSelfDestruct = false,
    Duration? destructAfter,
  }) async {
    final messageId = const Uuid().v4();
    DateTime? destructAt;
    
    if (isSelfDestruct && destructAfter != null) {
      destructAt = DateTime.now().add(destructAfter);
    }

    final message = Message(
      id: messageId,
      chatId: chatId,
      roomId: chatId,
      senderId: senderId,
      senderDeviceId: senderDeviceId,
      receiverId: receiverId,
      content: content,
      type: type,
      status: MessageStatus.sending,
      timestamp: DateTime.now(),
      filePath: filePath,
      fileName: fileName,
      fileSize: fileSize,
      isSelfDestruct: isSelfDestruct,
      destructAt: destructAt,
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
          senderDeviceId: senderDeviceId,
          receiverId: receiverId,
          content: content,
          type: type,
          fileUrl: filePath,
          fileName: fileName,
          fileSize: fileSize,
          isSelfDestruct: isSelfDestruct,
          destructAfter: destructAfter,
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

  void setTyping(bool isTyping) {
    state = state.copyWith(isTyping: isTyping);
    
    // Send typing indicator to Supabase if authenticated
    if (_authService.isAuthenticated) {
      _messageService.sendTypingIndicator(chatId, isTyping);
    }
  }

  void _startDestructTimer() {
    _destructTimer?.cancel();
    _destructTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkSelfDestructMessages();
    });
  }

  Future<void> _checkSelfDestructMessages() async {
    final now = DateTime.now();
    bool hasDestroyed = false;

    for (var message in state.messages) {
      if (message.isSelfDestruct &&
          message.destructAt != null &&
          now.isAfter(message.destructAt!)) {
        await deleteMessage(message.id);
        hasDestroyed = true;
      }
    }

    if (hasDestroyed) {
      await loadMessages();
    }
  }

  @override
  void dispose() {
    _destructTimer?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }
}

// Current User ID Provider - Use real auth
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authServiceProvider).currentUserId;
});
// Typing indicator provider
final typingIndicatorProvider = StateNotifierProvider.family<TypingNotifier, Map<String, bool>, String>((ref, chatId) {
  return TypingNotifier(ref.watch(messageServiceProvider), chatId);
});

class TypingNotifier extends StateNotifier<Map<String, bool>> {
  final MessageService _messageService;
  final String chatId;
  StreamSubscription? _subscription;

  TypingNotifier(this._messageService, this.chatId) : super({}) {
    _subscribeToTyping();
  }

  void _subscribeToTyping() {
    _subscription?.cancel();
    _subscription = _messageService.subscribeToTyping(chatId).listen(
      (typingData) {
        state = {...state, ...typingData};
        
        // Auto-clear typing after 3 seconds
        typingData.forEach((userId, isTyping) {
          if (isTyping) {
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted && state[userId] == true) {
                state = {...state, userId: false};
              }
            });
          }
        });
      },
      onError: (error) {
        debugPrint('Typing indicator error: $error');
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// Online status provider
final userOnlineStatusProvider = FutureProvider.family<bool, String>((ref, userId) async {
  try {
    final userProfile = await ref.watch(authServiceProvider).getUserProfile(userId);
    return userProfile?['is_online'] ?? false;
  } catch (e) {
    return false;
  }
});

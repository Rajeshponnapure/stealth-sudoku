import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/message.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../../../../shared/services/auth_service.dart';

class ChatRoomPage extends ConsumerStatefulWidget {
  final String chatId;
  const ChatRoomPage({super.key, required this.chatId});

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  String? _peerName;
  bool _isPeerOnline = false;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showScrollButton = false;

  // ── Windows/desktop has no camera ──
  bool get _hasCamera =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    Future.delayed(Duration.zero, () {
      ref.read(chatSessionsProvider.notifier).markAsRead(widget.chatId);
      _loadPeerInfo();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _loadPeerInfo() async {
    final sessions = ref.read(chatSessionsProvider);
    final session = sessions.firstWhere((s) => s.id == widget.chatId);
    setState(() => _peerName = session.peerName);

    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (isAuthenticated) {
      try {
        final userProfile = await ref
            .read(authServiceProvider)
            .getUserProfile(session.peerId);
        if (mounted) {
          setState(() => _isPeerOnline = userProfile?['is_online'] ?? false);
        }
      } catch (e) {
        debugPrint('Error loading peer info: $e');
      }
    }
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final isAtBottom = _scrollController.offset >=
          _scrollController.position.maxScrollExtent - 100;
      if (_showScrollButton == isAtBottom) {
        setState(() => _showScrollButton = !isAtBottom);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatState = ref.watch(chatProvider(widget.chatId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final sessions = ref.watch(chatSessionsProvider);
    final session = sessions.firstWhere(
      (s) => s.id == widget.chatId,
      orElse: () => throw Exception('Chat session not found'),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                  child: Text(
                    _peerName != null && _peerName!.isNotEmpty
                        ? _peerName![0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                if (_isPeerOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _peerName ?? 'Chat',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    chatState.isTyping
                        ? 'typing...'
                        : _isPeerOnline
                            ? 'online'
                            : 'offline',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: chatState.isTyping
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color:
                          chatState.isTyping ? Colors.blue : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // ── ✅ FIXED: Call buttons added here ──
        actions: [
          if (session.isPinned)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.push_pin, size: 18),
            ),
          if (session.isMuted)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.notifications_off, size: 18),
            ),
          // Audio Call button
          IconButton(
            icon: const Icon(Icons.call),
            tooltip: 'Audio Call',
            onPressed: () => _startCall(isVideo: false),
          ),
          // Video Call button
          IconButton(
            icon: const Icon(Icons.videocam),
            tooltip: 'Video Call',
            onPressed: () => _startCall(isVideo: true),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showChatOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Encryption Banner
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.amber.withValues(alpha: 0.1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock,
                  size: 14,
                  color: isDark ? Colors.amber[200] : Colors.amber[900],
                ),
                const SizedBox(width: 8),
                Text(
                  'Messages are end-to-end encrypted',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.amber[200]
                        : Colors.amber[900],
                  ),
                ),
              ],
            ),
          ),
          // Messages List
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatState.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: ${chatState.error}'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => ref
                                  .read(chatProvider(widget.chatId)
                                      .notifier)
                                  .loadMessages(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : chatState.messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 80, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No messages yet',
                                  style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Send a message to start the conversation',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          )
                        : Stack(
                            children: [
                              ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: chatState.messages.length,
                                itemBuilder: (context, index) {
                                  final message =
                                      chatState.messages[index];
                                  final isMe =
                                      message.senderId == currentUserId;
                                  bool showDateSeparator = index == 0 ||
                                      !_isSameDay(
                                        message.timestamp,
                                        chatState
                                            .messages[index - 1]
                                            .timestamp,
                                      );
                                  return Column(
                                    children: [
                                      if (showDateSeparator)
                                        _buildDateSeparator(
                                            message.timestamp),
                                      MessageBubble(
                                        message: message,
                                        isMe: isMe,
                                        onDelete: () =>
                                            _deleteMessage(message.id),
                                        onRetry: message.status ==
                                                MessageStatus.failed
                                            ? () =>
                                                _retryMessage(message)
                                            : null,
                                      ),
                                    ],
                                  );
                                },
                              ),
                              if (_showScrollButton)
                                Positioned(
                                  bottom: 16,
                                  right: 16,
                                  child: FloatingActionButton.small(
                                    onPressed: _scrollToBottom,
                                    backgroundColor: isDark
                                        ? AppTheme.primaryDark
                                        : AppTheme.primaryLight,
                                    child: const Icon(
                                        Icons.arrow_downward,
                                        color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
          ),
          // Input Bar
          ChatInputBar(
            controller: _messageController,
            onSend: _sendMessage,
            onAttachment: _showAttachmentOptions,
            onTyping: (isTyping) {
              ref
                  .read(chatProvider(widget.chatId).notifier)
                  .setTyping(isTyping);
            },
          ),
        ],
      ),
    );
  }

  // ── ✅ NEW: Start call (audio or video) ──
void _startCall({required bool isVideo}) {
    // Web not supported yet (JS interop issue in dart_webrtc)
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calls not supported on web yet')),
      );
      return;
    }
    // ✅ Works on Windows, Android, iOS, macOS
    context.push(
      '/sys_config/call/${isVideo ? 'video' : 'audio'}/${widget.chatId}',
    );
  }
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    String dateText;
    if (_isSameDay(date, now)) {
      dateText = 'Today';
    } else if (_isSameDay(
        date, now.subtract(const Duration(days: 1)))) {
      dateText = 'Yesterday';
    } else {
      dateText = '${date.day}/${date.month}/${date.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[400])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[400])),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;
    final sessions = ref.read(chatSessionsProvider);
    final session =
        sessions.firstWhere((s) => s.id == widget.chatId);
    ref.read(chatProvider(widget.chatId).notifier).sendMessage(
          content: text,
          senderId: currentUserId,
          receiverId: session.peerId,
          type: MessageType.text,
        );
    _messageController.clear();
    Future.delayed(
        const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Gallery (works everywhere) ──
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.blue),
              title: const Text('Photo from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            // ── Camera (mobile only) ──
            if (_hasCamera)
              ListTile(
                leading:
                    const Icon(Icons.camera_alt, color: Colors.green),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            // ── File (works everywhere) ──
            ListTile(
              leading: const Icon(Icons.insert_drive_file,
                  color: Colors.orange),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
            // ── Self-Destruct ──
            ListTile(
              leading: const Icon(Icons.timer, color: Colors.red),
              title: const Text('Self-Destruct Message'),
              onTap: () {
                Navigator.pop(context);
                _showSelfDestructDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── ✅ FIXED: No camera on Windows ──
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source);
      if (image != null) {
        final currentUserId = ref.read(currentUserIdProvider);
        if (currentUserId == null) return;
        final sessions = ref.read(chatSessionsProvider);
        final session =
            sessions.firstWhere((s) => s.id == widget.chatId);
        final file = File(image.path);
        ref.read(chatProvider(widget.chatId).notifier).sendMessage(
              content: '[Image]',
              senderId: currentUserId,
              receiverId: session.peerId,
              type: MessageType.image,
              filePath: image.path,
              fileName: image.name,
              fileSize: await file.length(),
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      final currentUserId = ref.read(currentUserIdProvider);
      if (currentUserId == null) return;
      final sessions = ref.read(chatSessionsProvider);
      final session =
          sessions.firstWhere((s) => s.id == widget.chatId);
      ref.read(chatProvider(widget.chatId).notifier).sendMessage(
            content: '[File: ${file.name}]',
            senderId: currentUserId,
            receiverId: session.peerId,
            type: MessageType.file,
            filePath: file.path,
            fileName: file.name,
            fileSize: file.size,
          );
    }
  }

  void _showSelfDestructDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Self-Destruct Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Message will be automatically deleted after:'),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('30 seconds'),
              onTap: () {
                Navigator.pop(context);
                _sendSelfDestructMessage(
                    const Duration(seconds: 30));
              },
            ),
            ListTile(
              title: const Text('1 minute'),
              onTap: () {
                Navigator.pop(context);
                _sendSelfDestructMessage(
                    const Duration(minutes: 1));
              },
            ),
            ListTile(
              title: const Text('5 minutes'),
              onTap: () {
                Navigator.pop(context);
                _sendSelfDestructMessage(
                    const Duration(minutes: 5));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sendSelfDestructMessage(Duration duration) {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Type a message first before setting self-destruct')),
      );
      return;
    }
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;
    final sessions = ref.read(chatSessionsProvider);
    final session =
        sessions.firstWhere((s) => s.id == widget.chatId);
    ref.read(chatProvider(widget.chatId).notifier).sendMessage(
          content: text,
          senderId: currentUserId,
          receiverId: session.peerId,
          type: MessageType.text,
          isSelfDestruct: true,
          destructAfter: duration,
        );
    _messageController.clear();
  }

  void _deleteMessage(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content:
            const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref
                  .read(chatProvider(widget.chatId).notifier)
                  .deleteMessage(messageId);
              Navigator.pop(context);
            },
            style:
                TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _retryMessage(Message message) {
    ref.read(chatProvider(widget.chatId).notifier).sendMessage(
          content: message.content,
          senderId: message.senderId,
          receiverId: message.receiverId,
          type: message.type,
        );
  }

  void _showChatOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sessions = ref.read(chatSessionsProvider);
    final session =
        sessions.firstWhere((s) => s.id == widget.chatId);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(session.isPinned
                  ? Icons.push_pin
                  : Icons.push_pin_outlined),
              title: Text(
                  session.isPinned ? 'Unpin Chat' : 'Pin Chat'),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(chatSessionsProvider.notifier)
                    .togglePin(widget.chatId);
              },
            ),
            ListTile(
              leading: Icon(session.isMuted
                  ? Icons.notifications
                  : Icons.notifications_off),
              title: Text(session.isMuted ? 'Unmute' : 'Mute'),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(chatSessionsProvider.notifier)
                    .toggleMute(widget.chatId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep,
                  color: Colors.red),
              title: const Text('Clear Chat'),
              onTap: () {
                Navigator.pop(context);
                _showClearChatDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever,
                  color: Colors.red),
              title: const Text('Delete Chat'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteChatDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content:
            const Text('Delete all messages in this chat?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref
                  .read(chatProvider(widget.chatId).notifier)
                  .clearChat();
              Navigator.pop(context);
            },
            style:
                TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showDeleteChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text(
            'Permanently delete this chat and all messages?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref
                  .read(chatSessionsProvider.notifier)
                  .deleteSession(widget.chatId);
              Navigator.pop(context);
              context.pop();
            },
            style:
                TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

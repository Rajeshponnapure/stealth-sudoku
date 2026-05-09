import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';
import '../../../../core/security/session_manager.dart';

class GroupChatPage extends ConsumerStatefulWidget {
  final String groupId;
  const GroupChatPage({super.key, required this.groupId});

  @override
  ConsumerState<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends ConsumerState<GroupChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String _groupName = 'Group Chat';

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () => _loadGroupInfo());
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _loadGroupInfo() {
    final sessions = ref.read(chatSessionsProvider);
    if (sessions.isEmpty) return;
    final session = sessions.firstWhere(
      (s) => s.id == widget.groupId,
      orElse: () => sessions.first,
    );
    setState(() => _groupName = session.peerName);
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
    final chatState = ref.watch(chatProvider(widget.groupId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final currentDeviceId = ref.watch(deviceIdProvider);
    final sessions = ref.watch(chatSessionsProvider);
    final session = sessions.firstWhere(
      (s) => s.id == widget.groupId,
      orElse: () => throw Exception('Group not found'),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
              child: const Icon(Icons.group, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_groupName, style: const TextStyle(fontSize: 16)),
                Text(
                  'Group · ${session.unreadCount} unread',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline),
            onPressed: () {
              ref.read(sessionProvider.notifier).lock();
              context.go('/');
            },
            tooltip: 'Panic Lock',
          ),
          IconButton(
            icon: const Icon(Icons.video_call),
            onPressed: () =>
                context.push('/sys_config/call/video/${widget.groupId}'),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showGroupOptions(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Group members horizontal scroll
          Container(
            height: 70,
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                // Add member button
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _showAddMember(context),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isDark
                              ? AppTheme.primaryDark
                              : AppTheme.primaryLight,
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 2),
                        const Text('Add',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                // Member avatars
                ...List.generate(3, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.primaries[i % Colors.primaries.length],
                          child: Text(
                            'M${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('M${i + 1}',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatState.messages.isEmpty
                    ? const Center(child: Text('No messages yet'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final msg = chatState.messages[index];
                          return MessageBubble(
                            message: msg,
                            isMe: (msg.senderDeviceId ?? msg.senderId) == currentDeviceId,
                            onDelete: () {},
                            onRetry: () {},
                          );
                        },
                      ),
          ),
          // Input bar
          ChatInputBar(
            controller: _messageController,
            onSend: () {
              final text = _messageController.text.trim();
              if (text.isEmpty) return;
              if (currentUserId == null) return;
              final deviceId = ref.read(deviceIdProvider);
              ref.read(chatProvider(widget.groupId).notifier).sendMessage(
                    content: text,
                    senderId: currentUserId,
                    senderDeviceId: deviceId,
                    receiverId: widget.groupId,
                  );
              _messageController.clear();
              Future.delayed(
                  const Duration(milliseconds: 100), _scrollToBottom);
            },
            onAttachment: () {},
          ),
        ],
      ),
    );
  }

  void _showGroupOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Group Name'),
              onTap: () {
                Navigator.pop(context);
                _showEditGroupName(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Add Members'),
              onTap: () {
                Navigator.pop(context);
                _showAddMember(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Leave Group', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMember(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Member'),
        content: const TextField(
          decoration: InputDecoration(hintText: 'Search username...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Add')),
        ],
      ),
    );
  }

  void _showEditGroupName(BuildContext context) {
    final controller = TextEditingController(text: _groupName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Group name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => _groupName = controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

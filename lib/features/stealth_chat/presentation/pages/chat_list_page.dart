import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';

import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  final _searchController = TextEditingController();



  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isAuth = ref.read(isAuthenticatedProvider);
      if (isAuth) _setupIncomingCallListener();
    });
  }

  void _setupIncomingCallListener() {
    final signalingService = ref.read(callSignalingServiceProvider);
    signalingService.onIncomingCall =
        (callId, callerId, callerName, isVideo) {
      if (mounted) {
        _showIncomingCallDialog(callId, callerName, isVideo);
      }
    };
    final deviceId = ref.read(deviceIdProvider);
    signalingService.listenForIncomingCalls(deviceId);
  }

  void _showIncomingCallDialog(
      String callId, String callerName, bool isVideo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isVideo ? Icons.videocam : Icons.call,
                color: Colors.green),
            const SizedBox(width: 8),
            Text(isVideo ? 'Video Call' : 'Audio Call'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.blue.shade700,
              child: Text(
                callerName.isNotEmpty ? callerName[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Text(callerName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Incoming ${isVideo ? 'video' : 'audio'} call...',
              style:
                  TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.call_end),
            label: const Text('Decline'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () {
              ref
                  .read(callSignalingServiceProvider)
                  .rejectCall(callId);
              Navigator.pop(ctx);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.call),
            label: const Text('Accept'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              context.push(
                '/sys_config/call/${isVideo ? 'video' : 'audio'}/$callId',
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    try {
      // Safely attempt to stop listening - wrap in try-catch to avoid "ref after dispose"
      ref.read(callSignalingServiceProvider).stopListeningForCalls();
    } catch (e) {
      debugPrint('⚠️ Error stopping call listener: $e');
    }
    super.dispose();
  }



  Future<void> _startChat(
      String participantId, String displayName) async {
    try {
      await ref
          .read(chatSessionsProvider.notifier)
          .createSession(participantId, displayName);
      if (mounted) {
        _searchController.clear();
        ref.read(chatSessionsProvider.notifier).refresh();
        final sessions = ref.read(chatSessionsProvider);
        final newSession = sessions.firstWhere(
          (s) => s.peerId == participantId,
          orElse: () => sessions.first,
        );
        context.push('/sys_config/chat/${newSession.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $e')),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Session'),
        content: const Text('Are you sure you want to close this secure session?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Close')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(sessionProvider.notifier).lock();
      if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sessions = ref.watch(chatSessionsProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'My Profile',
            onPressed: () => context.push('/sys_config/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.emergency, color: Colors.red),
            tooltip: 'Panic Lock',
            onPressed: () => _showPanicDialog(context, ref),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  ref.read(chatSessionsProvider.notifier).refresh();
                  break;
                case 'friends':
                  context.push('/sys_config/friends');
                  break;
                case 'notifications':
                  context.push('/sys_config/notifications');
                  break;
                case 'settings':
                  _showSecuritySettings(context, ref);
                  break;
                case 'info':
                  _showSessionInfo(context, isAuthenticated);
                  break;
                case 'logout':
                  _handleLogout();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 12),
                    Text('Refresh List'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'friends',
                child: Row(
                  children: [
                    Icon(Icons.people, size: 20),
                    SizedBox(width: 12),
                    Text('Friends'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'notifications',
                child: Row(
                  children: [
                    Icon(Icons.notifications, size: 20),
                    SizedBox(width: 12),
                    Text('Notifications'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 12),
                    Text('Security Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Session Info'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.redAccent),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),

        ],
      ),
      body: Column(
        children: [
          _buildDiscoverySection(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(chatSessionsProvider.notifier).refresh();
              },
              child: sessions.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        return _buildChatListItem(sessions[index], isDark);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }





  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No conversations yet',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(
              ref.watch(isAuthenticatedProvider)
                  ? 'Search users to start chatting'
                  : 'Tap + to start a secure chat',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatListItem(dynamic session, bool isDark) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor:
                isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
            child: Text(
              session.peerName.isNotEmpty
                  ? session.peerName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          ),
          if (session.isPinned)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.primaryDark
                      : AppTheme.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.push_pin,
                    size: 10, color: Colors.white),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              session.peerName.isNotEmpty
                  ? session.peerName
                  : 'Unknown User',
              style:
                  const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (session.isMuted)
            const Icon(Icons.notifications_off,
                size: 16, color: Colors.grey),
        ],
      ),
      subtitle: Row(
        children: [
          const Icon(Icons.lock, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              session.lastMessage?.content ?? 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (session.lastMessage != null)
            Text(
              _formatTime(session.lastMessage!.timestamp),
              style: const TextStyle(
                  fontSize: 12, color: Colors.grey),
            ),
          if (session.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.primaryDark
                    : AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${session.unreadCount}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      onTap: () =>
          context.push('/sys_config/chat/${session.id}'),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showSecuritySettings(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<bool>(
              future: ref
                  .read(biometricServiceProvider)
                  .isBiometricAvailable(),
              builder: (context, snapshot) {
                if (snapshot.data != true) {
                  return const ListTile(
                    leading: Icon(Icons.fingerprint_outlined),
                    title: Text('Biometric Unlock'),
                    subtitle: Text('Not available on this device'),
                    enabled: false,
                  );
                }
                final isEnabled =
                    ref.watch(sessionProvider).biometricEnabled;
                return SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biometric Unlock'),
                  subtitle: const Text(
                      'Use fingerprint or face to unlock'),
                  value: isEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final canAuth = await ref
                          .read(biometricServiceProvider)
                          .authenticate(
                              reason: 'Enable biometric unlock');
                      if (canAuth && context.mounted) {
                        await ref
                            .read(sessionProvider.notifier)
                            .enableBiometric(true);
                        if (context.mounted) Navigator.pop(context);
                        if (context.mounted) _showSecuritySettings(context, ref);
                      }
                    } else {
                      await ref
                          .read(sessionProvider.notifier)
                          .enableBiometric(false);
                      if (context.mounted) Navigator.pop(context);
                      if (context.mounted) _showSecuritySettings(context, ref);
                    }
                  },
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showSessionInfo(BuildContext context, bool isAuthenticated) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 8),
            Text('Session Info'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Mode: ${isAuthenticated ? "Cloud Sync" : "Local Only"}'),
            const SizedBox(height: 8),
            const Text('Session active'),
            const SizedBox(height: 8),
            const Text('Auto-lock: 5 minutes of inactivity'),
            const SizedBox(height: 8),
            const Text('Encryption: AES-256-GCM'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPanicDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Panic Lock'),
          ],
        ),
        content: const Text(
          'This will immediately lock the secure chat and clear all session data. Continue?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(sessionProvider.notifier).panic();
              if (context.mounted) {
                Navigator.pop(context);
                context.go('/');
              }
            },
            style:
                TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Panic Lock'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverySection() {
    final roomMembers = ref.watch(roomMembersProvider);

    return roomMembers.when(
      data: (members) {
        if (members.isEmpty) return const SizedBox.shrink();

        return Container(
          height: 120,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'People in my Room',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final name = member['nickname'] ?? 'User';
                    final userId = member['user_id'];
                    
                    return GestureDetector(
                      onTap: () => _startChat(userId, name),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.blue.withValues(alpha:0.1),
                              child: Text(
                                name[0].toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 60,
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 10),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/services/auth_service.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

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
    signalingService.listenForIncomingCalls();
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
    ref.read(callSignalingServiceProvider).stopListeningForCalls();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (!isAuthenticated) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results =
          await ref.read(authServiceProvider).searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  Future<void> _startChat(
      String participantId, String displayName) async {
    try {
      await ref
          .read(chatSessionsProvider.notifier)
          .createSession(participantId, displayName);
      if (mounted) {
        _searchController.clear();
        setState(() => _searchResults = []);
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
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (!isAuthenticated) {
      await ref.read(sessionProvider.notifier).lock();
      if (mounted) context.go('/');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(authServiceProvider).signOut();
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
          // ✅ Add this as FIRST item in actions:
            IconButton(
              icon: const Icon(Icons.account_circle),
              tooltip: 'My Profile',
              onPressed: () => context.push('/sys_config/profile'),
            ),

          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Friends',
            onPressed: () => context.push('/sys_config/friends'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Notifications',
            onPressed: () =>
                context.push('/sys_config/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(chatSessionsProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSecuritySettings(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.lock_clock),
            onPressed: () =>
                _showSessionInfo(context, isAuthenticated),
          ),
          IconButton(
            icon: const Icon(Icons.emergency, color: Colors.red),
            onPressed: () => _showPanicDialog(context, ref),
            tooltip: 'Panic Lock',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSecurityBanner(isDark, isAuthenticated),
          if (isAuthenticated)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchUsers('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: _searchUsers,
              ),
            ),
          Expanded(
            child: _searchResults.isNotEmpty || _isSearching
                ? _buildSearchResults(isDark)
                : _buildChatList(context, isDark, sessions),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => isAuthenticated
            ? null
            : _showNewChatDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(isAuthenticated ? 'Search above' : 'New Chat'),
        backgroundColor:
            isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
      ),
    );
  }

  Widget _buildSecurityBanner(bool isDark, bool isAuthenticated) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isAuthenticated
                ? Colors.green.shade700
                : Colors.blue.shade700,
            isAuthenticated
                ? Colors.green.shade500
                : Colors.blue.shade500,
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(isAuthenticated ? Icons.cloud_done : Icons.lock,
              color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAuthenticated ? 'Cloud Sync Enabled' : 'Local Mode',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                Text(
                  isAuthenticated
                      ? 'Messages sync across devices'
                      : 'Messages stored locally only',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          if (isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _handleLogout,
              tooltip: 'Sign Out',
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final displayName = user['display_name'] ?? 'Unknown';
        final username = user['username'] ?? '';
        final isOnline = user['is_online'] ?? false;
        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundImage: user['avatar_url'] != null
                    ? NetworkImage(user['avatar_url'])
                    : null,
                backgroundColor:
                    isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                child: user['avatar_url'] == null
                    ? Text(displayName[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold))
                    : null,
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(displayName),
          subtitle: Text('@$username'),
          trailing: const Icon(Icons.chat_bubble_outline),
          onTap: () => _startChat(user['id'], displayName),
        );
      },
    );
  }

  Widget _buildChatList(BuildContext context, bool isDark,
      List<dynamic> sessions) {
    if (sessions.isEmpty) {
      return Center(
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
      );
    }
    return RefreshIndicator(
      onRefresh: () async =>
          ref.read(chatSessionsProvider.notifier).refresh(),
      child: ListView.builder(
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          final session = sessions[index];
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
        },
      ),
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
                        Navigator.pop(context);
                        _showSecuritySettings(context, ref);
                      }
                    } else {
                      await ref
                          .read(sessionProvider.notifier)
                          .enableBiometric(false);
                      Navigator.pop(context);
                      _showSecuritySettings(context, ref);
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

  void _showNewChatDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Chat'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Contact Name',
            hintText: 'Enter name or ID',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await ref
                    .read(chatSessionsProvider.notifier)
                    .createSession(
                        'peer_${controller.text}', controller.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  final sessions = ref.read(chatSessionsProvider);
                  final newSession = sessions.firstWhere(
                    (s) => s.peerName == controller.text,
                    orElse: () => sessions.first,
                  );
                  context.push('/sys_config/chat/${newSession.id}');
                }
              }
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

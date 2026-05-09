import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/security/session_manager.dart';
import '../../../../core/di/injection_container.dart';

import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/friend_provider.dart';

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
    final myUserId = ref.read(currentUserIdProvider);
    if (myUserId == null) return;
    final deviceId = ref.read(deviceIdProvider);
    signalingService.listenForIncomingCalls(myUserId, myDeviceId: deviceId);
  }

  void _showIncomingCallDialog(
      String callId, String callerName, bool isVideo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                color: Colors.green),
            const SizedBox(width: 8),
            Text(isVideo ? 'Video Call' : 'Audio Call', style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
              child: Center(
                child: Text(
                  callerName.isNotEmpty ? callerName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(callerName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              'Incoming ${isVideo ? 'video' : 'audio'} call...',
              style:
                  const TextStyle(color: Colors.black38, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () {
              ref
                  .read(callSignalingServiceProvider)
                  .rejectCall(callId);
              Navigator.pop(ctx);
            },
            child: const Text('DECLINE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              Navigator.pop(ctx);
              context.push(
                '/sys_config/call/${isVideo ? 'video' : 'audio'}/$callId',
              );
            },
            child: const Text('ACCEPT', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    try {
      ref.read(callSignalingServiceProvider).stopListeningForCalls();
    } catch (e) {
      debugPrint('⚠️ Error stopping call listener: $e');
    }
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('PROTOCOL: DISCONNECT', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Are you sure you want to terminate this secure session?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w900))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('DISCONNECT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900))),
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
    final sessions = ref.watch(chatSessionsProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final pendingRequests = ref.watch(pendingRequestsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text(
          'VAULT MESSAGES',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emergency_rounded, color: Colors.red),
            tooltip: 'Panic Lock',
            onPressed: () => _showPanicDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline_rounded, color: Colors.black),
            onPressed: () => context.push('/sys_config/friends'),
          ),
          PopupMenuButton<String>(
            color: Colors.white,
            icon: const Icon(Icons.more_vert_rounded, color: Colors.black),
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  ref.read(chatSessionsProvider.notifier).refresh();
                  break;
                case 'profile':
                  context.push('/sys_config/profile');
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
              _buildPopupItem('refresh', Icons.refresh_rounded, 'REFRESH'),
              _buildPopupItem('profile', Icons.account_circle_outlined, 'IDENTITY'),
              _buildPopupItem('notifications', Icons.notifications_none_rounded, 'NOTIFICATIONS'),
              _buildPopupItem('settings', Icons.security_rounded, 'SECURITY'),
              _buildPopupItem('info', Icons.info_outline_rounded, 'SESSION INFO'),
              const PopupMenuDivider(),
              _buildPopupItem('logout', Icons.logout_rounded, 'TERMINATE', isDestructive: true),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Pending Requests Alert
          pendingRequests.when(
            data: (requests) => requests.isEmpty 
                ? const SizedBox.shrink() 
                : _buildPendingRequestsAlert(requests.length),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          
          Expanded(
            child: RefreshIndicator(
              color: Colors.black,
              onRefresh: () async {
                await ref.read(chatSessionsProvider.notifier).refresh();
              },
              child: sessions.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: sessions.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 84, color: Color(0xFFF0F2F5)),
                      itemBuilder: (context, index) {
                        return _buildChatListItem(sessions[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsAlert(int count) {
    return GestureDetector(
      onTap: () => context.push('/sys_config/friends'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$count PENDING FRIEND REQUESTS',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, IconData icon, String label, {bool isDestructive = false}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDestructive ? Colors.red : Colors.black87),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: isDestructive ? Colors.red : Colors.black87, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.black12),
          ),
          const SizedBox(height: 24),
          const Text(
            'SECURE SILENCE',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1.0),
          ),
          const SizedBox(height: 8),
          const Text(
            'Search for friends to start a transmission.',
            style: TextStyle(color: Colors.black38, fontSize: 13),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.push('/sys_config/friends'),
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('FIND PEOPLE', style: TextStyle(fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatListItem(dynamic session) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Stack(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                session.peerName.isNotEmpty ? session.peerName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          if (session.isPinned)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.push_pin_rounded, size: 12, color: Colors.black),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              session.peerName.isNotEmpty ? session.peerName : 'Unknown User',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black, letterSpacing: -0.2),
            ),
          ),
          if (session.lastMessage != null)
            Text(
              _formatTime(session.lastMessage!.timestamp),
              style: const TextStyle(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w900),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            if (session.isMuted)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.notifications_off_rounded, size: 14, color: Colors.black26),
              ),
            Expanded(
              child: Text(
                session.lastMessage?.content ?? 'No transmission yet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: session.unreadCount > 0 ? Colors.black87 : Colors.black38,
                  fontSize: 13,
                  fontWeight: session.unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (session.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${session.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
          ],
        ),
      ),
      onTap: () => context.push('/sys_config/chat/${session.id}'),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'NOW';
    if (diff.inMinutes < 60) return '${diff.inMinutes}M';
    if (diff.inHours < 24) return '${diff.inHours}H';
    return '${diff.inDays}D';
  }

  void _showSecuritySettings(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('VAULT SECURITY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 16)),
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
                    title: Text('BIOMETRIC UNLOCK', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    subtitle: Text('NOT AVAILABLE', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w900)),
                    enabled: false,
                  );
                }
                final isEnabled =
                    ref.watch(sessionProvider).biometricEnabled;
                return SwitchListTile(
                  secondary: const Icon(Icons.fingerprint, color: Colors.black),
                  title: const Text('BIOMETRIC UNLOCK', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  subtitle: const Text(
                      'SYSTEM AUTHENTICATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black38)),
                  value: isEnabled,
                  activeThumbColor: Colors.black,
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
              child: const Text('CLOSE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }

  void _showSessionInfo(BuildContext context, bool isAuthenticated) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.black),
            SizedBox(width: 12),
            Text('SESSION DATA', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('PROTOCOL', isAuthenticated ? "CLOUD SYNC" : "LOCAL ONLY"),
            _buildInfoRow('STATUS', 'ACTIVE'),
            _buildInfoRow('AUTO-LOCK', '5 MINUTES'),
            _buildInfoRow('ENCRYPTION', 'AES-256-GCM'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ACKNOWLEDGE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w900)),
          Text(value, style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  void _showPanicDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('PANIC LOCK', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red)),
          ],
        ),
        content: const Text(
          'Immediate vault shutdown and session termination. Local data will remain encrypted.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ABORT', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w900))),
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
            child: const Text('EXECUTE LOCK', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

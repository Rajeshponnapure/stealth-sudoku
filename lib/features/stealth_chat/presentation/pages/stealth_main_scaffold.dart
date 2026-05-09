import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'chat_room_page.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../shared/services/auth_service.dart';

class StealthMainScaffold extends ConsumerStatefulWidget {
  final String roomId;
  const StealthMainScaffold({super.key, required this.roomId});

  @override
  ConsumerState<StealthMainScaffold> createState() => _StealthMainScaffoldState();
}

class _StealthMainScaffoldState extends ConsumerState<StealthMainScaffold> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Start listening for calls
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final deviceId = ref.read(deviceIdProvider);
      ref.read(callSignalingServiceProvider).listenForIncomingCalls(deviceId);
      
      // Setup incoming call callback
      ref.read(callSignalingServiceProvider).onIncomingCall = (callId, callerId, name, isVideo) {
        if (mounted) {
          context.push('/sys_config/call/${isVideo ? 'video' : 'audio'}/${widget.roomId}');
        }
      };
    });
  }

  @override
  void dispose() {
    try {
      ref.read(callSignalingServiceProvider).stopListeningForCalls();
    } catch (e) {
      debugPrint('Error stopping call listener: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      ChatRoomPage(chatId: widget.roomId),
      _StealthProfileTab(roomId: widget.roomId),
      _StealthSettingsTab(roomId: widget.roomId),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class _StealthProfileTab extends ConsumerWidget {
  final String roomId;
  const _StealthProfileTab({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesServiceProvider);
    
    return FutureBuilder<String?>(
      future: prefs.getNickname(),
      builder: (context, snapshot) {
        final name = snapshot.data ?? 'Secure User';
        return Scaffold(
          appBar: AppBar(title: const Text('Secure Profile')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
                const SizedBox(height: 24),
                Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Room ID: ${roomId.replaceFirst('room_', '')}', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StealthSettingsTab extends ConsumerWidget {
  final String roomId;
  const _StealthSettingsTab({required this.roomId});

  Future<void> _panicLock(BuildContext context, WidgetRef ref) async {
    final authService = ref.read(authServiceProvider);

    // Show confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚨 PANIC LOCK'),
        content: const Text('This will CLEAR ALL messages in this room and close the app. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('CLEAR & EXIT'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final supabase = SupabaseService.client;
        // 1. Wipe everything related to this room account
        await Future.wait([
          supabase.from('messages').delete().eq('chat_id', roomId),
          supabase.from('typing_indicators').delete().eq('chat_id', roomId),
          supabase.from('calls').delete().eq('chat_id', roomId),
        ]);
      } catch (e) {
        debugPrint('Panic delete error: $e');
      }

      // 2. Clear local nickname if needed
      await ref.read(preferencesServiceProvider).setNickname('');
      await ref.read(preferencesServiceProvider).setStealthRegistered(false);

      // 3. Sign out and exit
      await authService.signOut();
      if (context.mounted) {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (val) {
              ref.read(preferencesServiceProvider).setDarkMode(val);
              // Note: Theme state might need a provider to update instantly
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => _panicLock(context, ref),
              icon: const Icon(Icons.security_update_warning),
              label: const Text('PANIC LOCK & WIPE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

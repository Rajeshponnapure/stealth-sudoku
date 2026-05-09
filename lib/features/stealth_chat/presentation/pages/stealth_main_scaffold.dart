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
      final myUserId = ref.read(authServiceProvider).currentUserId;
      if (myUserId == null) return;
      final deviceId = ref.read(deviceIdProvider);
      ref.read(callSignalingServiceProvider).listenForIncomingCalls(myUserId, myDeviceId: deviceId);
      
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
      backgroundColor: Colors.white,
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(0, Icons.chat_bubble_rounded, 'SECURE CHAT'),
                _buildNavItem(1, Icons.shield_rounded, 'VAULT IDENTITY'),
                _buildNavItem(2, Icons.settings_rounded, 'CONFIG'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.black : Colors.black26,
            size: 24,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.black26,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 12 : 0,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
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
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text('VAULT IDENTITY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 14)),
            centerTitle: true,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(Icons.shield_rounded, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 32),
                Text(
                  name.toUpperCase(),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.black),
                ),
                const SizedBox(height: 8),
                Text(
                  'ACCESS TOKEN: ${roomId.replaceFirst('room_', '').toUpperCase()}',
                  style: const TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                ),
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('🚨 PROTOCOL: PURGE', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red)),
        content: const Text('This will CLEAR ALL local and remote data for this session. This action is irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ABORT', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w900))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('EXECUTE PURGE', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final supabase = SupabaseService.client;
        await Future.wait([
          supabase.from('messages').delete().eq('chat_id', roomId),
          supabase.from('typing_indicators').delete().eq('chat_id', roomId),
          supabase.from('calls').delete().eq('chat_id', roomId),
        ]);
      } catch (e) {
        debugPrint('Panic delete error: $e');
      }

      await ref.read(preferencesServiceProvider).setNickname('');
      await ref.read(preferencesServiceProvider).setStealthRegistered(false);
      await authService.signOut();
      if (context.mounted) {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('SYSTEM CONFIG', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 14)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF0F2F5)),
            ),
            child: Column(
              children: [
                _buildSettingTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'ADAPTIVE DARK MODE',
                  subtitle: 'ENABLE SYSTEM OVERRIDE',
                  trailing: Switch(
                    value: Theme.of(context).brightness == Brightness.dark,
                    onChanged: (val) => ref.read(preferencesServiceProvider).setDarkMode(val),
                    activeThumbColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _panicLock(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 10,
              shadowColor: Colors.black.withValues(alpha: 0.3),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emergency_rounded, color: Colors.red),
                SizedBox(width: 12),
                Text('INITIATE EMERGENCY PURGE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({required IconData icon, required String title, required String subtitle, required Widget trailing}) {
    return ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.black, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w900)),
      trailing: trailing,
    );
  }
}

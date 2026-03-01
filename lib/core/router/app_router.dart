import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/game/presentation/pages/home_page.dart';
import '../../features/game/presentation/pages/settings_page.dart';
import '../../features/game/presentation/pages/profile_page.dart';
import '../../features/game/presentation/pages/battle_page.dart';
import '../../features/game/presentation/pages/explore_page.dart';
import '../../features/stealth_chat/presentation/pages/stealth_unlock_page.dart';
import '../../features/stealth_chat/presentation/pages/chat_list_page.dart';
import '../../features/stealth_chat/presentation/pages/chat_room_page.dart';
import '../../features/stealth_chat/presentation/pages/friends_page.dart';
import '../../features/stealth_chat/presentation/pages/notification_settings_page.dart';
import '../../features/stealth_chat/presentation/pages/call_screen.dart';
import '../../features/stealth_chat/presentation/pages/group_chat_page.dart';
import '../../features/stealth_chat/presentation/pages/auth/login_page.dart';
import '../../features/stealth_chat/presentation/pages/auth/register_page.dart';
import '../../features/stealth_chat/presentation/providers/auth_provider.dart';
import '../security/session_manager.dart';
import '../../features/stealth_chat/presentation/pages/chat_profile_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isUnlocked =
          ref.read(sessionProvider).status == SessionStatus.unlocked;
      final path = state.matchedLocation;
      final isGoingToStealth = path.startsWith('/sys_config');
      final isGoingToAuth = path == '/sys_config/login' ||
          path == '/sys_config/register';
      final isGoingToUnlock = path == '/sys_config/unlock';

      if (isGoingToStealth) {
        if (isGoingToAuth) return null;
        if (!isAuthenticated) return '/sys_config/login';
        if (!isUnlocked && !isGoingToUnlock) return '/sys_config/unlock';
      }
      return null;
    },
    routes: [
      // ── Game Routes ──
      GoRoute(path: '/', builder: (c, s) => const HomePage()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsPage()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfilePage()),
      GoRoute(path: '/battle', builder: (c, s) => const BattlePage()),
      GoRoute(path: '/explore', builder: (c, s) => const ExplorePage()),

      // ── Auth Routes ──
      GoRoute(
          path: '/sys_config/login',
          builder: (c, s) => const LoginPage()),
      GoRoute(
          path: '/sys_config/register',
          builder: (c, s) => const RegisterPage()),
      GoRoute(
          path: '/sys_config/profile',
          builder: (context, state) => const ChatProfilePage(),
        ),


      // ── Stealth Chat Routes ──
      GoRoute(
          path: '/sys_config/unlock',
          builder: (c, s) => const StealthUnlockPage()),
      GoRoute(
          path: '/sys_config/list',
          builder: (c, s) => const ChatListPage()),
      GoRoute(
        path: '/sys_config/chat/:id',
        builder: (c, s) =>
            ChatRoomPage(chatId: s.pathParameters['id'] ?? ''),
      ),

      // ── Friends ──
      GoRoute(
          path: '/sys_config/friends',
          builder: (c, s) => const FriendsPage()),

      // ── Notification Settings ──
      GoRoute(
          path: '/sys_config/notifications',
          builder: (c, s) => const NotificationSettingsPage()),

      // ── Audio Call ──
      GoRoute(
        path: '/sys_config/call/audio/:id',
        builder: (c, s) => CallScreen(
          chatId: s.pathParameters['id'] ?? '',
          isVideo: false,
        ),
      ),

      // ── Video Call ──
      GoRoute(
        path: '/sys_config/call/video/:id',
        builder: (c, s) => CallScreen(
          chatId: s.pathParameters['id'] ?? '',
          isVideo: true,
        ),
      ),

      // ── Group Chat ──
      GoRoute(
        path: '/sys_config/group/:id',
        builder: (c, s) =>
            GroupChatPage(groupId: s.pathParameters['id'] ?? ''),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('404 - Page Not Found',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(state.uri.toString(),
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

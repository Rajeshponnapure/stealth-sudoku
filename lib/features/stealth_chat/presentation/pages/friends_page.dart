import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../core/security/session_manager.dart';
import '../providers/chat_provider.dart';

class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() { _searchResults = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await ref.read(authServiceProvider).searchUsers(query);
      if (mounted) setState(() { _searchResults = results; _isSearching = false; });
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _startChat(String userId, String displayName) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(chatSessionsProvider.notifier).createSession(userId, displayName);
      if (!mounted) return;
      await ref.read(chatSessionsProvider.notifier).refresh();
      final sessions = ref.read(chatSessionsProvider);
      if (sessions.isEmpty) return;
      final session = sessions.firstWhere(
        (s) => s.peerId == userId,
        orElse: () => sessions.first,
      );
      router.push('/sys_config/chat/${session.id}');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline),
            onPressed: () {
              ref.read(sessionProvider.notifier).lock();
              context.go('/');
            },
            tooltip: 'Panic Lock',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Friends'),
            Tab(icon: Icon(Icons.search), text: 'Find People'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(isDark),
          _buildFindPeople(isDark),
        ],
      ),
    );
  }

  Widget _buildFriendsList(bool isDark) {
    final sessions = ref.watch(chatSessionsProvider);
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No friends yet',
                style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Use the "Find People" tab to add friends',
                style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final s = sessions[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
            child: Text(
              s.peerName.isNotEmpty ? s.peerName[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(s.peerName),
          subtitle: Text(s.lastMessage?.content ?? 'Tap to chat'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.message_outlined),
                onPressed: () => context.push('/sys_config/chat/${s.id}'),
              ),
              IconButton(
                icon: const Icon(Icons.call_outlined),
                onPressed: () => context.push('/sys_config/call/audio/${s.id}'),
              ),
              IconButton(
                icon: const Icon(Icons.videocam_outlined),
                onPressed: () => context.push('/sys_config/call/video/${s.id}'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFindPeople(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search by name or username...',
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: _searchUsers,
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Search for people to add'
                            : 'No users found',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
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
                                backgroundColor: isDark
                                    ? AppTheme.primaryDark
                                    : AppTheme.primaryLight,
                                child: user['avatar_url'] == null
                                    ? Text(
                                        displayName[0].toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      )
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
                          trailing: ElevatedButton.icon(
                            icon: const Icon(Icons.message, size: 16),
                            label: const Text('Message'),
                            onPressed: () => _startChat(user['id'], displayName),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../core/security/session_manager.dart';
import '../providers/chat_provider.dart';
import '../providers/friend_provider.dart';

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

  Future<void> _sendFriendRequest(String userId) async {
    try {
      await ref.read(friendRepositoryProvider).sendRequest(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('FRIEND REQUEST TRANSMITTED'), backgroundColor: Colors.black),
        );
        ref.invalidate(sentRequestsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TRANSMISSION FAILED: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startChat(String userId, String displayName) async {
    try {
      await ref.read(chatSessionsProvider.notifier).createSession(userId, displayName);
      if (!mounted) return;
      await ref.read(chatSessionsProvider.notifier).refresh();
      if (!mounted) return;
      final sessions = ref.read(chatSessionsProvider);
      final session = sessions.firstWhere((s) => s.peerId == userId);
      if (!mounted) return;
      context.push('/sys_config/chat/${session.id}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ERROR: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'GLOBAL DIRECTORY',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emergency_rounded, color: Colors.red),
            onPressed: () => ref.read(sessionProvider.notifier).panic(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black38,
          indicatorWeight: 4,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
          tabs: const [
            Tab(text: 'AUTHORIZED FRIENDS'),
            Tab(text: 'FIND PEOPLE'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(),
          _buildFindPeople(),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    final friendsAsync = ref.watch(friendsProvider);

    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) {
          return _buildEmptyState(
            Icons.people_outline_rounded,
            'NO AUTHORIZED PEERS',
            'Your secure network is currently empty.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 20),
          itemCount: friends.length,
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 84, color: Color(0xFFF0F2F5)),
          itemBuilder: (context, index) {
            final friend = friends[index];
            final name = friend['display_name'] ?? friend['username'] ?? 'Unknown';
            final userId = friend['id'];
            final isOnline = friend['is_online'] ?? false;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                child: Center(
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              subtitle: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: isOnline ? Colors.green : Colors.black12, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOnline ? 'ONLINE' : 'OFFLINE',
                    style: TextStyle(color: isOnline ? Colors.green : Colors.black38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(Icons.chat_bubble_outline_rounded, () => _startChat(userId, name)),
                  const SizedBox(width: 8),
                  _buildActionButton(Icons.call_outlined, () => context.push('/sys_config/call/audio/$userId')),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
      error: (e, _) => Center(child: Text('ERROR: $e')),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F2F5)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black, size: 20),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildFindPeople() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0F2F5)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _searchUsers,
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.2),
              decoration: const InputDecoration(
                hintText: 'SEARCH BY IDENTITY...',
                hintStyle: TextStyle(color: Colors.black12, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.0),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.black),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator(color: Colors.black))
              : _searchResults.isEmpty
                  ? _buildEmptyState(
                      Icons.person_search_rounded,
                      'SEARCH THE VAULT',
                      'Find people by their username or display name.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 84, color: Color(0xFFF0F2F5)),
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        final name = user['display_name'] ?? user['username'] ?? 'Unknown';
                        final username = user['username'] ?? '';
                        final userId = user['id'];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                            child: Center(
                              child: Text(
                                name[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          subtitle: Text('@$username', style: const TextStyle(color: Colors.black38, fontSize: 12, fontWeight: FontWeight.w700)),
                          trailing: Consumer(
                            builder: (context, ref, child) {
                              final statusAsync = ref.watch(friendshipStatusProvider(userId));
                              return statusAsync.when(
                                data: (status) {
                                  if (status['is_friend'] == true) {
                                    return _buildActionButton(Icons.chat_bubble_outline_rounded, () => _startChat(userId, name));
                                  }
                                  final reqStatus = status['request_status'];
                                  if (reqStatus == 'pending') {
                                    return const Text('PENDING', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w900, fontSize: 10));
                                  }
                                  return ElevatedButton(
                                    onPressed: () => _sendFriendRequest(userId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                    child: const Text('ADD FRIEND', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                  );
                                },
                                loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)),
                                error: (_, __) => const Icon(Icons.error_outline),
                              );
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Color(0xFFF8F9FA), shape: BoxShape.circle),
            child: Icon(icon, size: 48, color: Colors.black12),
          ),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.black38, fontSize: 13)),
        ],
      ),
    );
  }
}

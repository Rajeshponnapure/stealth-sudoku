import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/auth_service.dart';
import '../providers/friend_provider.dart';
import '../providers/chat_provider.dart';

class ChatProfilePage extends ConsumerStatefulWidget {
  const ChatProfilePage({super.key});

  @override
  ConsumerState<ChatProfilePage> createState() => _ChatProfilePageState();
}

class _ChatProfilePageState extends ConsumerState<ChatProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _friendRequests = [];
  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = true;
  bool _isEditing = false;
  final _displayNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final userId = authService.currentUserId;
      if (userId != null) {
        // ✅ Use authService for profile, friendRepository for friends
        final profile = await authService.getUserProfile(userId);
        final friendRepo = ref.read(friendRepositoryProvider);
        final requests = await friendRepo.getPendingRequests();
        final friends = await friendRepo.getFriends();

        if (mounted) {
          setState(() {
            _profile = profile;
            _friendRequests = List<Map<String, dynamic>>.from(requests);
            _friends = List<Map<String, dynamic>>.from(friends);
            _displayNameController.text =
                profile?['display_name'] ?? '';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    try {
      final authService = ref.read(authServiceProvider);
      // ✅ Only pass displayName — username not in updateProfile signature
      await authService.updateProfile(
        displayName: _displayNameController.text.trim(),
      );
      setState(() => _isEditing = false);
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    try {
      // ✅ Use friendRepository directly
      await ref.read(friendRepositoryProvider).acceptRequest(requestId);
      await _loadProfile();
      // Invalidate providers so friends list refreshes everywhere
      ref.invalidate(friendsProvider);
      ref.invalidate(pendingRequestsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    try {
      await ref.read(friendRepositoryProvider).rejectRequest(requestId);
      await _loadProfile();
      ref.invalidate(pendingRequestsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: _saveProfile,
              tooltip: 'Save',
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => setState(() => _isEditing = false),
              tooltip: 'Cancel',
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(icon: Icon(Icons.person), text: 'Profile'),
            Tab(
              icon: Badge(
                label: Text('${_friendRequests.length}'),
                isLabelVisible: _friendRequests.isNotEmpty,
                child: const Icon(Icons.person_add),
              ),
              text: 'Requests',
            ),
            Tab(
              icon: const Icon(Icons.people),
              text: 'Friends (${_friends.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(isDark),
                _buildRequestsTab(isDark),
                _buildFriendsTab(isDark),
              ],
            ),
    );
  }

  // ──────────────────────────────────────────────
  // Tab 1: Profile
  // ──────────────────────────────────────────────
  Widget _buildProfileTab(bool isDark) {
    final email = _profile?['email'] ?? 'Not available';
    final displayName = _profile?['display_name'] ?? 'No name set';
    final username = _profile?['username'] ?? 'No username';
    final avatarUrl = _profile?['avatar_url'];
    final isOnline = _profile?['is_online'] ?? false;
    final createdAt = _profile?['created_at'] != null
        ? DateTime.tryParse(_profile!['created_at'])
        : null;

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // ── Avatar + Online indicator ──
            Stack(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor:
                      isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 44,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey,
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
            const SizedBox(height: 8),
            Text(
              isOnline ? '● Online' : '○ Offline',
              style: TextStyle(
                color: isOnline ? Colors.green : Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),

            // ── Info Card ──
            _buildInfoCard(
              isDark: isDark,
              children: [
                _buildInfoRow(
                  icon: Icons.email,
                  label: 'Email',
                  value: email,
                  isEditable: false,
                ),
                const Divider(height: 1),
                _buildInfoRow(
                  icon: Icons.badge,
                  label: 'Display Name',
                  value: displayName,
                  isEditable: _isEditing,
                  controller: _displayNameController,
                ),
                const Divider(height: 1),
                _buildInfoRow(
                  icon: Icons.alternate_email,
                  label: 'Username',
                  value: '@$username',
                  isEditable: false, // username not editable via updateProfile
                ),
                const Divider(height: 1),
                _buildInfoRow(
                  icon: Icons.calendar_today,
                  label: 'Member Since',
                  value: createdAt != null
                      ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                      : 'Unknown',
                  isEditable: false,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Stats Card ──
            _buildInfoCard(
              isDark: isDark,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat('Friends', '${_friends.length}',
                          Icons.people, Colors.blue),
                      _buildStat('Requests', '${_friendRequests.length}',
                          Icons.person_add, Colors.orange),
                      _buildStat(
                        'Chats',
                        '${ref.read(chatSessionsProvider).length}',
                        Icons.chat,
                        Colors.green,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Security Card ──
            _buildInfoCard(
              isDark: isDark,
              children: [
                ListTile(
                  leading: const Icon(Icons.lock, color: Colors.green),
                  title: const Text('End-to-End Encrypted'),
                  subtitle: const Text('All messages are encrypted'),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.shield, color: Colors.blue),
                  title: const Text('Encryption'),
                  subtitle: const Text('AES-256-GCM'),
                  trailing:
                      const Icon(Icons.info_outline, color: Colors.blue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Tab 2: Friend Requests
  // ──────────────────────────────────────────────
  Widget _buildRequestsTab(bool isDark) {
    if (_friendRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_disabled,
                size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No pending requests',
                style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Friend requests will appear here',
                style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _friendRequests.length,
        itemBuilder: (context, index) {
          final request = _friendRequests[index];
          final senderName =
              request['sender']?['display_name'] ??
              request['sender']?['username'] ??
              request['display_name'] ??
              request['username'] ??
              'Unknown';
          final senderEmail =
              request['sender']?['email'] ?? request['email'] ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                child: Text(
                  senderName[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(senderName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(senderEmail,
                  style: const TextStyle(fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle,
                        color: Colors.green, size: 32),
                    onPressed: () =>
                        _acceptFriendRequest(request['id'] as String),
                    tooltip: 'Accept',
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel,
                        color: Colors.red, size: 32),
                    onPressed: () =>
                        _rejectFriendRequest(request['id'] as String),
                    tooltip: 'Reject',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Tab 3: Friends
  // ──────────────────────────────────────────────
  Widget _buildFriendsTab(bool isDark) {
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No friends yet',
                style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text(
              'Search users from the chat list to add friends',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          final name = friend['display_name'] ??
              friend['username'] ??
              'Unknown';
          final isOnline = friend['is_online'] ?? false;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                isOnline ? '● Online' : '○ Offline',
                style: TextStyle(
                  color: isOnline ? Colors.green : Colors.grey,
                  fontSize: 12,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () => context.pop(),
                tooltip: 'Message',
              ),
            ),
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────
  Widget _buildInfoCard(
      {required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isEditable,
    TextEditingController? controller,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[500])),
                if (isEditable && controller != null)
                  TextField(
                    controller: controller,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: UnderlineInputBorder(),
                    ),
                  )
                else
                  Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

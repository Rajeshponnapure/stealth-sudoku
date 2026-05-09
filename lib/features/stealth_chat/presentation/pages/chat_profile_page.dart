import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/auth_service.dart';
import '../providers/friend_provider.dart';
import '../providers/chat_provider.dart';
import '../../../../core/security/session_manager.dart';

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
      final userId = authService.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await authService.updateProfile(
        userId: userId,
        displayName: _displayNameController.text.trim(),
      );
      if (mounted) setState(() => _isEditing = false);
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
          'Profile & Security',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emergency_rounded, color: Colors.red),
            onPressed: () {
              ref.read(sessionProvider.notifier).lock();
              context.go('/');
            },
            tooltip: 'Panic Lock',
          ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: Colors.black),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.check_rounded, color: Colors.green),
              onPressed: _saveProfile,
              tooltip: 'Save',
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.red),
              onPressed: () => setState(() => _isEditing = false),
              tooltip: 'Cancel',
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0),
          indicatorWeight: 4,
          tabs: [
            const Tab(text: 'OVERVIEW'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('REQUESTS'),
                  if (_friendRequests.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                      child: Text('${_friendRequests.length}', style: const TextStyle(color: Colors.white, fontSize: 9)),
                    ),
                ],
              ),
            ),
            Tab(text: 'FRIENDS (${_friends.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(),
                _buildRequestsTab(),
                _buildFriendsTab(),
              ],
            ),
    );
  }

  // ──────────────────────────────────────────────
  // Tab 1: Profile
  // ──────────────────────────────────────────────
  Widget _buildProfileTab() {
    final displayName = _profile?['display_name'] ?? 'No name set';
    final username = _profile?['username'] ?? 'No username';
    final email = _profile?['email'] ?? 'No email linked';
    final isOnline = _profile?['is_online'] ?? false;
    final createdAt = _profile?['created_at'] != null
        ? DateTime.tryParse(_profile!['created_at'])
        : null;

    return RefreshIndicator(
      color: Colors.black,
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            // Avatar
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Text(
                      isOnline ? 'ONLINE' : 'OFFLINE',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Info Section
            _buildInfoRow(
              icon: Icons.person_outline_rounded,
              label: 'DISPLAY NAME',
              value: displayName,
              isEditable: _isEditing,
              controller: _displayNameController,
            ),
            const Divider(height: 32, color: Color(0xFFF0F2F5)),
            _buildInfoRow(
              icon: Icons.alternate_email_rounded,
              label: 'USER IDENTITY',
              value: '@$username',
              isEditable: false,
            ),
            const Divider(height: 32, color: Color(0xFFF0F2F5)),
            _buildInfoRow(
              icon: Icons.email_outlined,
              label: 'SECURE EMAIL',
              value: email,
              isEditable: false,
            ),
            const Divider(height: 32, color: Color(0xFFF0F2F5)),
            _buildInfoRow(
              icon: Icons.calendar_today_rounded,
              label: 'INITIALIZED ON',
              value: createdAt != null
                  ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                  : 'Unknown',
              isEditable: false,
            ),
            const SizedBox(height: 40),

            // Stats
            Row(
              children: [
                Expanded(child: _buildStat('FRIENDS', '${_friends.length}', Icons.people_outline_rounded)),
                Expanded(child: _buildStat('SESSIONS', '${ref.read(chatSessionsProvider).length}', Icons.chat_bubble_outline_rounded)),
              ],
            ),
            const SizedBox(height: 40),

            // Security Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF0F2F5)),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: Colors.black, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'VAULT SECURITY',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSecurityAction(
                    label: 'MODIFY ACCESS PASSWORD',
                    icon: Icons.lock_reset_rounded,
                    onTap: _showPasswordChangeDialog,
                  ),
                  const Divider(height: 32, color: Color(0xFFF0F2F5)),
                  _buildSecurityAction(
                    label: 'BIOMETRIC AUTHENTICATION',
                    icon: Icons.fingerprint_rounded,
                    trailing: Text(
                      ref.watch(sessionProvider).biometricEnabled ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        color: ref.watch(sessionProvider).biometricEnabled ? Colors.green : Colors.black38,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                    onTap: () {}, // Handled in settings menu
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityAction({required String label, required IconData icon, required VoidCallback onTap, Widget? trailing}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Colors.black, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black87, letterSpacing: 0.5),
            ),
          ),
          trailing ?? const Icon(Icons.chevron_right_rounded, color: Colors.black26),
        ],
      ),
    );
  }

  void _showPasswordChangeDialog() {
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('CHANGE PASSWORD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter a new secure password for your vault access.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passController,
              obscureText: true,
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
              decoration: InputDecoration(
                hintText: 'NEW PASSWORD',
                hintStyle: const TextStyle(color: Colors.black12, fontWeight: FontWeight.w900),
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.black),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w900)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password too short')));
                return;
              }
              try {
                await ref.read(authServiceProvider).changePassword(passController.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully')));
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            child: const Text('UPDATE', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Tab 2: Friend Requests
  // ──────────────────────────────────────────────
  Widget _buildRequestsTab() {
    if (_friendRequests.isEmpty) {
      return _buildEmptyState(Icons.person_add_disabled_rounded, 'NO PENDING REQUESTS', 'Vault access requests will appear here.');
    }

    return RefreshIndicator(
      color: Colors.black,
      onRefresh: _loadProfile,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _friendRequests.length,
        itemBuilder: (context, index) {
          final request = _friendRequests[index];
          final senderName = request['sender']?['display_name'] ?? request['sender']?['username'] ?? 'Unknown';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0F2F5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: Text(senderName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(senderName, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
                      const Text('REQUESTING ACCESS', style: TextStyle(fontSize: 9, color: Colors.black38, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.black, size: 28),
                  onPressed: () => _acceptFriendRequest(request['id'] as String),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_rounded, color: Colors.black26, size: 28),
                  onPressed: () => _rejectFriendRequest(request['id'] as String),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_friends.isEmpty) {
      return _buildEmptyState(Icons.people_outline_rounded, 'NO AUTHORIZED FRIENDS', 'Search the global directory to add peers.');
    }

    return RefreshIndicator(
      color: Colors.black,
      onRefresh: _loadProfile,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          final name = friend['display_name'] ?? friend['username'] ?? 'Unknown';
          final isOnline = friend['is_online'] ?? false;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0F2F5)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
                child: Center(
                  child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
              subtitle: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: isOnline ? Colors.green : Colors.black12, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline ? 'ONLINE' : 'OFFLINE',
                    style: TextStyle(color: isOnline ? Colors.green : Colors.black26, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black12),
              onTap: () => context.pop(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.black12),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.black38, fontSize: 13)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isEditable,
    TextEditingController? controller,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: Colors.black),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.0)),
              const SizedBox(height: 4),
              if (isEditable && controller != null)
                TextField(
                  controller: controller,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black, letterSpacing: -0.2),
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none),
                )
              else
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black, letterSpacing: -0.2)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.black, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -1.0)),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.0)),
      ],
    );
  }
}

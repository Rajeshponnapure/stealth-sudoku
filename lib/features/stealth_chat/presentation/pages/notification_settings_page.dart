import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  bool _messageNotifications = true;
  bool _callNotifications = true;
  bool _groupNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _previewEnabled = false; // stealth — hide preview by default

  Future<void> _saveSettings() async {
    // ✅ Capture BEFORE await
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    // Simulate saving to preferences
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Notification settings saved')),
    );
    router.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildSection('Messages', [
            SwitchListTile(
              secondary: const Icon(Icons.message),
              title: const Text('Message Notifications'),
              subtitle: const Text('Show notifications for new messages'),
              value: _messageNotifications,
              onChanged: (v) => setState(() => _messageNotifications = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_off),
              title: const Text('Hide Message Preview'),
              subtitle: const Text('Don\'t show message content in notification'),
              value: _previewEnabled,
              onChanged: (v) => setState(() => _previewEnabled = v),
            ),
          ]),
          _buildSection('Calls', [
            SwitchListTile(
              secondary: const Icon(Icons.call),
              title: const Text('Call Notifications'),
              subtitle: const Text('Show incoming call alerts'),
              value: _callNotifications,
              onChanged: (v) => setState(() => _callNotifications = v),
            ),
          ]),
          _buildSection('Groups', [
            SwitchListTile(
              secondary: const Icon(Icons.group),
              title: const Text('Group Notifications'),
              subtitle: const Text('Show notifications for group messages'),
              value: _groupNotifications,
              onChanged: (v) => setState(() => _groupNotifications = v),
            ),
          ]),
          _buildSection('Sound & Vibration', [
            SwitchListTile(
              secondary: const Icon(Icons.volume_up),
              title: const Text('Sound'),
              value: _soundEnabled,
              onChanged: (v) => setState(() => _soundEnabled = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration),
              title: const Text('Vibration'),
              value: _vibrationEnabled,
              onChanged: (v) => setState(() => _vibrationEnabled = v),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }
}

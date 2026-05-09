import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const _keyMessage = 'notif_messages';
  static const _keyCall = 'notif_calls';
  static const _keyGroup = 'notif_groups';
  static const _keySound = 'notif_sound';
  static const _keyVibration = 'notif_vibration';
  static const _keyPreview = 'notif_preview';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _messageNotifications = prefs.getBool(_keyMessage) ?? true;
      _callNotifications = prefs.getBool(_keyCall) ?? true;
      _groupNotifications = prefs.getBool(_keyGroup) ?? true;
      _soundEnabled = prefs.getBool(_keySound) ?? true;
      _vibrationEnabled = prefs.getBool(_keyVibration) ?? true;
      _previewEnabled = prefs.getBool(_keyPreview) ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMessage, _messageNotifications);
    await prefs.setBool(_keyCall, _callNotifications);
    await prefs.setBool(_keyGroup, _groupNotifications);
    await prefs.setBool(_keySound, _soundEnabled);
    await prefs.setBool(_keyVibration, _vibrationEnabled);
    await prefs.setBool(_keyPreview, _previewEnabled);

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Notification settings saved')),
    );
    router.pop();
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
          'Alert Protocols',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('DEPLOY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSection('COMMUNICATIONS', [
            _buildSwitchTile(
              icon: Icons.message_rounded,
              title: 'DIRECT MESSAGES',
              subtitle: 'NOTIFY ON INCOMING DATA',
              value: _messageNotifications,
              onChanged: (v) => setState(() => _messageNotifications = v),
            ),
            _buildSwitchTile(
              icon: Icons.visibility_off_rounded,
              title: 'STEALTH MODE',
              subtitle: 'HIDE CONTENT PREVIEWS',
              value: _previewEnabled,
              onChanged: (v) => setState(() => _previewEnabled = v),
            ),
          ]),
          const SizedBox(height: 32),
          _buildSection('VOICE SECURE', [
            _buildSwitchTile(
              icon: Icons.call_rounded,
              title: 'INCOMING CALLS',
              subtitle: 'SIGNAL ON VOICE REQUEST',
              value: _callNotifications,
              onChanged: (v) => setState(() => _callNotifications = v),
            ),
          ]),
          const SizedBox(height: 32),
          _buildSection('HAPTIC & AUDIO', [
            _buildSwitchTile(
              icon: Icons.volume_up_rounded,
              title: 'AUDIBLE SIGNALS',
              subtitle: 'PLAY SECURE TONES',
              value: _soundEnabled,
              onChanged: (v) => setState(() => _soundEnabled = v),
            ),
            _buildSwitchTile(
              icon: Icons.vibration_rounded,
              title: 'HAPTIC FEEDBACK',
              subtitle: 'VIBRATE ON ALERT',
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
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.black38,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0F2F5)),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.black, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w900)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.black,
      ),
    );
  }
}

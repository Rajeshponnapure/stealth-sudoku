import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/theme_provider.dart';
import '../../../stealth_chat/presentation/providers/auth_provider.dart';
import '../../../../core/security/session_manager.dart';



class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _secretTapCount = 0;
  DateTime? _lastTapTime;

  @override
  Widget build(BuildContext context) {
    final prefsService = ref.watch(preferencesServiceProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Section
          _buildSection(
            'Appearance',
            [
              SwitchListTile(
                secondary: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                ),
                title: const Text('Dark Mode'),
                subtitle: const Text('Toggle dark theme'),
                value: isDark,
                onChanged: (value) {
                  ref.read(themeModeProvider.notifier).toggleTheme();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Game Settings
          _buildSection(
            'Game Settings',
            [
              FutureBuilder<bool>(
                future: prefsService.isHintEnabled(),
                builder: (context, snapshot) {
                  return SwitchListTile(
                    title: const Text('Enable Hints'),
                    subtitle: const Text('Show hint button during game'),
                    value: snapshot.data ?? true,
                    onChanged: (value) {
                      prefsService.setHintEnabled(value);
                      setState(() {});
                    },
                  );
                },
              ),
              FutureBuilder<bool>(
                future: prefsService.isAutoCheckEnabled(),
                builder: (context, snapshot) {
                  return SwitchListTile(
                    title: const Text('Auto Check'),
                    subtitle: const Text('Automatically check for errors'),
                    value: snapshot.data ?? true,
                    onChanged: (value) {
                      prefsService.setAutoCheckEnabled(value);
                      setState(() {});
                    },
                  );
                },
              ),
              FutureBuilder<bool>(
                future: prefsService.isHighlightEnabled(),
                builder: (context, snapshot) {
                  return SwitchListTile(
                    title: const Text('Highlight Cells'),
                    subtitle: const Text('Highlight selected row/column'),
                    value: snapshot.data ?? true,
                    onChanged: (value) {
                      prefsService.setHighlightEnabled(value);
                      setState(() {});
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Sound & Haptics
          _buildSection(
            'Sound & Haptics',
            [
              FutureBuilder<bool>(
                future: prefsService.isSoundEnabled(),
                builder: (context, snapshot) {
                  return SwitchListTile(
                    title: const Text('Sound Effects'),
                    value: snapshot.data ?? true,
                    onChanged: (value) {
                      prefsService.setSoundEnabled(value);
                      setState(() {});
                    },
                  );
                },
              ),
              FutureBuilder<bool>(
                future: prefsService.isVibrationEnabled(),
                builder: (context, snapshot) {
                  return SwitchListTile(
                    title: const Text('Vibration'),
                    value: snapshot.data ?? true,
                    onChanged: (value) {
                      prefsService.setVibrationEnabled(value);
                      setState(() {});
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // About
          _buildSection(
            'About',
            [
              ListTile(
                title: const Text('App Version'),
                subtitle: GestureDetector(
                  onTap: _onVersionTap,
                  child: Text(
                    AppConstants.appVersion,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                trailing: _secretTapCount > 0
                    ? Text('$_secretTapCount/${AppConstants.stealthTapCount}')
                    : null,
              ),
              ListTile(
                title: const Text('Help & Support'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Show help dialog
                },
              ),
              ListTile(
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Show privacy policy
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildDangerZone(),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Danger Zone',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Reset All Data'),
            subtitle: const Text('Clear all game progress and settings'),
            trailing: const Icon(Icons.warning, color: Colors.red),
            onTap: _showResetDialog,
          ),
        ),
      ],
    );
  }

  void _onVersionTap() {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inSeconds > 2) {
      _secretTapCount = 0;
    }

    _lastTapTime = now;
    _secretTapCount++;
    setState(() {});

    if (_secretTapCount >= AppConstants.stealthTapCount) {
      _secretTapCount = 0;
      _showStealthUnlock();
    }
  }

  void _showStealthUnlock() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('🔐 Stealth Mode'),
      content: const Text('Access secure chat system?'),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            context.pop();
            
            // Check if authenticated
            final isAuthenticated = ref.read(isAuthenticatedProvider);
            final sessionStatus = ref.read(sessionProvider).status;
            
            if (!isAuthenticated) {
              // Not authenticated - go to login
              context.push('/sys_config/login');
            } else if (sessionStatus != SessionStatus.unlocked) {
              // Authenticated but locked - go to unlock
              context.push('/sys_config/unlock');
            } else {
              // Authenticated and unlocked - go to chat list
              context.push('/sys_config/list');
            }
          },
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}


  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Data?'),
        content: const Text(
          'This will delete all your game progress, stats, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);  // ✅ capture before await
                  final router = GoRouter.of(context);              // ✅ capture before await
                  await ref.read(preferencesServiceProvider).clearAll();
                  if (mounted) {
                    router.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('All data has been reset')),
                    );
                  }
                },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/security/session_manager.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _secretTapCount = 0;
  DateTime? _lastTapTime;

  // ✅ Local state — loaded synchronously from already-initialized SharedPreferences
  bool _hintsEnabled = true;
  bool _autoCheck = true;
  bool _highlightCells = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = ref.read(preferencesServiceProvider);
    final hint = await prefs.isHintEnabled();
    final auto = await prefs.isAutoCheckEnabled();
    final highlight = await prefs.isHighlightEnabled();
    final sound = await prefs.isSoundEnabled();
    final vibration = await prefs.isVibrationEnabled();
    if (mounted) {
      setState(() {
        _hintsEnabled = hint;
        _autoCheck = auto;
        _highlightCells = highlight;
        _soundEnabled = sound;
        _vibrationEnabled = vibration;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesServiceProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Appearance ──────────────────────────────────────────────────
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

          // ── Game Settings ───────────────────────────────────────────────
          _buildSection(
            'Game Settings',
            [
              SwitchListTile(
                title: const Text('Enable Hints'),
                subtitle: const Text('Show hint button during game'),
                value: _hintsEnabled,
                onChanged: (value) {
                  setState(() => _hintsEnabled = value);
                  prefs.setHintEnabled(value);
                },
              ),
              SwitchListTile(
                title: const Text('Auto Check'),
                subtitle: const Text('Automatically check for errors'),
                value: _autoCheck,
                onChanged: (value) {
                  setState(() => _autoCheck = value);
                  prefs.setAutoCheckEnabled(value);
                },
              ),
              SwitchListTile(
                title: const Text('Highlight Cells'),
                subtitle: const Text('Highlight selected row/column'),
                value: _highlightCells,
                onChanged: (value) {
                  setState(() => _highlightCells = value);
                  prefs.setHighlightEnabled(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Sound & Haptics ─────────────────────────────────────────────
          _buildSection(
            'Sound & Haptics',
            [
              SwitchListTile(
                title: const Text('Sound Effects'),
                value: _soundEnabled,
                onChanged: (value) {
                  setState(() => _soundEnabled = value);
                  prefs.setSoundEnabled(value);
                },
              ),
              SwitchListTile(
                title: const Text('Vibration'),
                value: _vibrationEnabled,
                onChanged: (value) {
                  setState(() => _vibrationEnabled = value);
                  prefs.setVibrationEnabled(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── About ───────────────────────────────────────────────────────
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
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Help & Support'),
                      content: const Text(
                        'For support, contact us at support@stealthsudoku.com',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => ctx.pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Privacy Policy'),
                      content: const SingleChildScrollView(
                        child: Text(
                          'Stealth Sudoku does not collect or share any personal data. '
                          'All communication is encrypted and stored securely. '
                          'We do not sell your data to third parties.',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => ctx.pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
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

      // Go directly to unlock screen for better stealth
      final isUnlocked = ref.read(sessionProvider).status == SessionStatus.unlocked;
      if (isUnlocked) {
        context.push('/sys_config/list');
      } else {
        context.push('/sys_config/unlock');
      }
    }
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
              final messenger = ScaffoldMessenger.of(context);
              final router = GoRouter.of(context);
              await ref.read(preferencesServiceProvider).clearAll();
              // Reset local state after clear
              if (mounted) {
                setState(() {
                  _hintsEnabled = true;
                  _autoCheck = true;
                  _highlightCells = true;
                  _soundEnabled = true;
                  _vibrationEnabled = true;
                });
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

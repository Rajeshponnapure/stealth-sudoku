import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/security/session_manager.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';


class StealthUnlockPage extends ConsumerStatefulWidget {
  const StealthUnlockPage({super.key});

  @override
  ConsumerState<StealthUnlockPage> createState() => _StealthUnlockPageState();
}

class _StealthUnlockPageState extends ConsumerState<StealthUnlockPage> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('System Configuration'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: (bottomInset > 0 ? bottomInset : 24) + 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight -
                      24 -
                      (bottomInset > 0 ? bottomInset : 24),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Icon(
                        Icons.lock_outline,
                        size: 80,
                        color:
                            isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Enter Security Code',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This is a secure area. Please authenticate.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _pinController,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        decoration: InputDecoration(
                          hintText: '••••••',
                          counterText: '',
                          errorText: _errorMessage,
                          prefixIcon: const Icon(Icons.vpn_key),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                        onSubmitted: (_) => _handleUnlock(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleUnlock,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? AppTheme.primaryDark
                                : AppTheme.primaryLight,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Unlock',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Biometric Unlock Button
                      FutureBuilder<bool>(
                        future: ref
                            .read(biometricServiceProvider)
                            .isBiometricAvailable(),
                        builder: (context, snapshot) {
                          if (snapshot.data != true ||
                              !ref.watch(sessionProvider).biometricEnabled) {
                            return const SizedBox.shrink();
                          }

                          return FutureBuilder<String>(
                            future: ref
                                .read(biometricServiceProvider)
                                .getBiometricTypeString(),
                            builder: (context, typeSnapshot) {
                              final biometricType =
                                  typeSnapshot.data ?? 'Biometric';

                              return SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _handleBiometricUnlock,
                                  icon: Icon(
                                    biometricType.contains('Face')
                                        ? Icons.face
                                        : Icons.fingerprint,
                                  ),
                                  label:
                                      Text('Unlock with $biometricType'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.amber),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'First time? Enter any 6-digit PIN to create your secure code.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.amber[200]
                                      : Colors.amber[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleUnlock() async {
    final pin = _pinController.text.trim();
    debugPrint('🔐 Attempting unlock with PIN: ${pin.length} digits');

    if (pin.length != 6) {
      setState(() {
        _errorMessage = 'PIN must be 6 digits';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🔐 Calling session unlock...');
      final success = await ref.read(sessionProvider.notifier).unlock(pin);
      debugPrint('🔐 Unlock result: $success');

      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (success) {
        debugPrint(
            '🔐 Session state after unlock: ${ref.read(sessionProvider).status}');
        debugPrint('🔐 Navigating to /sys_config/list');
        context.go('/sys_config/list');
      } else {
        setState(() {
          _errorMessage = 'Invalid PIN';
        });
        _pinController.clear();
      }
    } catch (e) {
      debugPrint('🔐 Error during unlock: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Authentication failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleBiometricUnlock() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success =
          await ref.read(sessionProvider.notifier).unlockWithBiometric();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (success) {
        debugPrint('🔐 Biometric unlock successful');
        context.go('/sys_config/list');
      } else {
        setState(() {
          _errorMessage = 'Biometric authentication failed';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Authentication failed: $e';
        _isLoading = false;
      });
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/security/session_manager.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/services/auth_service.dart';


class StealthUnlockPage extends ConsumerStatefulWidget {
  const StealthUnlockPage({super.key});

  @override
  ConsumerState<StealthUnlockPage> createState() => _StealthUnlockPageState();
}

class _StealthUnlockPageState extends ConsumerState<StealthUnlockPage> {
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = ref.read(preferencesServiceProvider);
    final savedUsername = await prefs.getNickname();
    if (savedUsername != null) {
      _usernameController.text = savedUsername;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
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
                        controller: _usernameController,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'Username',
                          prefixIcon: const Icon(Icons.person_outline),
                          errorText: _errorMessage != null && _errorMessage!.contains('Username') ? _errorMessage : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _pinController,
                        obscureText: _obscurePin,
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
                          errorText: _errorMessage != null && !_errorMessage!.contains('Username') ? _errorMessage : null,
                          prefixIcon: const Icon(Icons.vpn_key),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePin ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePin = !_obscurePin;
                              });
                            },
                          ),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => context.pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 16),
                          TextButton(
                            onPressed: () => context.push('/sys_config/register'),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            child: const Text('Create a Room'),
                          ),
                        ],
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
                                'Enter your room code to login. If you do not have a room yet, click "Create a Room".',
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
    final username = _usernameController.text.trim();
    final pin = _pinController.text.trim();
    debugPrint('🔐 Attempting unlock for $username with PIN');

    if (username.isEmpty) {
      setState(() {
        _errorMessage = 'Username is required';
      });
      return;
    }

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
      final authService = ref.read(authServiceProvider);
      final prefs = ref.read(preferencesServiceProvider);

      // Local unlock still only needs PIN (or we could use username+PIN too, 
      // but let's keep local unlock simple for now unless requested)
      final success = await ref.read(sessionProvider.notifier).unlock(pin, force: false);
      debugPrint('🔐 Unlock result: $success');

      if (success) {
        // ── Personal Vault Login ──
        if (!authService.isAuthenticated) {
          try {
            final roomId = await prefs.getRoomId();
            
            // ✅ PHASE 1 FIX: Block login if no registration found — don't use placeholder
            if (roomId == null) {
              throw Exception('Device not registered. Please register first.');
            }
            
            await authService.signInToVault(username, pin, roomId, allowRegistration: false);
          } catch (e) {
            debugPrint('🔐 Failed to enter vault: $e');
            String msg = 'Incorrect credentials. Please check your username and PIN.';
            if (e.toString().contains('not registered')) {
              msg = 'Device not registered. Please register first.';
            }
            setState(() {
              _errorMessage = msg;
              _isLoading = false;
            });
            return; // ⛔ STOP navigation if vault login fails
          }
        }

        if (mounted) {
          context.go('/sys_config/list');
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid PIN';
          _isLoading = false;
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

      if (success) {
        debugPrint('🔐 Biometric unlock successful');

        // Perform vault login so Supabase is authenticated
        final authService = ref.read(authServiceProvider);
        if (!authService.isAuthenticated) {
          try {
            final prefs = ref.read(preferencesServiceProvider);
            final savedUsername = await prefs.getNickname();
            final roomId = await prefs.getRoomId();
            final savedPin = await ref.read(sessionProvider.notifier).getSavedPin();

            if (savedUsername == null || roomId == null || savedPin == null) {
              if (!mounted) return;
              setState(() {
                _errorMessage = 'Saved credentials not found. Please unlock with PIN first.';
                _isLoading = false;
              });
              return;
            }

            await authService.signInToVault(savedUsername, savedPin, roomId, allowRegistration: false);
          } catch (e) {
            debugPrint('🔐 Biometric vault login failed: $e');
            if (!mounted) return;
            setState(() {
              _errorMessage = 'Vault login failed. Please unlock with PIN.';
              _isLoading = false;
            });
            return;
          }
        }

        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          context.go('/sys_config/list');
        }
      } else {
        setState(() {
          _isLoading = false;
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/security/session_manager.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/stealth_notification_service.dart';

class StealthUnlockPage extends ConsumerStatefulWidget {
  const StealthUnlockPage({super.key});

  @override
  ConsumerState<StealthUnlockPage> createState() => _StealthUnlockPageState();
}

class _StealthUnlockPageState extends ConsumerState<StealthUnlockPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
    final savedEmail = await prefs.getNickname(); 
    if (savedEmail != null && savedEmail.contains('@')) {
      _emailController.text = savedEmail;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleUnlock() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'EMAIL AND PASSWORD REQUIRED');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final response = await authService.signInWithEmail(email: email, password: password);

      if (response.user != null) {
        // Unlock session locally with the password
        final success = await ref.read(sessionProvider.notifier).unlock(password, force: true);
        if (success && mounted) {
          _handlePostUnlockRedirect();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'AUTHENTICATION FAILED: ${e.toString().toUpperCase()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleBiometricUnlock() async {
    setState(() => _isLoading = true);
    try {
      final success = await ref.read(sessionProvider.notifier).unlockWithBiometric();
      if (!mounted) return;

      if (success) {
        final authService = ref.read(authServiceProvider);
        if (!authService.isAuthenticated) {
          // Attempt background login with saved credentials
          final prefs = ref.read(preferencesServiceProvider);
          final email = await prefs.getNickname();
          final password = await ref.read(sessionProvider.notifier).getSavedPin();

          if (email != null && password != null) {
            await authService.signInWithEmail(email: email, password: password);
          }
        }
        if (mounted) _handlePostUnlockRedirect();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'BIOMETRIC AUTHENTICATION FAILED';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Handle redirect after successful unlock - checks for pending notification navigation
  void _handlePostUnlockRedirect() {
    final nav = StealthNotificationService.getPendingNavigation();
    if (nav != null) {
      final type = nav['type'];
      if (type == 'chat') {
        final chatId = nav['chatId'];
        if (chatId != null) {
          context.go('/sys_config/chat/$chatId');
          return;
        }
      } else if (type == 'friend_request' || type == 'friend_request_accepted') {
        context.go('/sys_config/list');
        return;
      } else if (type == 'incoming_call') {
        final chatId = nav['chatId'];
        final callId = nav['callId'];
        final isVideo = nav['isVideo'] == 'true';
        final sdpOffer = nav['sdpOffer'];
        if (chatId != null && callId != null) {
          // Navigate to call screen to accept the incoming call
          context.go('/sys_config/call/${isVideo ? 'video' : 'audio'}/$chatId?callId=$callId', extra: sdpOffer);
          return;
        }
      }
    }
    // Default: go to chat list
    context.go('/sys_config/list');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock_person_rounded, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 40),
                const Text(
                  'VAULT ACCESS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'AUTHORIZED PERSONNEL ONLY',
                  style: TextStyle(
                    color: Colors.black38,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 64),
                
                _buildTextField(
                  controller: _emailController,
                  label: 'EMAIL ADDRESS',
                  hint: 'ENTER YOUR EMAIL',
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 24),
                
                _buildTextField(
                  controller: _passwordController,
                  label: 'VAULT PASSWORD',
                  hint: '••••••••',
                  icon: Icons.key_rounded,
                  obscure: _obscurePin,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  ),
                  onSubmitted: (_) => _handleUnlock(),
                ),
                
                if (_errorMessage != null) ...[
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 56),
                
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleUnlock,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 10,
                      shadowColor: Colors.black.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text(
                            'DECRYPT & ACCESS',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                
                FutureBuilder<bool>(
                  future: ref.read(biometricServiceProvider).isBiometricAvailable(),
                  builder: (context, snapshot) {
                    if (snapshot.data != true || !ref.watch(sessionProvider).biometricEnabled) {
                      return const SizedBox.shrink();
                    }
                    return TextButton.icon(
                      onPressed: _handleBiometricUnlock,
                      icon: const Icon(Icons.fingerprint_rounded, color: Colors.black, size: 20),
                      label: const Text(
                        'BIOMETRIC AUTH',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => context.push('/sys_config/register'),
                  child: const Text(
                    'INITIALIZE NEW VAULT',
                    style: TextStyle(color: Colors.black38, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.0),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool isNumber = false,
    int? maxLength,
    Widget? suffix,
    Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.0),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0F2F5)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            maxLength: maxLength,
            onSubmitted: onSubmitted,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: obscure ? 10 : -0.2,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.black12, fontWeight: FontWeight.w500, letterSpacing: 1.0),
              prefixIcon: Icon(icon, color: Colors.black, size: 20),
              suffixIcon: suffix,
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
        ),
      ],
    );
  }
}

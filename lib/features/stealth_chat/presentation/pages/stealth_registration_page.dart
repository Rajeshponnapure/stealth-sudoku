import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../core/security/session_manager.dart';

class StealthRegistrationPage extends ConsumerStatefulWidget {
  const StealthRegistrationPage({super.key});

  @override
  ConsumerState<StealthRegistrationPage> createState() => _StealthRegistrationPageState();
}

class _StealthRegistrationPageState extends ConsumerState<StealthRegistrationPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'ALL FIELDS ARE REQUIRED');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'PASSWORDS DO NOT MATCH');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'PASSWORD TOO SHORT (MIN 6 CHARS)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signUpWithEmail(
        email: email,
        password: password,
        username: username,
      );

      if (mounted) {
        // Unlock session locally with the password (as a PIN equivalent for encryption)
        await ref.read(sessionProvider.notifier).unlock(password, force: true);
        if (mounted) context.go('/sys_config/list');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'REGISTRATION FAILED: ${e.toString().toUpperCase()}';
        _isLoading = false;
      });
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
      ),
      body: Center(
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
                child: const Icon(Icons.shield_rounded, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 40),
              const Text(
                'VAULT INITIALIZATION',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ESTABLISH GLOBAL IDENTITY',
                style: TextStyle(
                  color: Colors.black38,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              _buildTextField(
                controller: _usernameController,
                label: 'USER IDENTITY',
                hint: 'Choose your username',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _emailController,
                label: 'EMAIL ADDRESS',
                hint: 'Enter your secure email',
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _passwordController,
                label: 'VAULT PASSWORD',
                hint: 'Minimum 6 characters',
                icon: Icons.lock_rounded,
                obscure: true,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _confirmPasswordController,
                label: 'CONFIRM PASSWORD',
                hint: 'Repeat your password',
                icon: Icons.lock_clock_outlined,
                obscure: true,
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
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
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
                          'AUTHORIZE ACCESS',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                        ),
                ),
              ),
              const SizedBox(height: 48),
            ],
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
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.black12, fontWeight: FontWeight.w500),
              prefixIcon: Icon(icon, color: Colors.black, size: 20),
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

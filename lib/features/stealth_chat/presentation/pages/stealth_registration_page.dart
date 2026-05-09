import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../core/security/session_manager.dart';

class StealthRegistrationPage extends ConsumerStatefulWidget {
  const StealthRegistrationPage({super.key});

  @override
  ConsumerState<StealthRegistrationPage> createState() => _StealthRegistrationPageState();
}

class _StealthRegistrationPageState extends ConsumerState<StealthRegistrationPage> {
  final _nameController = TextEditingController();
  final _roomIdController = TextEditingController();
  final _roomCodeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final roomId = _roomIdController.text.trim();
    final code = _roomCodeController.text.trim();

    if (name.isEmpty || roomId.isEmpty || code.length != 6) {
      setState(() {
        _errorMessage = 'Name, Room ID, and Vault PIN are required';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final prefs = ref.read(preferencesServiceProvider);

      // 1. Sign in to the personal vault
      final response = await authService.signInToVault(name, code, roomId, allowRegistration: true);

      if (response.user != null) {
        // 2. Save local registration data
        await prefs.setNickname(name);
        await prefs.setRoomId(roomId);
        await prefs.setStealthRegistered(true);

        // 3. Unlock session locally with forced override
        await ref.read(sessionProvider.notifier).unlock(code, force: true);

        if (mounted) {
          // Navigate to the chat list (Home Section)
          context.go('/sys_config/list');
        }
      } else {
        setState(() {
          _errorMessage = 'Registration failed: No user returned';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Registration failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            const Icon(Icons.lock_person, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Secure Setup',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your private communication space',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Nickname',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomIdController,
              decoration: const InputDecoration(
                labelText: 'Room ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.meeting_room),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomCodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Vault PIN (6 digits)',
                counterText: '',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Vault'),
              ),
            ),
          ],
        ),
      ),
    ),
      ),
    );
  }
}

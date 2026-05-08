import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/di/injection_container.dart';
import 'core/router/app_router.dart';
import 'shared/services/stealth_notification_service.dart';
import 'shared/services/device_service.dart';
import 'shared/services/auth_service.dart';
import 'core/theme/app_theme.dart';

const _supabaseUrl = 'https://owyjeacntzcnugfpayeb.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93eWplYWNudHpjbnVnZnBheWViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE0MTY1OTksImV4cCI6MjA4Njk5MjU5OX0.sDW2bPVOD0YHCXNz8wQR3Rv-SOazijXJfVnyT212TPc';

// ── Firebase Background Handler (Must be top-level) ──
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need to initialize Firebase here because the app is killed:
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
  // The OS will automatically display the notification if it contains a 'notification' block.
  // Or you can trigger StealthNotificationService here manually.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try to initialize Firebase, but catch error if google-services.json is missing
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase init failed (Likely missing google-services.json): $e");
  }

  // ✅ Run Supabase init + notifications in PARALLEL
  await Future.wait([
    _initSupabaseWithRetry(),
    _initNotifications(),
  ]);

  final overrides = await initializeDependencies();

  runApp(
    ProviderScope(
      overrides: overrides,
      child: const MyApp(),
    ),
  );
}

Future<void> _initSupabaseWithRetry({int maxRetries = 3}) async {
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: true,
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          logLevel: RealtimeLogLevel.info,
          timeout: Duration(seconds: 30),
        ),
        storageOptions: const StorageClientOptions(
          retryAttempts: 2,
        ),
      );
      debugPrint('✅ Supabase initialized (attempt $attempt)');
      return;
    } catch (e) {
      debugPrint('⚠️ Supabase init attempt $attempt failed: $e');
      if (attempt < maxRetries) {
        await Future.delayed(Duration(seconds: attempt * 2));
      } else {
        rethrow;
      }
    }
  }
}

Future<void> _initNotifications() async {
  // ✅ Skip on Web and Windows — not supported
  if (kIsWeb || (!kIsWeb && Platform.isWindows)) return;
  try {
    await StealthNotificationService.initialize();
    await StealthNotificationService.requestPermissions();
    StealthNotificationService.startGlobalCallListener();
  } catch (e) {
    debugPrint('Notifications skipped: $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // ✅ Watch themeModeProvider from AppTheme so toggle actually applies
    final themeMode = ref.watch(themeModeProvider);
    // Register device FCM token for background pushes if already signed in
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final auth = ref.read(authServiceProvider);
        if (auth.isAuthenticated) {
          final deviceService = ref.read(deviceServiceProvider);
          await deviceService.registerToken();
          deviceService.startTokenRefreshListener();
        }
      } catch (e) {
        debugPrint('Device registration at startup failed: $e');
      }
    });
    
    return MaterialApp.router(
      title: 'Stealth Sudoku',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

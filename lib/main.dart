import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/di/injection_container.dart';
import 'core/router/app_router.dart';
import 'shared/services/stealth_notification_service.dart';

const _supabaseUrl = 'https://owyjeacntzcnugfpayeb.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im93eWplYWNudHpjbnVnZnBheWViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE0MTY1OTksImV4cCI6MjA4Njk5MjU5OX0.sDW2bPVOD0YHCXNz8wQR3Rv-SOazijXJfVnyT212TPc';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  } catch (e) {
    debugPrint('Notifications skipped: $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Stealth Sudoku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

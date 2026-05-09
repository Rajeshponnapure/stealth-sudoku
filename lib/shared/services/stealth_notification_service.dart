import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';  // for debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
class StealthNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  
  // ✅ Track which chat the user is currently looking at
  static String? activeChatId;

  // Disguise templates - make it look like game notifications
  static final List<Map<String, String>> _disguiseTemplates = [
    {
      'title': '🎮 New Level Unlocked!',
      'body': 'You earned {count} coins! Tap to collect rewards.',
    },
    {
      'title': '⭐ Achievement Unlocked!',
      'body': 'Complete {count} more puzzles to unlock bonus.',
    },
    {
      'title': '🏆 Daily Challenge Ready!',
      'body': '{count} new challenges available. Start playing!',
    },
    {
      'title': '💎 Bonus Reward!',
      'body': 'Claim your {count} gems now!',
    },
    {
      'title': '🎯 Streak Bonus!',
      'body': 'You have {count} day streak! Keep it going!',
    },
  ];

  // Initialize notifications
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  // Request notification permissions
  static Future<bool> requestPermissions() async {
    // 1. Request OS permission for showing notifications
    if (!(await Permission.notification.isGranted)) {
      await Permission.notification.request();
    }

    // 2. Request Firebase Messaging (Push) permission explicitly
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('FCM Permission status: ${settings.authorizationStatus}');
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      debugPrint('FCM Permission request failed: $e');
      return false;
    }
  }

  // Show disguised notification (looks like game notification)
  static Future<void> showDisguisedMessage({
    required String chatId,
    required String senderName,
    required String message,
    bool showBadge = true,
  }) async {
    // ✅ SILENCE RULE: If we are already in this chat, don't show a popup
    if (activeChatId == chatId) {
      debugPrint('Silencing notification for active chat: $chatId');
      return;
    }

    // Pick a random disguise template
    final template = _disguiseTemplates[Random().nextInt(_disguiseTemplates.length)];
    final messageLength = message.length;

    // Create disguised title and body
    final disguisedTitle = template['title']!;
    final disguisedBody = template['body']!.replaceAll('{count}', '$messageLength');

    // Store real data in payload for when user opens the app
    final payload = 'stealth_chat:$chatId:$senderName:$message';

    final androidDetails = AndroidNotificationDetails(
      'game_updates', // Channel ID - looks like game channel
      'Game Updates', // Channel name
      channelDescription: 'Sudoku game achievements and rewards',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 250, 250]), // Game-like vibration
      styleInformation: BigTextStyleInformation(
        disguisedBody,
        contentTitle: disguisedTitle,
      ),
      category: AndroidNotificationCategory.message, // 🥷 Disguised as game category
      visibility: NotificationVisibility.private, // Hide from lock screen details
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
      categoryIdentifier: 'game_notification',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      chatId.hashCode % 100000, // Unique ID per chat
      disguisedTitle,
      disguisedBody,
      details,
      payload: payload,
    );
  }

  // Show actual notification (when app is open)
  static Future<void> showInAppNotification({
    required String chatId,
    required String senderName,
    required String message,
  }) async {
    final payload = 'in_app_chat:$chatId';

    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Messages',
      channelDescription: 'Chat notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: false,
      enableVibration: false,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      senderName,
      message.length > 50 ? '${message.substring(0, 50)}...' : message,
      details,
      payload: payload,
    );
  }

  // Show friend request notification (disguised)
  static Future<void> showFriendRequest({
    required String requestId,
    required String senderName,
  }) async {
    const disguisedTitle = '🎁 Special Gift Available!';
    const disguisedBody = 'Tap to claim your surprise reward!';
    final payload = 'friend_request:$requestId';

    const androidDetails = AndroidNotificationDetails(
      'game_updates',
      'Game Updates',
      channelDescription: 'Sudoku game achievements and rewards',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      styleInformation: BigTextStyleInformation(disguisedBody),
      category: AndroidNotificationCategory.message,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      requestId.hashCode % 100000,
      disguisedTitle,
      disguisedBody,
      details,
      payload: payload,
    );
  }

  // Cancel specific notification
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Show friend request accepted notification (disguised)
  static Future<void> showFriendRequestAccepted({required String accepterName}) async {
    const disguisedTitle = '🎁 Gift Unlocked!';
    final disguisedBody = 'Your friend sent you a surprise reward! Tap to claim.';
    final payload = 'friend_request_accepted:$accepterName';

    final androidDetails = AndroidNotificationDetails(
      'game_updates',
      'Game Updates',
      channelDescription: 'Sudoku game achievements and rewards',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      styleInformation: BigTextStyleInformation(disguisedBody),
      category: AndroidNotificationCategory.message,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      accepterName.hashCode % 100000,
      disguisedTitle,
      disguisedBody,
      details,
      payload: payload,
    );
  }

  // Cancel all notifications
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // Show disguised incoming call notification
  static Future<void> showIncomingCall({
    required String chatId,
    required String callId,
    required String callerName,
    required bool isVideo,
    String? sdpOffer,
  }) async {
    const disguisedTitle = '🧩 Sudoku Tournament Update!';
    const disguisedBody = 'Your next opponent is ready! Tap to start the match.';
    // Include all call details in payload
    final payload = 'incoming_call:$chatId:$callId:$callerName:${isVideo ? 'video' : 'audio'}:${sdpOffer ?? ''}';

    final androidDetails = AndroidNotificationDetails(
      'game_updates',
      'Game Updates',
      channelDescription: 'Sudoku game achievements and rewards',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/launcher_icon',
      styleInformation: const BigTextStyleInformation(disguisedBody),
      category: AndroidNotificationCategory.call,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 500, 500]),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      callId.hashCode % 100000 + 10,
      disguisedTitle,
      disguisedBody,
      details,
      payload: payload,
    );
  }

  // Start Global Call Listener
  static void startGlobalCallListener() async {
    // Requires Supabase and SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final roomId = prefs.getString('stealth_room_id');
      
      if (roomId != null && roomId.isNotEmpty) {
        final myDeviceId = prefs.getString('stealth_device_id') ?? 'unknown_device';
        final myUserId = Supabase.instance.client.auth.currentUser?.id;

        Supabase.instance.client
            .channel('global_calls_$roomId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'calls',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'chat_id',
                value: roomId,
              ),
              callback: (payload) {
                final call = payload.newRecord;
                if (call['status'] == 'ringing' && call['caller_id'] != myDeviceId) {
                   showIncomingCall(
                     chatId: roomId,
                     callId: call['id'].toString(),
                     callerName: 'Secure Partner',
                     isVideo: call['call_type'] == 'video',
                     sdpOffer: call['sdp_offer'],
                   );
                }
              },
            )
            .subscribe();
            
        // Also listen for new messages to trigger morphed notifications!
        Supabase.instance.client
            .channel('global_msgs_$roomId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'chat_id',
                value: roomId,
              ),
              callback: (payload) async {
                final msg = payload.newRecord;
                // If it's not sent by me, trigger text notification
                final senderDeviceId = msg['sender_device_id'] ?? msg['sender_id'];
                final senderId = msg['sender_id'];
                if (senderDeviceId != myDeviceId && senderId != myUserId) {
                  await showDisguisedMessage(
                    chatId: roomId,
                    senderName: 'Secure User',
                    message: msg['content'] ?? 'New message',
                  );
                }
              },
            )
            .subscribe();
      }
    } catch (e) {
      debugPrint('Failed to start global call listener: $e');
    }
  }

  // Get active notifications
static Future<List<ActiveNotification>> getActiveNotifications() async {
  final androidPlugin = _notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin == null) {
    return <ActiveNotification>[];
  }

  final active = await androidPlugin.getActiveNotifications();
  return active;
}

// Handle notification tap
static void _onNotificationTapped(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null) return;

  // Parse payload and handle navigation
  if (payload.startsWith('stealth_chat:')) {
    // Format: stealth_chat:chatId:senderName:message
    final parts = payload.split(':');
    if (parts.length >= 2) {
      final chatId = parts[1];
      debugPrint('Navigate to chat: $chatId');  // ✅ Fixed
      _pendingNavigation = {'type': 'chat', 'chatId': chatId};
    }
  } else if (payload.startsWith('friend_request:')) {
    final requestId = payload.split(':')[1];
    debugPrint('Navigate to friend requests');
    _pendingNavigation = {'type': 'friend_request', 'requestId': requestId};
  } else if (payload.startsWith('incoming_call:')) {
    // Format: incoming_call:chatId:callId:callerName:callType:sdpOffer
    final parts = payload.split(':');
    if (parts.length >= 5) {
      final chatId = parts[1];
      final callId = parts[2];
      final callerName = parts[3];
      final isVideo = parts[4] == 'video';
      final sdpOffer = parts.length > 5 ? parts.sublist(5).join(':') : null;
      debugPrint('Navigate to incoming call: $chatId, video: $isVideo');
      _pendingNavigation = {
        'type': 'incoming_call',
        'chatId': chatId,
        'callId': callId,
        'callerName': callerName,
        'isVideo': isVideo.toString(),
        'sdpOffer': sdpOffer ?? '',
      };
    }
  }
}


  // Store pending navigation (to be used by app)
  static Map<String, String>? _pendingNavigation;

  static Map<String, String>? getPendingNavigation() {
    final nav = _pendingNavigation;
    _pendingNavigation = null;
    return nav;
  }

  // Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    return await Permission.notification.isGranted;
  }

  // Open app notification settings
  static Future<void> openNotificationSettings() async {
    await openAppSettings();
  }
}

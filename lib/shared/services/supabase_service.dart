import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  
  // Auth helpers
  static User? get currentUser => client.auth.currentUser;
  static String? get currentUserId => currentUser?.id;
  static bool get isAuthenticated => currentUser != null;
  
  // Real-time channels
  static RealtimeChannel createChannel(String channelName) {
    return client.channel(channelName);
  }
  
  // Storage helpers
  static SupabaseStorageClient get storage => client.storage;
  
  static String getPublicUrl(String bucket, String path) {
    return storage.from(bucket).getPublicUrl(path);
  }
  
  // Sign out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}

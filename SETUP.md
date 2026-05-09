# 🛠️ Setup & Deployment Guide: Stealth Sudoku

This guide provides step-by-step instructions for configuring the Supabase backend and building the Stealth Sudoku application.

---

## 📋 Prerequisites

Before you begin, ensure you have the following installed:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable channel)
- [Android Studio](https://developer.android.com/studio) / [Xcode](https://developer.apple.com/xcode/) (for mobile builds)
- [Supabase Account](https://supabase.com/)
- [Firebase Account](https://console.firebase.google.com/) (for Push Notifications)

---

## 🗄️ 1. Supabase Backend Setup

### Step 1: Create a Project
1. Create a new project in the Supabase Dashboard.
2. Note your **Project URL** and **Anon Key**.

### Step 2: Database Schema
Go to the **SQL Editor** in Supabase and run the following migrations found in the `supabase/migrations/` directory in this order:
1. `20260509_add_secure_pin_to_profiles.sql` (Initial Schema)
2. `20260509_emergency_sync_fix.sql` (Disables RLS and sets up Room/Device tables)

**Important Tables created:**
- `profiles`: Stores user nicknames and secure PIN hashes.
- `devices`: Tracks physical device IDs and FCM tokens.
- `rooms`: Manages private communication spaces.
- `messages`: Stores end-to-end encrypted message payloads.

---

## 🔔 2. Firebase Cloud Messaging (FCM)

1. Create a new project in the [Firebase Console](https://console.firebase.google.com/).
2. Add an **Android app** with your package name (e.g., `com.example.stealth_sudoku`).
3. Download `google-services.json` and place it in `android/app/`.
4. (Optional) Add an **iOS app** and download `GoogleService-Info.plist`. Place it in `ios/Runner/`.
5. In Firebase Settings, go to **Cloud Messaging** and ensure the API is enabled.

---

## ⚙️ 3. Flutter Configuration

### Step 1: Dependencies
Run the following command to fetch all required packages:
```bash
flutter pub get
```

### Step 2: Environment Variables
Create or update your Supabase configuration. This is usually located in `lib/core/di/injection_container.dart` or a `.env` file if implemented:
```dart
// Ensure these match your Supabase project
const String supabaseUrl = 'YOUR_SUPABASE_URL';
const String supabaseKey = 'YOUR_SUPABASE_ANON_KEY';
```

---

## 🏗️ 4. Building the Application

### Android (APK)
To generate a production-ready APK:
```bash
flutter build apk --release
```
The output will be located at `build/app/outputs/flutter-apk/app-release.apk`.

### iOS
1. Open `ios/Runner.xcworkspace` in Xcode.
2. Configure your **Development Team** and **Bundle Identifier**.
3. Run:
```bash
flutter build ios --release
```

---

## 🧪 5. Testing the Stealth Vault

1. **Launch the app**: You will see the Sudoku home screen.
2. **Access Settings**: Navigate to the System Configuration.
3. **Register**: Click **"Create a Room"**. Enter a Nickname and a 6-digit PIN.
4. **Second Device**: On another device, use the **same Room ID** and a different Nickname.
5. **Verify Sync**:
   - Check the `devices` table in Supabase to see both devices registered.
   - You should see the other user in the "People in my Room" bar inside the chat section.

---

## 🛡️ Security Notes
- **RLS**: In development, Row Level Security is disabled for speed. For production, re-enable RLS and configure policies that restrict message access to users within the same `room_id`.
- **Encryption Keys**: AES keys are derived from the User PIN. Ensure users choose complex PINs for maximum security.

---

**Need Help?** Contact the development team or refer to the project's internal documentation.

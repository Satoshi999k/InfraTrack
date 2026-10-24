# infatrack

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## API configuration

Android and iOS builds use the production API by default, including debug
builds, so a physical device does not depend on a developer computer's LAN IP.
To use a local API, pass its reachable base URL explicitly:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3001/api
```

Use `10.0.2.2` for the Android emulator. For a physical device, replace it with
the computer's current LAN IP and make sure the API server is listening on the
network. Web preview defaults to `http://localhost:3001/api`.

## Android push notifications

Push notifications use Firebase Cloud Messaging (FCM). The app continues to
work without Firebase configuration, but push delivery stays disabled until
both the Android app and API server are configured.

1. Create a Firebase project and register an Android app using the exact
   application ID from `android/app/build.gradle.kts` (`com.example.infatrack`).
2. In Firebase project settings, copy the Android app's API key and App ID, plus
   the project ID and messaging sender ID. Put those values in a local
   `firebase-config.json` file in this Flutter project:

   ```json
   {
     "FIREBASE_API_KEY": "your Firebase web API key",
     "FIREBASE_APP_ID": "your Android Firebase App ID",
     "FIREBASE_MESSAGING_SENDER_ID": "your Firebase sender ID",
     "FIREBASE_PROJECT_ID": "your Firebase project ID",
     "FIREBASE_STORAGE_BUCKET": "your Firebase storage bucket"
   }
   ```

   This file is git-ignored. It contains client configuration, not server
   credentials.
3. Create a Firebase service-account key for the server. Store its full JSON
   contents as the `FIREBASE_SERVICE_ACCOUNT_JSON` secret in the API server's
   hosting environment. Never put this key in the Flutter app, repository, or
   chat.
4. Deploy/restart the API server so it creates the `push_device_tokens` table
   and can send FCM messages.
5. Run the Android app with the local Firebase options:

   ```powershell
   D:\flutter\bin\flutter.bat run --dart-define-from-file=firebase-config.json
   ```

   Use the same define file when building an Android release. Android 13 and
   newer will ask the user for notification permission. Push token registration
   requires a signed-in user; tapping city-update notifications opens News.

Push credentials are separate: the app's Firebase values are client settings;
the service-account JSON is a private server credential. iOS/APNs delivery is
not configured by this Android setup.

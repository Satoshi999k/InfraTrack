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

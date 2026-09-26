# claimtrek

A new Flutter project.

## Firebase setup

The Firebase config files are not in the repository, because they carry the project's API
keys. Generate them locally before building:

```sh
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project-id>
```

This writes `lib/firebase_options.dart` and `android/app/google-services.json`, both of which
are git-ignored. Without them the app does not compile.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

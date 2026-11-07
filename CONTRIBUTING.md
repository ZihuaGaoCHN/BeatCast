# Contributing

Thanks for taking a look at BeatCast.

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm,android-arm64
```

Requirements are Flutter 3.41+, Android SDK 36 and JDK 17.

## Pull requests

- Keep changes focused and explain the watch model / Wear OS version used for
  hardware testing.
- Run `flutter analyze` and `flutter test` before opening a PR.
- Do not commit signing keys, `android/local.properties`, build outputs or APKs.

## Licensing

By contributing you agree that your contributions are licensed under the MIT
License in `LICENSE`.

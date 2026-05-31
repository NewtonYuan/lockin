# Release

## Steps

1. Increment the version in `pubspec.yaml`.

Example:

```yaml
version: 0.1.2+3
```

Increment the 2 AND the 3

2. Build the Android App Bundle from the project root:

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

3. Upload this file to Google Play:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Note

Release signing is already configured for this project. Make sure the keystore
file referenced by `android/key.properties` exists before building.

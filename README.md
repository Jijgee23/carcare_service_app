# CarCare service app

Staff-facing Flutter prototype. Package and application identities are unchanged by the toolchain upgrade.

## Toolchain

Use **Flutter 3.47.2 / Dart 3.13.2**. `.fvmrc` pins the team SDK; the SDK constraints in `pubspec.yaml` reject older installations but do not install Flutter for you. With FVM installed:

```sh
fvm install
fvm flutter --version
fvm flutter pub get
```

Without FVM, install Flutter 3.47.2 from the official archive, ensure your IDE uses that SDK, and omit `fvm` from the commands. Do not edit Flutter's `.metadata` revision to upgrade the SDK.

Android: JDK 17, Android SDK platform 36, NDK 28.2.13676358 (selected by Flutter), AGP 8.11.1, Gradle 8.14 and Kotlin 2.2.20. The existing Gradle/Kotlin versions are retained; notification-required Java desugaring is enabled with desugar_jdk_libs 2.1.4. Flutter defaults currently require Android API 24 or newer. Java 8 cannot build this project.

These Gradle/AGP/Kotlin versions meet Flutter 3.47.2's minimums, but Flutter can warn about future support. Migrating to AGP 9 and built-in Kotlin is a separate native-toolchain change requiring an Android build; do not raise those version numbers independently.

If Flutter reports Java 25 / Gradle 8.14 incompatibility, select an installed JDK 17 or 21 with `flutter config --jdk-dir="<JDK directory>"`, then verify using `flutter doctor -v`. This is a user-wide Flutter setting, not a project setting. Java 21 is also compatible with this Gradle version; Java 25 is not. On this workstation Flutter was configured to use the verified Java 21 JDK bundled with the Red Hat Java extension. Extension upgrades may move that directory, so a standalone JDK is preferable for a permanent setup.

iOS: macOS with Xcode compatible with this Flutter release and CocoaPods. The existing iOS deployment target remains 16.0. Select the service app's signing team and provisioning on the Mac.

## Local configuration

Copy `.env.example` to `.env`, then set `BASE_URL` to the team's staff API base ending `/api/v1/` (including its trailing slash). The example host is intentionally nonfunctional. The `.env` asset is required for builds and startup; it contains public client configuration, never server credentials. Tests do not connect to a backend.

PowerShell:

```powershell
Copy-Item .env.example .env
```

macOS:

```sh
cp .env.example .env
```

The existing Android/Firebase and Apple app identities are preserved. A Flutter upgrade does not require creating new Firebase apps.

## Validate and build

```sh
fvm flutter pub get
fvm flutter analyze
fvm flutter test
fvm flutter build apk --debug
```

After this upgrade, on the Mac update the native CocoaPods resolution because the tracked Podfile.lock still pins the older Firebase SDK:

```sh
fvm flutter pub get
cd ios
pod update --repo-update
cd ..
fvm flutter build ios --no-codesign
```

Review and commit the regenerated `ios/Podfile.lock`. Subsequent ordinary installs should use `pod install`; do not routinely update all native dependencies. The current Windows checkout cannot regenerate or validate the Apple native lockfile.

Firebase Core 4.14.0 selects Apple Firebase SDK 12.18.0; the old lockfile contains 12.14.0. This is an outstanding Mac-side migration step, not a validated iOS build.

Release Android signing still uses the prototype's debug key configuration. Configure real release signing before distributing a production build.

## Upgrade scope (2026-09-05)

- Flutter 3.47.2 / Dart 3.13.2 baseline and FVM pin.
- Chart library 0.68 → 1.2; intl 0.19 → 0.20.3.
- Updated compatible Dio, image picker, Firebase Core/Messaging, local notifications and URL launcher constraints.
- Retained Provider, GetX, Hive, Hive Flutter and JWT decoder. Storage/auth migrations are outside this compatibility change. Older null-safe packages can have their pre-Dart-3 SDK upper bound interpreted compatibly by Pub; successful dependency resolution is the check, not a manual edit to package caches.
- Enabled Android core-library desugaring and a compile SDK floor of 36.
- Replaced the unrelated counter template test with actual analytics chart/date-range coverage.
- Added the missing environment example.

## Validation recorded on 2026-09-05

- `flutter pub get`: passed; regenerated `pubspec.lock` with 18 dependency updates.
- `flutter analyze --no-pub`: passed with no issues under the existing analyzer rules. Flutter added standard exclusions for generated build/platform directories; existing suppressed lints were not expanded.
- `flutter test --no-pub`: passed; analytics chart renders 7-, 30- and 90-day ranges.
- `flutter build apk --debug --no-pub`: blocked before native compilation because this workstation has no Android SDK. Its PATH Java is version 8, so configure JDK 17 as well.
- iOS compilation, CocoaPods update and device behavior: not run; require the Mac.

A local ignored `.env` was copied from the example solely to allow asset validation. Replace its placeholder URL before using the app. No production backend requests were made.

## References

- [Flutter SDK archive](https://docs.flutter.dev/install/archive)
- [Local notifications Android requirements](https://pub.dev/packages/flutter_local_notifications/versions/22.3.0)
- [Chart migration changelog](https://pub.dev/packages/fl_chart/changelog)

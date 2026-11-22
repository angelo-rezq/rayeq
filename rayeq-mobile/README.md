# Rayeq mobile

Flutter customer and worker pilot for رايق, حلاقك عندك.

## Build

Use Flutter 3.50.1 / Dart 3.14.0 and JDK 21. Install the Android SDK and set ANDROID_HOME and JAVA_HOME for your machine. Local paths are not committed.

```sh
flutter pub get
flutter test
flutter analyze
flutter build apk --release --target-platform android-arm64 --dart-define=API_BASE_URL=https://rayeq-platform.onrender.com/api/v1
```

Android package: `com.rayeq.rayeq`, minimum SDK 24, target SDK 36. This pilot packaging is ARM64-only, including plugin native libraries. APK output: `build/app/outputs/flutter-apk/app-release.apk`.

The current release build type uses the local Android development certificate. It is suitable for a manually installed test build, not a production signing arrangement. Keep a separate, durable production key outside source control before store distribution or a public update commitment.

## Live path

`lib/live.dart` is the default app. `lib/api.dart` is the HTTPS/Bearer JSON client and secure session storage. Roles are fetched from `/me`, not granted by a local setting. Pending workers never fetch assignment data.

Implemented mobile routes include registration, email-code verification/resend, login/logout/session restore, password reset, live catalog, customer current/past booking lists with pagination, quote review and idempotent booking creation, assigned worker visits, forward status updates and a 30-day Cairo-time schedule.

Server-side validation, price snapshots, assignment conflicts, role checks and token verification remain the backend's responsibility. UI checks do not replace those controls.

Original design fixtures remain in `lib/main.dart` only for explicit `--dart-define=DESIGN_PREVIEW=true` builds. They are not used as fallback live data.

## Pilot state, 22 November 2026

The deployed catalog was checked with intake disabled, demo flag true, empty services/areas, no support number and InstaPay unavailable. Do not seed invented commercial prices or payment details. Email delivery is not ready yet. Registration/verification/booking end-to-end and Android installation/launch have not passed a real-device check.

Ten local automated tests pass. These include transport/session behavior and role/fixture-isolation widget checks. A successful build or signature check is not a device runtime test.

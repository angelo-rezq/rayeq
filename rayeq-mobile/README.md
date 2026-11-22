# Rayeq mobile

Flutter customer and worker app for رايق, حلاقك عندك. Android is the tested build target. The admin dashboard is a separate web app.

## Build

Toolchain used for the reviewed build: Flutter 3.50.1, Dart 3.14.0, JDK 21, Android SDK 36 and Gradle 9.5. Set ANDROID_HOME and JAVA_HOME for your own installation, then run:

```sh
flutter pub get
flutter test --dart-define=PREVIEW_FIXTURES=true
flutter analyze
flutter build apk --release --target-platform android-arm64 \
  --dart-define=API_BASE_URL=https://rayeq-platform.onrender.com/api/v1
```

Package: `com.rayeq.rayeq`. Version: `1.1.0+2`. The reviewed APK is ARM64-only, minimum Android API 24, target API 36. Native libraries use legacy extraction for compatibility. Output: `build/app/outputs/flutter-apk/app-release.apk`.

`PREVIEW_FIXTURES` defaults to false. Only pass `--dart-define=PREVIEW_FIXTURES=true` for an explicitly requested review build. The flag enables the demo barber directory and known bilingual sample labels. It does not create or delete backend records. Backend pilot cleanup must be handled separately, with owner approval.

## Signing and updates

This pilot uses the local Android development signing configuration. The signing key is deliberately not included in this source archive. Building on a new machine creates a different development certificate unless the original keystore is securely restored. That build cannot update the already installed pilot app.

Preserve the original signing key securely before relying on continued pilot updates. Do not commit a keystore or its password. Switching to a different signing certificate requires a separate migration plan; changing the key in this project alone does not upgrade existing installations.

The Android update flow checks an HTTPS download on the configured allowed host, limits the download size, verifies SHA-256, package name, exact advertised version code, a higher installed-version code, and matching signing certificates. It uses Android's package installer, including the user's unknown-source consent when required. It does not silently install. Update metadata and binaries must be published only after release approval.

Compilation, APK metadata and signing checks passed. Installation, update download and build-1-to-build-2 upgrade have not been tested on a real Android device.

## App structure

- `lib/live.dart`: authentication, customer and worker screens, bookings and schedules.
- `lib/api.dart`: HTTPS API, Bearer sessions, secure session storage and booking idempotency.
- `lib/localization.dart`: Arabic and English copy, saved locale and direction.
- `lib/profile.dart`: profile details, avatar and account actions.
- `lib/about.dart`: About, factual privacy information and text-only development credit.
- `lib/app_updates.dart`: update presentation and native bridge.
- `lib/demo_data.dart`: isolated, compile-time-gated review data.
- `android/app/src/main/kotlin/com/rayeq/rayeq/MainActivity.kt`: native APK verification and installer handoff.

Roles come from the server, not a local selector. Worker registration does not grant approval. Pending workers do not receive assigned visits. Booking requests require admin review and assignment. Worker completion does not mark a booking paid. Mobile checks do not replace backend authorization, price validation or assignment-conflict checks.

Names and other text entered by real users remain as entered. Known pilot samples and optional English backend fields have bilingual display support. The interface defaults to Arabic and supports a saved English selection.

## Verification and limits

The current local suite has 20 passing tests with review fixtures enabled. Tests cover transport/session behavior, role restrictions, fixture isolation, localization and phone-sized component layouts. Visual tests write PNGs to the system temporary directory under `rayeq-visual-review`. Set `RAYEQ_VISUAL_OUTPUT` to choose another folder.

A passing local suite is not a full live-service or real-device acceptance test. SMTP delivery, account lifecycle, production privacy/support contact, real operational data, durable key storage and Android runtime acceptance need their own release checks. The privacy screen describes implemented data handling; it does not claim legal certification or an unimplemented retention/deletion process.

See `PHOTO_CREDITS.md` for the stock-image sources and license references. The current branding is a temporary wordmark, not a finalized logo.

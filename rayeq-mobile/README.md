# Rayeq mobile

Flutter customer and worker app for رايق, حلاقك عندك. Android is the build target. The admin dashboard is a separate web app.

## Build

Toolchain used for the reviewed build: Flutter 3.50.1, Dart 3.14.0, JDK 21, Android SDK 36 and Gradle 9.5. Set ANDROID_HOME and JAVA_HOME for your own installation, then run:

```sh
flutter pub get
flutter test --dart-define=PREVIEW_FIXTURES=true
flutter analyze
flutter build apk --release --target-platform android-arm64 \
  --dart-define=API_BASE_URL=https://rayeq-platform.onrender.com/api/v1 \
  --dart-define=UPDATE_DOWNLOAD_HOST=rayeq-releases.onrender.com
```

Package: `com.rayeq.rayeq`. Version: `1.1.0+2`. The reviewed APK is ARM64-only, minimum Android API 24, target API 36. Native libraries use legacy extraction for compatibility. Output: `build/app/outputs/flutter-apk/app-release.apk`.

`PREVIEW_FIXTURES` defaults to false. Only pass `--dart-define=PREVIEW_FIXTURES=true` for an explicitly requested review build. The flag enables the demo barber directory and known bilingual sample labels. It does not create or delete backend records. Backend pilot cleanup must be handled separately, with owner approval.

## Web review index

A web build with `PREVIEW_FIXTURES=true` opens a labelled screen index with customer, worker, authentication and information/update routes. The review adapter uses local sample responses, without replacing live sessions or sending real bookings/reviews/uploads. A separate Connected app entry uses the actual API. Native Android builds do not open this index.

## Reviews and work photos

Customers can review their own completed visits once, when the backend returns `canReview=true`. Public profiles display API rating aggregates, paginated reviews and work photos. Empty ratings are not fabricated. Approved workers can choose camera or gallery, upload raw JPEG/PNG/WebP files up to 5 MiB, and delete their photos with confirmation. The backend re-encodes images and enforces its six-photo cap and upload-rate limits. Featured API profiles and nearby selection open the public profile.

## Signing and updates

This pilot uses the local Android development signing configuration. The signing key is deliberately not included in this source archive. Building on a new machine creates a different development certificate unless the original keystore is securely restored. That build cannot update the already installed pilot app.

Preserve the original signing key securely before relying on continued pilot updates. Do not commit a keystore or its password. Switching to a different signing certificate requires a separate migration plan; changing the key in this project alone does not upgrade existing installations.

The Android update flow checks an HTTPS download on the configured allowed host, limits the download size, verifies SHA-256, package name, exact advertised version code, a higher installed-version code, and matching signing certificates. It uses Android's package installer, including the user's unknown-source consent when required. It does not silently install. Update metadata and binaries must be published only after release approval.

The recovered source passes 63 automated tests. A new native build must still be compiled and inspected. Installation, update download and device upgrade have not been tested on a real Android device. The original pilot signing key was lost; a new signing identity cannot update build 1 in place. Do not publish a recovered APK as update-compatible without checking its certificate and explaining the separate-install requirement.

## App structure

- `lib/live.dart`: authentication, customer and worker screens, bookings and schedules.
- `lib/api.dart`: HTTPS API, Bearer sessions, secure session storage and booking idempotency.
- `lib/localization.dart`: Arabic and English copy, saved locale and direction.
- `lib/profile.dart`: profile details, avatar and account actions.
- `lib/nearby.dart`: tap-only approximate location lookup, manual area fallback, requested-barber selection and opted-in foreground worker availability.
- `lib/about.dart`: About, factual privacy information and text-only development credit.
- `lib/app_updates.dart`: update presentation and native bridge.
- `lib/demo_data.dart`: isolated, compile-time-gated review data.
- `android/app/src/main/kotlin/com/rayeq/rayeq/MainActivity.kt`: native APK verification and installer handoff.

Roles come from the server, not a local selector. Worker registration does not grant approval. Pending workers do not receive assigned visits. A selected available barber is booked directly only after the server returns CONFIRMED. Requests without a selected barber use management assignment. Worker completion does not mark a booking paid. Mobile checks do not replace backend authorization, price validation or assignment-conflict checks.

Names and other text entered by real users remain as entered. Known pilot samples and optional English backend fields have bilingual display support. The interface defaults to Arabic and supports a saved English selection.

## Verification and limits

The automated tests cover transport/session behavior, role restrictions, fixture isolation, localization, update grace and offline policy, explicit location permissions and zone sharing, foreground-only availability, and booking rechecks after price review. Booking forms are rendered at 320, 390 and 430px in Arabic and English. Visual tests write PNGs to the system temporary directory under `rayeq-visual-review`. Set `RAYEQ_VISUAL_OUTPUT` to choose another folder.

A passing local suite is not a full live-service or real-device acceptance test. SMTP delivery, account lifecycle, production privacy/support contact, real operational data, durable key storage and Android runtime acceptance need their own release checks. The privacy screen describes implemented data handling; it does not claim legal certification or an unimplemented retention/deletion process.

See `PHOTO_CREDITS.md` for the stock-image sources and license references. The current branding is a temporary wordmark, not a finalized logo.

## Location and typography

Customer location is requested only after tapping the location button. Coordinates are rounded to 0.01 degree before transmission. They are used transiently by the nearby/booking recheck, not stored on customer profiles or bookings. Workers can explicitly store or clear a coarse zone. Availability heartbeats contain no location, start only after opt-in, and stop outside the foreground. Manual area and typed-address routes remain available without device location. The Android app requests coarse location only, never background location.

IBM Plex Sans Arabic is bundled in four weights under its open font license, including its matching Latin glyphs. There is no runtime font download. The shared reading size is 15px, with captions and navigation no smaller than 12px before system text scaling. Filled form labels remain inside their field.

### Release configuration

The release download hostname is supplied with `--dart-define=UPDATE_DOWNLOAD_HOST=YOUR_APPROVED_STATIC_HOST`. The same define is decoded by Android Gradle into native download validation. HTTPS, no credentials, the exact allowed host and SHA256 are checked before installation; arbitrary download hosts and redirects are rejected. Version metadata always comes from the live API, not a static manifest with a frozen clock.

Version requests allow a 120-second cold-start wait. Startup uses an 8-second soft wait, then opens the app while the check continues. Failed automatic checks retry twice, one minute apart. A failed or incomplete live response never creates an offline lock. Build-2 publication uses minimum supported build 1 and a mandatory deadline exactly 48 hours after publication.

For future Google Play distribution, review a separate Play flavor and installer permission/update handling. This sideload MVP has not been validated as a Play submission. No signing key or secret is included in the repository.

Recovery note: the source was reconstructed from the archived v7 source plus the later product-code edits. It was re-checked with the complete test suite, including the screen index, reviews/gallery transports and update policy. The permitted static release host is `rayeq-releases.onrender.com`; keep `rayeq-platform.onrender.com` allowed too. Android compile/target SDK are pinned to 36. The temporary wordmark remains. A replaceable SVG splash animation is a later design task, not a completed feature in this build.

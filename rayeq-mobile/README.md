# Rayeq mobile

Flutter Android customer and worker app for رايق. Customer-facing tagline: حلاقك لحد باب بيتك / Your barber, at your door. The admin dashboard stays on the web.

## Build

Toolchain: Flutter 3.50.1, Dart 3.14.0, JDK 21, Android SDK 36, Gradle 9.5. Set JAVA_HOME and ANDROID_HOME for your installation.

```sh
flutter pub get
flutter test --dart-define=PREVIEW_FIXTURES=true
flutter analyze
flutter build apk --release --target-platform android-arm64 \
  --dart-define=API_BASE_URL=https://rayeq-platform.onrender.com/api/v1 \
  --dart-define=UPDATE_DOWNLOAD_HOST=rayeq-releases.onrender.com
```

Package `com.rayeq.rayeq`. Source version `1.1.2+4`. ARM64-only, target SDK 36. Native libraries use legacy extraction. Build 3 was approved and compiled as a signed ARM64 APK. Package, version, APK v2 signature, ZIP integrity/alignment and the retained build-2 certificate were verified. Real-device installation and upgrade remain untested.

PREVIEW_FIXTURES defaults to false. Add `--dart-define=PREVIEW_FIXTURES=true` only for the requested review build. It enables labelled demo profiles and known bilingual samples. It never deletes backend data. The web review build opens a labelled customer/worker/auth screen index with an isolated sample adapter. Native builds open the connected app, not that index.

## Signing

Release builds no longer fall back to a debug certificate. Set both private environment inputs to sign, or neither to produce an unsigned artifact:

- RAYEQ_STORE_FILE: restored PKCS12 keystore path.
- RAYEQ_STORE_PASSWORD_FILE: protected UTF-8 file holding its password.

The key alias is `rayeq`. Keep the key and password outside this repository and outside source archives. The encrypted signing backup and its password are stored separately. Never generate a new key for an ordinary update.

Build 2 uses a replacement release key. Build 3 must retain that same key to update build 2. Neither build can update build 1 in place, whose original key was lost. Verify the signed APK certificate and update compatibility before publishing. No build-3 installation or upgrade has yet been tested on an Android device.

## Public profiles, photos and biographies

Public detail, reviews and gallery load independently. A failed optional section does not discard successful profile data. Portraits use portraitUrl and fall back to a labelled work-photo thumbnail, then a placeholder. The API supplies services, prices, coverage, experience and public biography. Empty ratings are not invented. Prices exclude travel where the server says so.

Approved workers can edit public titleAr/titleEn, bioAr/bioEn, yearsExperience and specialties, and upload/delete their portrait. Uploads use raw JPEG/PNG/WebP bytes, max 5 MiB. The backend controls prices, services and coverage. Public fields must not contain a private address or personal contact information.

The separate customer account bio uses GET/PATCH profile.bio, max 1500, trimmed; an empty string clears it. It is visible to the assigned barber through authorized booking customerProfile.name/bio and to admins, not an anonymous public directory. Worker booking cards and visit details display the account bio, and label the account holder separately if their name differs from the actual visitor. The booking visitor name remains primary. Customer-facing notice explains the audience. Worker public bioAr/bioEn remain separate. The backend reports live HTTPS verification of save/trim/limit/clear and account isolation using temporary fictional accounts. Flutter transport/widget tests cover the wiring; a native-device smoke test is still required.

Profile Share opens Android's native text-summary sharing sheet. There is no public landing page, so no API URL is shared. Other preview platforms copy the summary. Heart controls persist on-device under the signed-in account. Saved loads actual public barber IDs and provides retry/removal for unavailable entries.

## Booking and location

Roles come from the server. Worker registration does not grant approval. Pending workers do not receive assigned visits. Selecting a barber is not confirmation: the backend must return CONFIRMED with that employee assignment. Requests without a selected barber use management assignment. Worker completion does not mark payment collected. Quotes and assignment availability are rechecked before booking.

Location is requested only after a tap. Coordinates are rounded to 0.01 degree, used transiently for nearby/booking rechecks, and not stored on customer profiles/bookings. Workers may explicitly store or clear a coarse zone. Availability heartbeats contain no location, require opt-in and stop outside the foreground. Manual area and address entry remain available. Android requests coarse location only, never background location.

## Branding and interface

The bundled monogram and Arabic wordmark are traced from the supplied brand sheet. Startup draws the mark, fills it and reveals the wordmark, respecting reduced-motion settings. Launcher icons and native launch background match. Arabic and English remain separate interface selections. Real users' names and entered text stay as entered.

IBM Plex Sans Arabic is bundled for interface text. Noto Sans Arabic and Jost are bundled for brand typography, without runtime downloads. See THIRD_PARTY_NOTICES.md and PHOTO_CREDITS.md. Brand SVG source files are in assets/brand.

## Updates and release checks

Update metadata comes from the live API. The app verifies an HTTPS URL on the configured download host, file-size limit, SHA-256, package name, exact advertised version code, higher build number and matching signing certificate before handing off to Android's installer. It never silently installs. Publish binaries and update metadata only after release approval.

The optional period is 48 hours from publication, followed by the required-update deadline. Offline/failed/incomplete checks do not lock users out. Startup has an 8-second soft wait while the longer live request may continue; automatic failures retry twice one minute apart.

Automated tests cover transport/session behavior, role boundaries, preview isolation, language/layout, update grace/offline behavior, booking rechecks, independent public-profile loading, editable worker fields, raw portrait upload, customer account bio save/clear and worker-only booking display, saved public profiles and native share content. Visual tests render 320, 390 and 430px app layouts in Arabic and English; screenshots are written under the temporary rayeq-visual-review folder.

A passing suite is not a real-device or full live-service acceptance test. Build-3 native compilation and static package/signature checks passed after screenshot approval. Device install/upgrade testing and native-device smoke tests of profile editing and sharing remain required. Free-tier backend cold starts can delay live responses.

## Build 4 registration response

Registration follows the server result. HTTP 202 with next:login returns to sign-in with the email kept and password/code cleared. A returned token session loads the server account; verification responses still open the code screen. No temporary verification bypass or worker approval is implemented on the device. The server owns both controls. Build 4 retains the build-2/build-3 signing certificate, and versionCode 4 supersedes 3. Native installation/upgrade is not tested on a real device.

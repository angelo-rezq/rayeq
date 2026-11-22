# Android app release metadata

## Public contract

`GET https://rayeq-platform.onrender.com/api/v1/app/version`

No login, session or database query is required. The normal API envelope applies:

```json
{
  "data": {
    "latestBuild": 1,
    "latestVersion": "1.0.0",
    "minSupportedBuild": 1,
    "apkUrl": "https://rayeq-platform.onrender.com/download/rayeq-pilot-arm64-1.0.0.apk",
    "sha256": "a895f9efecd4548da693b34b8fb32b9a42a4045fadec24d95a7566a682335091",
    "releaseNotesAr": "النسخة التجريبية الأولى. للاختبار فقط، وليست لإرسال زيارات حقيقية."
  }
}
```

- `latestBuild`: Android `versionCode`, an integer. Compare numbers, not version strings.
- `latestVersion`: Android `versionName`, for display.
- `minSupportedBuild`: lowest supported Android build. It must not exceed `latestBuild`. Raising it is an explicit release decision, not an automatic part of publishing an APK.
- `apkUrl`: HTTPS download on this Rayeq service, without query or fragment.
- `sha256`: lowercase SHA-256 of the exact APK bytes.
- `releaseNotesAr`: plain Arabic text, not HTML or executable content.

The response sends `Cache-Control: no-store`, `CDN-Cache-Control: no-store`, `Surrogate-Control: no-store`, `Pragma: no-cache` and `Expires: 0`. The route is dynamic. The metadata is read from the deployed config, not a mutable shared cache. Render Free cold starts can delay the response, so the client should have a timeout and retry option.

## Publish a new APK

The release bump point is `config/app-release.json`, tracked in this private repository. No paid service or extra database is used.

1. Build the APK with a higher Android `versionCode`. Preserve the installed app's application ID and signing key. Verify `versionName`, `versionCode`, signing certificate and supported architecture from the built APK, not its filename alone.
2. Copy it into `public/download/` using a new filename for every build, for example `rayeq-arm64-1.0.1-build2.apk`. Never overwrite an existing APK URL: APK responses are cacheable and immutable.
3. Compute the file's SHA-256 with `sha256sum`. Update all release fields in `config/app-release.json`. Keep `minSupportedBuild` unchanged unless a forced update is intended. Use the exact new HTTPS URL under `/download/`.
4. Run `npm run typecheck` and `npm run build`. The build runs `npm run verify:release` first. It validates metadata, checks the hosted APK file exists locally, checks ZIP magic, enforces this service's configured origin and verifies the exact SHA-256. Native app version/signing verification is still the publisher's responsibility.
5. Commit the APK and metadata together, then deploy. This keeps the download and metadata in the same release. Leave prior APKs available for rollback. A release must never advertise an APK before it is hosted.
6. After deploy, fetch the public version endpoint without auth. Download the exact returned `apkUrl` and independently compare its SHA-256 with the returned `sha256`. Test an upgrade over the previous installed APK on Android before announcing release.

The default expected origin is `https://rayeq-platform.onrender.com`; `PUBLIC_ORIGIN` or `RENDER_EXTERNAL_URL` sets the expected origin during build if the service moves.

## Client behavior

The Flutter client can check on launch/resume and from an explicit "check for updates" action. Do not poll constantly. Handle offline, timeout, non-200, malformed metadata, mismatched hashes and interrupted downloads without losing the user's session or data.

If installed build is below `latestBuild`, offer the update and show the release notes. If it is below `minSupportedBuild`, show a clear required-update state with a retry/download path. If the version endpoint is unavailable, the client must not invent a forced-update requirement. This minimum is a client policy signal, not server-side API enforcement.

Download only from an approved HTTPS Rayeq origin and compare SHA-256 before handing the APK to Android's installer. SHA-256 checks integrity against the metadata; Android's signing-certificate verification remains essential. Android must show its normal installation consent. This endpoint does not permit silent installs or bypassing Android security settings.

The old build 1 has no updater UI. Users with that build need one installation of a newer updater-enabled APK before future in-app checks can work. Web preview metadata checks do not prove native APK installation or upgrade compatibility.

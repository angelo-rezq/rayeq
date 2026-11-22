# Rayeq Google Play preparation

Checked: 22 November 2026. This is a preparation checklist, not confirmation that the app is ready for Google Play. No Play Console login or account-state check was performed.

## Recommended release paths

- Keep the sideload MVP and the Play distribution path separate. The sideload APK installer must not be shipped as a Play self-updater.
- Continue using the existing Render backend and dedicated Rayeq Neon database. The separate static release host avoids a sleeping Node process for APK downloads; it does not make API requests always-on.
- Keep the dynamic version API authoritative for fresh server time. A static download manifest is useful for downloads, but must not pretend to provide a fresh server clock.

## Before a Play upload

| Area | Work required |
| --- | --- |
| Android target | New phone apps and updates must target Android 16 / API 36 under the current policy. Check the built artifact, not only the Gradle file. A target SDK is not the minimum supported Android version. |
| Upload artifact | Build a signed Android App Bundle (.aab). New Play apps use App Bundles and Play App Signing. A sideload APK alone is not the upload deliverable. |
| Signing | Use a release certificate, not Android Debug. Securely back up the signing material and its access instructions outside GitHub and chat. Decide signing continuity before distributing a replacement for an already-installed app. A different certificate normally cannot update the existing installation. |
| Play updater | Remove REQUEST_INSTALL_PACKAGES and the direct APK self-update path from the Play build. Use Google's update mechanism. Keep distribution-channel version policy separate where necessary. |
| Account deletion | Provide an obvious in-app deletion-request path and a working external deletion-request resource that names the app. Linking from the app to that real web request flow is an allowed approach. Merely disabling an account is not deletion. |
| Privacy | Prepare a standard, active, publicly accessible, non-geofenced webpage, not a PDF. Include the app/operator identity, privacy contact, data use/sharing, security, retention and deletion practices. Make it accessible in the app and in the listing. Obtain the operator/contact/retention decisions before publishing it. |
| Data safety | Audit actual app and SDK behavior. Potential categories to inspect include name, email, phone, profile photos, booking/address information, reviews, work photos, location and diagnostics. Do not preselect form answers from this list without checking the final implementation. |
| Location | Off-device ephemeral processing still belongs in the form answers. Qualifying ephemeral use may be omitted from the customer-facing label. Determine the actual precision from the final code and Google's definitions, rather than assuming a UI label such as approximate settles it. |
| App access | Prepare reliable reviewer access to customer and worker features. Resolve OTP delivery, account activation and any reviewer instructions before review. Do not give reviewers private production customer data. |
| Store declarations | Complete app access, ads, content rating, target audience, Data safety and other applicable Console declarations using actual app behavior. |
| Device tests | Test installation, customer and worker flows, permissions, slow/cold API startup, gallery uploads, reviews, updates and failure cases on Android devices. A mobile web preview is not a native install test. |

## Listing assets

- App icon: 512 x 512, 32-bit PNG with alpha, at most 1024 KB.
- Feature graphic: 1024 x 500, JPEG or 24-bit PNG without alpha.
- Short description: at most 80 characters.
- Provide at least two screenshots. Google permits up to eight per supported device type. Screenshots must meet the published format and dimension rules: JPEG or 24-bit PNG without alpha, minimum dimension 320 px, maximum dimension 3840 px, and the longer dimension no more than twice the shorter dimension.
- The 390 x 844 screenshots used for design review do not meet that last ratio rule. Capture separate store-ready images rather than stretching them. Four portrait screenshots at 1080 x 1920 or higher following the recommendation criteria are a useful target, not a claim that four are the basic upload minimum.
- Use genuine app screens, accurate descriptions and clearly fictional sample data. Do not advertise features that have not passed native testing.

## Closed testing

For personal developer accounts created after 13 November 2023, Google requires at least 12 testers continuously opted in for the preceding 14 days before applying for production access. Completing that interval does not itself grant production access. Google also asks about the testing and production readiness. Account type, creation date and actual eligibility remain unverified here.

## Hosting boundaries

Render documents a 15-minute idle spin-down for Free web services and about a minute to wake. Static sites are served separately and are free to deploy, but still use workspace bandwidth and pipeline quotas. Quota exhaustion is not unlimited free hosting. With no payment method, the documented fallback is suspension of Free services or disabled builds rather than supplementary billing. A later payment-method or plan change can change that billing risk.

Neon's Free compute can also sleep after five idle minutes. Its documented wake is much shorter than the Render web-service wake. Client timeout/retry handling remains necessary.

No backend migration, Vercel deployment or Netlify deployment is part of this plan.

## Sources

Official sources read on 22 November 2026:

1. Target API policy: https://support.google.com/googleplay/android-developer/answer/11926878?hl=en
2. New-personal-account testing: https://support.google.com/googleplay/android-developer/answer/14151465?hl=en
3. App Bundles: https://developer.android.com/guide/app-bundle
4. Upload preparation: https://developer.android.com/studio/publish/upload-bundle
5. App signing and debug-certificate limits: https://developer.android.com/studio/publish/app-signing
6. Install-package permission: https://support.google.com/googleplay/android-developer/answer/12085295
7. Play self-update restriction: https://support.google.com/googleplay/android-developer/answer/16559646?hl=en
8. Account deletion: https://support.google.com/googleplay/android-developer/answer/13327111?hl=en
9. Data safety and ephemeral processing: https://support.google.com/googleplay/android-developer/answer/10787469
10. User data and privacy policy: https://support.google.com/googleplay/android-developer/answer/10144311?hl=en
11. Listing assets and screenshots: https://support.google.com/googleplay/android-developer/answer/9866151
12. Review preparation: https://support.google.com/googleplay/android-developer/answer/9859455
13. Render Free limits: https://render.com/docs/free
14. Render static sites: https://render.com/docs/static-sites
15. Neon compute sleep: https://neon.com/docs/introduction/scale-to-zero

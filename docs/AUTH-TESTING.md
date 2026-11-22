# Temporary registration without email

This is for the current closed Rayeq pilot, not a production authentication policy.

## Switch

`rayeq_settings.key = 'auth:emailVerificationBypass'` contains:

```json
{"enabled":true,"expiresAt":"an explicit ISO timestamp"}
```

No row, false, an invalid/missing expiry, an expired timestamp, configured email, or real `config.intakeEnabled=true` all mean OFF. Email readiness uses the same required Mailjet or SMTP environment fields as normal sending. The code ships OFF. Enable only with owner approval and an explicit pilot expiry.

A maximum of 100 separately flagged accounts can be created. Existing IP/email rate limits remain. Duplicate registration does not change an existing account, password, role, or verification state.

New accounts have `email_verified=false` and `email_verification_bypassed=true`. Registration returns HTTP 202 with `next:"login"`, `testingOnly:true`, the expiry, and an Arabic instruction to log in with the chosen password. No session or fake verification code is returned. Normal password checks are required. Workers start as `worker_pending`, with no worker booking access, until an admin explicitly approves and links them to an active qualified employee. The admin list labels these as unverified test accounts. Public worker discovery still requires real email verification, so approval alone does not put an unverified test worker into discovery.

The setting is checked at login and on every authenticated request for unverified test accounts. Turning it off or configuring email blocks their unverified access, including existing sessions. Once email works they can request a real code through the normal resend flow, verify, and log in normally. Verification clears the bypass flag. No email ownership is claimed by testing mode.

Real booking intake and the existing demo-customer allowlist are unchanged. Newly registered customers are not added to that allowlist and cannot submit real visits. No existing admin/demo user is changed.

## Current APK 3 limitation

The installed APK's register handler always opens the verification screen, even when the API returns `next:"login"`. After registering, tap **رجوع للدخول** and log in with the email and password just chosen. Do not enter an invented code. A later Flutter build should consume the registration response and go directly to password login.

## Turn off

Update the dedicated Rayeq database only:

```sql
UPDATE rayeq_settings
SET value = jsonb_set(value, '{enabled}', 'false'::jsonb)
WHERE key = 'auth:emailVerificationBypass';
```

Deleting that one setting also turns it off. Do not delete user accounts as a revert. Verify `/api/v1/health` reports `emailVerificationBypassActive:false` and that an unverified testing session is refused. Configuring the email environment fields ignores the switch automatically; clear it explicitly too before launch. Do not open real intake before the existing launch gates pass.

## Checks

`node --env-file=.env.local --import tsx scripts/isolated-test.ts auth-bypass-test permission-test`

The new suite covers default-off failure, no account creation on failure, customer and worker testing signup, truthful verification state, password enforcement, strict OTP, pending-worker isolation/approval, protection of existing users/admins, immediate session cutoff, expiry, configured-email/real-intake auto-disable, and the global cap. These run only in isolated disposable schemas.

## Risk

Email ownership is unproven, so someone can claim another person's address. Keep this testing-only, keep real visits closed, and require real email verification before launch.

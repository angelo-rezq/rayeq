# Rayeq / رايق
Private Arabic-first operations dashboard and JSON API for a company-managed grooming pilot in Minya.

## Run
Node 22+. `npm ci`, configure `.env.local` from `.env.example`, then `npm run dev`.
Production: `npm run build`, then `npm start`. The startup migration touches only `rayeq_` tables in the configured dedicated database.

## Admin
Set `ADMIN_EMAIL` and a strong `BOOTSTRAP_TOKEN` in server environment. Visit `/setup`, enter the token and a new password. Bootstrap can create only the first admin. Remove `BOOTSTRAP_TOKEN` after successful setup. Login is at `/dashboard` with HttpOnly, SameSite=Strict cookie sessions. Native mobile uses the same login response's Bearer token. Sessions are hashed in Postgres and expire in 7 days. Passwords use scrypt with per-user salt.

## Launch gate
No invented catalog is seeded. Intake defaults off. Add approved services, areas, employees, and optional verified support/transfer instructions. Configure SMTP and test delivery before enabling intake. SMTP is vendor-neutral and can switch to Mailjet through environment variables alone. No SMTP means registration fails closed with 503. No verification codes or passwords are echoed or logged. `RAYEQ_TEST_MODE=1` is for isolated automated tests only, never production. It writes test email codes to a mode-0600 temporary test mailbox.

Worker registration creates `worker_pending`, not worker privilege. Admin must link a verified applicant to an active employee with skills and areas. Approval revokes existing sessions. Workers see only assigned work and progress one state at a time after admin confirmation. Marking complete never marks payment paid. Only admin records collection. Payroll is separate from booking revenue.

## Pilot rules, not settled company policy
Customer cancellation is free only for PENDING or UNDER_REVIEW requests. Later cancellation requires admin support. Requested booking times are not guaranteed availability. Admin confirms assignment and time. Overlap prevention serializes on each employee and checks full time intervals plus a provisional 15-minute travel buffer. This is fixed-buffer dispatch protection, not route-aware scheduling or full shift planning. No automated employee GPS tracking.

## API
Prefix `/api/v1`, JSON `{data:...}` and `{error:{code,message,fields}}`. See `docs/API-CONTRACT.md`. Added `/auth/reset-password` with `{email,code,password}`; it revokes all account sessions. Admin endpoints are implemented in `lib/api.ts`. Integer money is EGP piastres throughout. Catalog/version changes require re-quote. Idempotency keys are scoped to user and exact validated payload.

## Checks
`npm run typecheck`, `npm run build`, `npm run test:permissions`. The permission suite creates temporary records on the configured dedicated database and removes them. Run only before launch or against an isolated test database because it temporarily opens intake for fixtures. It tests role restrictions, ownership, worker assignment, forward transitions, verification/replay, session revocation, server prices and parallel overlapping assignments.

## Deployment
Private GitHub repo, Render Free Node service, Frankfurt, build `npm ci && npm run build`, start `npm start`. Neon Free database is separate from every unrelated project. Free Render services may sleep, leading to a slow first request. No guaranteed uptime is claimed for the pilot.

## Data protection and recovery
All SQL is parameterized. Server owns roles and financial fields. Public catalog excludes private records. Mutations use DB-backed limits and audit trails. No secrets are committed. Neon currently shows 6-hour restore history on this Free project; arrange independent encrypted exports before live business use. No backup automation is claimed. Advanced discounts, reviews, push notifications, saved-address management, route optimization and full shift scheduling are outside today's slice.

### Render Free email transport
Render Free blocks SMTP ports 25/465/587. Set `MAILJET_API_KEY`, `MAILJET_SECRET_KEY`, and `MAIL_FROM` for HTTPS delivery on this host. The sender must already be validated and active in Mailjet. The HTTP adapter checks both HTTP success and Mailjet's per-message success response. SMTP remains available for other hosts, but is not the Render Free production path. References: https://render.com/docs/free and https://dev.mailjet.com/email/guides/send-api-v31/ .

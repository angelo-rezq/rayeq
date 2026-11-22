# Minya managed grooming platform

## Product specification and decision record

### Confirmed by owner, 22 November 2026
- Managed company employees, not a barber marketplace. Admin dispatches staff by phone/WhatsApp; no employee accounts in v1.
- Home/workplace visits in Old Minya and New Minya. Configurable service areas and employee service qualifications.
- Cash or InstaPay to COMPANY accounts only. No gateway, wallet or automated transfer verification.
- Employees receive monthly salaries. Payroll separate from service revenue; incentive details undecided.
- Arabic-first RTL mobile experience. Placeholder brand, no name/logo decided.
- Colors: charcoal #191919, ivory #F4F0E8, copper #B77A52, stone #77736E.
- Email account verification, NOT phone verification. Phone required as booking contact only. Never email a reusable password; use confirmation/magic link.
- Same-day target: live functional vertical slice for owner testing by 19:00 Africa/Cairo, 22 Nov 2026. Catalog, persisted booking intake, protected admin booking list, service/price/area editing.
- Owner plans market testing with strangers. Public intake must not ship without verified email, rate limits, access control and real persistence.
- Free tiers; do not use existing Vercel account. Private fresh repository, separate deploy key and database project. Do not alter other projects.

### Stack decision (engineering recommendation, owner delegated choice)
Next.js + TypeScript + Tailwind-capable CSS, Supabase/PostgreSQL + Supabase Auth, Render host.
Reason for replacing MongoDB/Mongoose: relational service/area/staff/payment records, transactional booking writes, RLS, and later interval exclusion constraints for staff assignments. Next handlers stay stateless and portable to serverless; no permanent websocket or in-memory source of truth. Render is chosen for today's free preview and existing owner hosting preference. Check current limitations before public deployment; no paid upgrade without approval.
Sources inspected: https://supabase.com/docs/guides/auth/phone-login ; https://supabase.com/docs/guides/database/postgres/row-level-security ; https://vercel.com/legal/terms .

### Public-release blockers / open business decisions
1. Real email sender. Supabase default SMTP only sends to organization team addresses, currently two messages/hour, not market-test scale. Source: https://supabase.com/docs/guides/auth/auth-smtp . Mailjet review pending per project coordinator. Keep confirmation ON; no fake verification.
2. Owner-approved service names/prices/durations, travel fees, hours, cancellation rules, actual company transfer details. Current UI fixture prices are illustrative, visibly labeled. Do not silently publish as approved rates.
3. Staff assignment and availability: requested times are not confirmed slots. Every incoming request is PENDING until admin review. Do not promise instant service or fake capacity.
4. Privacy/support identity and retention policy before broad public use.

### Today's acceptance criteria
- Arabic mobile catalog at 320/390px without horizontal overflow.
- Confirmed email account creates a booking with required contact phone, home/work address, service, area and requested date/time.
- Server obtains prices from live catalog, stores immutable service/area/price snapshots; client totals never trusted.
- Retry idempotency prevents duplicate booking creation; shared persistent rate limit; no localStorage/in-memory database.
- Non-admin cannot read another customer's booking or mutate services/areas/status. Unverified users cannot create bookings.
- Admin can read real incoming bookings, edit service prices/descriptions/active status and areas, and progress or cancel requests with audit history.
- InstaPay payment starts UNPAID / awaiting manual verification. Customer reference is a claim, not proof of money received.
- Booking state and financial/payment state remain separate.
- Tests: unauthorized/forbidden, malformed payload, stale/disabled catalog, duplicate retry, price tampering, persistence across reloads, email confirmation round trip.

### Roadmap after today's slice
Qualified employee profiles/skills/shifts, atomic interval-reserving assignment with travel buffers, full state graph, customer history and cancellation policy, monthly payroll ledger and collection reconciliation, notification outbox/retries, backup/restore test, accessibility and security review, PWA installation testing, APK decision only after scope is explicit. No unsupported store-price or publication-time promises.

### Engineering guardrails
- Unique(employee,start) does NOT prevent overlapping appointments with different starts. Use time intervals + database exclusion constraint or serialized reservation transaction.
- No arbitrary backwards status changes. Corrections are explicit audited actions with guards, never replayed notifications or charges.
- No automatic completion or payment verification by cron.
- Admin membership server/database-managed, never user-editable metadata.
- No service-role secret in browser; secrets excluded from git, exports and logs.
- Cache only public assets/catalog. Never service-worker-cache customer or admin API responses.

## Progress
- UI foundation coded; next build succeeds with zero reported npm audit vulnerabilities at initial install.
- Captured and inspected mobile home/services/booking screens and desktop admin empty state. Sent to owner via coordinator for visual review.
- Booking forms are currently visual only and visibly labeled. Persistence, authentication and deployed URL are not yet complete.

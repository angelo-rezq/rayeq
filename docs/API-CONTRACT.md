# Rayeq mobile/backend contract v1

Owner scope: Flutter Android app TODAY, customer + worker; admin dashboard remains web. Brand رايق, tagline حلاقك عندك. Cash/InstaPay only; no gateway. API prefix `/api/v1`. Use JSON UTF-8. IDs are strings. Money is INTEGER EGP piastres (18000 = EGP 180), never floating point.

This is a proposed stable wire contract so Flutter and backend can proceed independently. Backend owner may adjust a field before wiring, but report differences through coordinator. Source code has visual fixtures only; do NOT treat sample prices/services as owner-approved commercial data.

## Transport and errors
- HTTPS only in deployed APK. Base URL supplied by Flutter build `--dart-define=API_BASE_URL=https://...`.
- Mobile uses `Authorization: Bearer <sessionToken>`, stored with flutter_secure_storage, not plain preferences. Backend issues a cryptographically random opaque session token (hash in DB) or a properly validated signed session. The backend agent owns implementation and revocation. Never trust a submitted user ID or role.
- Auth token expires/revokes; GET me validates server-side. 401 clears mobile session.
- Envelope success `{ "data": ... }`; errors `{ "error": { "code":"...", "message":"Arabic safe user message", "fields":{} } }`.
- HTTP 400 validation; 401 unauthenticated; 403 forbidden/unverified; 409 stale price/invalid transition/conflict; 429 rate limit with Retry-After; 503 dependency unavailable. No SQL/provider secrets in errors.
- Persisted per-identity/IP rate limits. Auth resend cooldown returned by server, NOT only a mobile timer.
- For booking creation client passes a fresh UUID `Idempotency-Key` header; reuse it only on retry of identical payload.

## Auth, email-code verification, and roles
Phone is never verification identity. Do not send reusable passwords in email. Customer and worker both email-verify. Role intent does not grant privilege. Use provider-backed verification codes or equivalent verified backend flow, never echo a code in API output/logs.

POST `/auth/register`
Request: `{name,email,password,accountType:"customer"|"worker"}`
Response 202 data: `{ next:"verify_email", email, resendAfterSeconds:60 }`.
Worker intent becomes `worker_pending` after email verification. No assigned bookings or PII before administrator approval.

POST `/auth/verify-email`
Request `{email,code}`
Response data: `{token, expiresAt, user:{id,name,email,emailVerified:true,role:"customer"|"worker_pending"|"worker"|"admin"}}`.
If provider cannot issue a session after verifying, return `next:"login"` and Flutter logs in afterwards. Tell coordinator which before integration.

POST `/auth/resend-verification` request `{email}` response 202 `{resendAfterSeconds}`. Avoid account enumeration.
POST `/auth/login` request `{email,password}` response same session shape. Unverified login returns error `EMAIL_NOT_VERIFIED` with safe resend route, no privileged session.
POST `/auth/logout` revokes current token, returns 204.
GET `/me` returns data `{id,name,email,emailVerified,role}`; role always loaded from trusted server state.
POST `/auth/forgot-password` request `{email}` generic 202. If not in today's slice, explicitly report and disable UI action, do not fake send.

## Public catalog and configuration
GET `/catalog`
Response data `{brand:{nameAr:"رايق",nameEn:"Rayeq",taglineAr:"حلاقك عندك"},currency:"EGP",timezone:"Africa/Cairo",intakeEnabled:boolean,services:[{id,nameAr,descriptionAr,category,durationMinutes,priceMinor,version,active}],areas:[{id,nameAr,travelFeeMinor,version,active}],support:{phone?:string,whatsapp?:string}}`.
Only active public rows. Server may set `isDemo:true` on configured test catalog; app shows test notice. Do not publish invented contact/company transfer numbers.

## Customer booking
POST `/quotes` (authenticated, verified)
Request `{serviceId,areaId}`
Response `{serviceId,areaId,serviceNameAr,durationMinutes,servicePriceMinor,travelFeeMinor,discountMinor:0,totalMinor,serviceVersion,areaVersion,currency:"EGP",expiresAt}`. No discounts engine needed today. Versions submitted to booking, server recalculates and rejects stale versions (409 PRICE_CHANGED) to avoid silent price change.

POST `/bookings`
Request `{serviceId,areaId,serviceVersion,areaVersion,customerName,contactPhone,locationType:"home"|"work",address:{street,building,floor?,apartment?,workplaceName?,directions?},bookingType:"scheduled"|"immediate",localDate?:"YYYY-MM-DD",localTime?:"HH:mm",timezone:"Africa/Cairo",paymentMethod:"cash"|"instapay",consent:true}`.
Server validates all fields, active service/area, future requested time, and required workplaceName for work. Server uses Cairo IANA timezone to convert local date/time. No fake capacity: requested times remain PENDING, not guaranteed slots. For immediate, no invented ETA. Snapshot prices/address/service names at insert. Payment always UNPAID on create. No company transfer destination configured means show unavailable instructions, not a fabricated number.
Response 201 data Booking:
`{id,reference,status:"PENDING",service:{id,nameAr,durationMinutes},area:{id,nameAr},customerName,contactPhone,locationType,address,bookingType,requestedAt:string|null,timezone:"Africa/Cairo",price:{serviceMinor,travelMinor,discountMinor,totalMinor,currency:"EGP"},payment:{method,status:"UNPAID"|"PENDING_REVIEW"|"PAID",collectedMinor},assignedWorker?:{id,name},createdAt,updatedAt,history:[{status,at}],version}`.

GET `/bookings?scope=current|past&limit=20&cursor=...` returns only customer's own: `{items:Booking[],nextCursor:null|string}`.
GET `/bookings/:id` only owner, assigned approved worker, or admin with role-appropriate fields. Never include internal notes, salary or private staff contact to customer.
POST `/bookings/:id/cancel` request `{reason,version}`. Since cancellation policy not owner-approved, either allow only PENDING/UNDER_REVIEW pre-dispatch without charge or return `CANCELLATION_REQUIRES_SUPPORT` for other states and expose grounded support route. Backend must state chosen provisional test rule visibly; no invented fee.

## Worker interface
GET `/worker/bookings?scope=current|past&limit=20&cursor=...` approved worker only, and only rows assigned to token's worker identity. Same Booking shape, limited to required contact/address/service; no company-wide financial data.
GET `/worker/schedule?from=YYYY-MM-DD&to=YYYY-MM-DD` returns `{items:[{bookingId,reference,startAt,endAt?,serviceNameAr,areaNameAr,status}]}` for self only.
PATCH `/worker/bookings/:id/status` request `{status,version}`.
Allowed forward-only: CONFIRMED -> ON_THE_WAY -> ARRIVED -> IN_PROGRESS -> COMPLETED. Worker cannot assign/reassign, change customer price, approve their own role or mark payment PAID. COMPLETED does not automatically imply PAID. Version/conflict guards, audit actor/time on every change.
Worker pending GET `/me` works; all worker data endpoints return 403 `WORKER_APPROVAL_PENDING`.

## Admin responsibilities owned by backend task
Web dashboard with protected admin login. Read incoming bookings, edit services/prices/areas and intake switch, approve/reject worker applications, map worker to skill qualifications and areas before assignment. Assignment must be exclusive and safe on overlapping intervals (not unique start timestamp alone), or explicitly limit today's slice to manual requests without claiming concurrency solved. Status transitions and payment collections audited. Employee monthly salary records are separate from revenue, no salary display to worker until permission/policy decided. No unauthenticated admin preview containing real data.

## Cross-platform auth caution
Flutter native is not a browser. Do not deliver cookie-only auth and assume it works as bearer. Agree session contract and confirm API auth from a real HTTP client before handoff. Test malicious role request, another-customer ID, other-worker assignment ID, replayed booking POST, edited client price, stale service version and unverified account booking denial.

## Current integration state
No endpoint is connected yet. No API base URL or token embedded in app. Current Flutter screens navigate between visual fixtures only and say so in booking/worker data. Backend completion and email verification end-to-end remain required before public market testing.

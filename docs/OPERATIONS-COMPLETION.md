# Operations completion, November 2026

## Admin dashboard

- Services and areas: create/edit/activate/deactivate. Delete only when unused by staff and bookings. Demo-manifest records are protected. Service image URL supports HTTPS links; it is not a binary uploader.
- Staff: employee record CRUD with guarded deletion. A linked account, booking, payroll record or photo blocks deletion; deactivate instead. Public bio, portrait and specialties remain editable.
- Admin-created worker login: explicitly confirmed staff identity, new email only, qualified active employee only. It never overwrites another user or grants admin privileges. `staff_managed_login=true` is a separate access basis. `email_verified` remains false. A managed worker can sign in while active even without email delivery. Admin can reset only a managed worker password, revoking sessions. Self-registered accounts keep email recovery. No password is returned, logged or put in audit details. Demo identities cannot be provisioned/reset.
- Admin booking entry: search an existing customer, select active service/area, requested date/time, address and cash payment. Requires confirmation of customer consent. It uses current server prices and the existing intake/demo restrictions. It does not create a guest identity or override closed intake. Assign staff in the booking detail.
- Payroll: edit buttons prefill the existing employee/month record. Saving updates that same month. Records are not deleted, and paid is bookkeeping, not a transfer.
- Portfolio: admin upload on behalf of an active approved worker, same image processing/storage limits as worker upload. Delete remains available. To replace, delete and upload. Portraits are separate.
- Reviews: hide/restore, never rewrite customer ratings or invent reviews.
- Bookings and audit history: retain records. Cancellation is not deletion. Audit is read-only. No arbitrary edit of historical prices or customer details.

## Mobile contracts

All paths below are under `/api/v1`, use the existing Bearer session, and keep `{data:...}` / `{error:{code,message,fields}}` envelopes.

### Saved addresses

Customer-only `GET /addresses` returns `{items:[Address]}`. `POST /addresses` takes `{label,locationType,address}` and returns Address (201). `PATCH /addresses/:id` takes the full same payload plus `version`, returns Address. `DELETE /addresses/:id` takes JSON `{version}` and returns 204. Address is `{id,label,locationType,address,version,updatedAt}`. Address fields: required street/building; optional floor/apartment/workplaceName/directions. Work addresses require workplaceName. Limit20, owner-scoped, stale edits409 and other owners404.

`POST /bookings` accepts `addressId` instead of address+locationType. Do not combine them. Address contents are copied into the booking and remain unchanged by later address edits/deletion. All other booking fields and idempotency requirements stay.

### Cancellation, support and payment

Booking DTO adds `cancellation:{canCancel,requiresSupport,feeMinor:0,policyAr}`. Existing `POST /bookings/:id/cancel` takes `{version,reason}`. Only the owning customer can self-cancel PENDING/UNDER_REVIEW. No new fee or paid cancellation service.

`GET /catalog` includes support phone/WhatsApp and InstaPay instructions from admin settings, plus `scheduling:{mode:'requested_time',timezone:'Africa/Cairo',guaranteedSlots:false}`. No unapproved working hours or guaranteed slots. Assignment still checks worker conflicts with15minute travel buffer.

Customer/admin `GET /bookings/:id` adds `paymentSummary:{totalMinor,collectedMinor,remainingMinor,currency:'EGP',instapayInstructions,support}`. This never proves a bank transfer was received; admin records collection.

### Worker privacy

Worker DTOs omit price, payment and paymentSummary, not fake zeros. `visibility:{financialsVisible:false,addressReleased,addressReleaseState:'assigned'|'withheld',addressReleasePolicy:'assigned_active_booking_only'}`. Address/contactPhone/customerLocation/customerProfile are released only for that worker's assigned active booking in ASSIGNED/CONFIRMED/ON_THE_WAY/ARRIVED/IN_PROGRESS. They are absent for terminal records. Nonfinancial schedule remains unchanged. Reassignment removes previous worker access.

### Refresh and auth retry

Use existing list/detail/schedule GETs on pull-to-refresh and app resume. No push notification service/account or promise was added.

Successful resend returns202 with data.resendAfterSeconds60 and Retry-After60. All429 responses include Retry-After and error.resendAfterSeconds matching the available wait. Existing error code/fields remain.

## Limits and release gates

Free Render/Neon setup unchanged. Closed real intake, demo allowlist/data, registration-test expiry and old build1 update metadata are preserved. Build4 APK remains hosted independently. New mobile UI needs a Flutter build; backend changes do not prove Android-device installation. Mail delivery, business catalog/staff/support details, full real-device test and separately approved demo wipe remain launch gates. No guarantee that free hosting carries a year of production service uninterrupted.

## Verification

`node --env-file=.env.local --import tsx scripts/isolated-test.ts operations-test` runs52 operation/mobile checks in a temporary isolated schema. Regression suites: permission61, bypass33, bilingual catalog24, profile30, nearby51, reviews44, gallery60, public barber profile74. Prior privacy assertions were intentionally updated to require removal after completion and absence of worker finances. Production build/typecheck also required. Inspect desktop and phone UI pixels before release.

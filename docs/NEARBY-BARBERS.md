# Nearby barbers, without a map

Authenticated, verified customers use `POST /api/v1/barbers/nearby`.

Location search:

```json
{"latitude":28.0871,"longitude":30.7618,"serviceId":"service UUID","areaId":"optional area UUID","requestedAt":"optional ISO-8601 time with UTC offset"}
```

If location permission is denied, omit both coordinates and provide `serviceId` and `areaId`. Do not supply only one coordinate. `requestedAt` defaults to now and may be at most 60 days ahead. Scheduled booking submit still uses the existing Cairo `localDate` and `localTime` fields.

The normal `{data: ...}` response contains:

- `mode`: `location` or `area`.
- `barbers`: at most 30 entries, each with `id`, `nameAr`, `nameEn`, `availabilityStatus` (`available`), `availabilityUpdatedAt`, and `approximateDistance`.
- `approximateDistance`: `{minKm,maxKm}` in 2-km bands, or null for area-only search. It is not an ETA or a promise of travel time.
- `checkedAt`, `requestedAt`, `availabilityFreshForMinutes` (15), `locationMaxAgeHours` (24), `radiusKm` (20 for location, null for area), `selectionIsReservation` (false).
- Empty results also have `emptyReason: NO_AVAILABLE_BARBERS` and `canUseAreaFallback`.

Only active employees linked to verified, approved worker accounts are eligible. The employee must be qualified for the service and selected area, available within the last 15 minutes, and have no conflicting booking, including the normal 15-minute travel buffer. Active in-transit/on-site/in-progress work also blocks immediate availability even if its planned end has passed. Location search requires a coarse zone updated within 24 hours. Area-only fallback does not require a zone and does not invent a distance.

## Worker opt-in

`GET /api/v1/worker/availability` returns `availabilityStatus`, `effectiveAvailabilityStatus`, `isFresh`, `availabilityUpdatedAt`, `locationUpdatedAt`, `hasCoarseZone`, and `freshForMinutes`.

`PATCH /api/v1/worker/availability` accepts:

```json
{"availabilityStatus":"available","location":{"latitude":28.0871,"longitude":30.7618}}
```

Status is `offline`, `available`, or `busy`. An omitted location preserves the saved zone; explicit null clears it. Only the worker's own active employee record is changed. Exact coordinates are rounded to 0.01 degree before persistence, with numeric(5,2) storage as a second precision limit. These are coarse zones, not street addresses or real-time tracks. No coordinates are returned by the worker availability or customer directory responses. To remain listed, refresh status while the worker has chosen to be available. A five-minute foreground heartbeat leaves room inside the 15-minute freshness limit. Going offline stops listing immediately.

Customer search coordinates are used only during that request and are not saved to bookings or audit details. API request bodies must not be added to application logs. The directory never exposes employee phone, email, salary, user ID, street address or coordinates. The separate question of customer-address visibility in already assigned worker bookings is unchanged by this feature.

## Selection and booking-time recheck

The existing booking POST accepts optional `preferredBarberId` and optional `customerLocation: {latitude,longitude}`. Include the location used to search if permission was granted; without it the server rechecks qualification/availability within the selected area.

Immediately before creating the booking, the server rechecks current eligibility and conflicts. If the chosen barber is no longer eligible, it returns HTTP 409 with `BARBER_UNAVAILABLE`. Refresh the list or let the customer submit without a preference. Keep normal service/area version checks and the idempotency key.

A selected-barber booking that passes the submit-time recheck is inserted as `CONFIRMED` with the employee, start and end times in the same transaction. The employee row lock serializes competing customer selections and existing admin assignments. The booking becomes visible to that barber immediately, with no separate admin or barber acceptance step. Availability still must be fresh in normal mode. Search itself is not a reservation.

The response adds `assignmentMode: CUSTOMER_SELECTED`, `requiresAdminApproval: false`, `isAssigned: true`, `startAt`, `endAt`, and `assignedWorker: {id,name,nameAr,nameEn}`. The legacy `name` field remains Arabic. `preferredBarber: {id,nameAr,nameEn,availabilityCheckedAt}` records the original choice. A request with no chosen barber remains `PENDING`, `assignmentMode: MANAGED`, `requiresAdminApproval: true`, `isAssigned: false`, with no assignedWorker. The approval flag is derived from the current status, including later admin reassignment.

The old `consent: true` field is optional. Omission and true normalize identically for idempotency; explicit false remains invalid. This is request compatibility, not a stored record of checkbox consent. Customer coordinates are not retained. An idempotent retry returns the already-created booking even if availability later changes. Worker cancellation is not added; confirmed customer cancellation still requires support. Admin reassignment and cancellation stay available through the existing controls.

## Removable fictional directory

Only the existing allowlisted pilot customer, with public intake closed and the pilot unexpired, receives the three fictional Minya entries stored in the pilot manifest. Their names and coarse zones are in `lib/demo-fixtures.ts`, and the response adds `demoOnly: true` and `availabilityIsPreview: true`. These are fixed presentation examples, not actual staff availability. All three now have employee records so selections can confirm real booking rows and reserve their demo slots. The first uses the existing pilot worker account; the other two are manifest-owned fictional employees with no login accounts. Qualification, activity and slot conflicts are checked for all three. No real outside employee can enter this demo assignment path.

`node --env-file=.env.local --import tsx scripts/demo-nearby.ts` is a dry run. `--confirm` creates the two manifest-owned fictional employees, updates the pilot directory, and fills a missing English name on the matching pilot employee. Original expiry, catalog prices, payment state, intake and release config stay unchanged. Guarded cleanup removes the two extra employees as well as the directory manifest. It aborts on changed identity, a linked user, contact/payroll data or unrelated bookings. Clean-launch reset still requires separate owner approval and has not been executed.

## Worker English fields

- Admin employee POST/PATCH/GET: `displayNameEn`. PATCH omission preserves it; null/empty clears it.
- Login user and `GET /me`: `displayNameEn`.
- Profile: `displayNameEn` and `workerProfile.employeeNameEn`.
- Worker schedule items: `serviceNameEn`, `areaNameEn`.
- Assigned booking worker: `assignedWorker.nameEn`.
- Nearby barber: `nameEn`.

No English field falls back to Arabic. Flutter should show an English placeholder for missing translations rather than copying the Arabic value into English UI.

## Regression checks

Run the selected suites through `scripts/isolated-test.ts`. It creates and removes separate temporary schemas, not production fixtures. Never run permission/lifecycle tests against the live public schema. Nearby tests include role/privacy checks, coarse storage, availability/zone staleness, conflicts, radius, fallback, booking-time recheck, idempotency, English staff/schedule fields, and removable demo previews.

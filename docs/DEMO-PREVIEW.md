# Pilot preview presentation

The allowlisted pilot fixtures use fictional names and a neutral, city-free address to preview the normal app UI. They are not real customers, staff or dispatch instructions.

`node --env-file=.env.local --import tsx scripts/demo-preview-data.ts` previews the fixture update. Add `--confirm` to apply it to the two manifest-owned seed bookings and their allowlisted catalog/accounts. It rejects an open public intake, unexpected owners, unrecognized fixture amounts or any paid seed booking. This updates presentation data, not booking/payment lifecycle states. It does not change passwords, emails or account roles.

## Optional booking display fields

The usual `/bookings`, `/bookings/:id`, `/worker/bookings` and admin booking responses keep the existing envelope and fields, and may include:

- `service.nameEn`, English service label.
- `area.nameEn`, English area label.
- `customerNameEn`, English fixture customer name.
- `assignedWorker.nameEn`, English fixture worker name.
- `address.streetEn`, English street label.
- `address.directionsEn`, English arrival note.
- `contactPhoneMasked: true`, the fixture phone is display-only and must not be dialed or used for messaging. The visible phone is masked instead of a real routable number.
- `dispatchAllowed: false`, the booking is a pilot fixture, not an external dispatch request.
- `payment.statusLabelAr` and `payment.statusLabelEn`, display text for `UNPAID`, `PENDING_REVIEW` or `PAID`. `payment.status` remains the authoritative enum. `UNPAID` displays as "لسه ما اتدفعش" / "Not paid yet". Labels are generated from the enum, never a replacement for it.

Select English fields in English mode, falling back to the original Arabic fields when an English field is absent. The English booking fields are optional and currently populated for the seeded preview bookings. They do not imply that arbitrary user-entered addresses have been translated. Catalog/profile base schemas remain Arabic-first.

## Safeguards and cleanup

- Normal `config.intakeEnabled` remains false. Demo access remains limited to the explicitly allowlisted pilot customer and seeded service/area IDs.
- `demoOnly`, `isDemo` and each booking's `demoSeed` remain present server-side.
- New allowlisted demo bookings receive `dispatchAllowed:false`.
- A seeded demo booking can be assigned only to the manifest's mapped pilot employee/user. Reassigning it to another employee fails with `409 DEMO_DISPATCH_BLOCKED`.
- No external dispatch integration or booking email is added. Masked fixture contacts are not real recipients.
- Payment state/collected amounts are not changed by presentation updates. Fictional preview prices are centralized in `lib/demo-fixtures.ts`: haircut 200 EGP, beard 100 EGP, travel zero. They are not commercial offers. `scripts/demo-preview-prices.ts` is dry-run unless `--confirm` is supplied and reconciles only the manifest's confirmed haircut fixture to its service total. The older completed zero-price booking is retained as a historical fixture. All remain removable by `demo:reset`.
- Demo expiry and ownership manifest are retained. `npm run demo:reset` still discovers the fixture records by IDs/demoSeed, not display names; it is dry-run unless `--confirm` is supplied. Never use a reset merely to test it on live data.
- The saved smoke-test idempotency payloads are left unchanged to preserve their request hashes and history. Historical audit entries are not rewritten. The older `demo-neutral-labels.ts` utility reflects an earlier presentation and should not be rerun over this preview.

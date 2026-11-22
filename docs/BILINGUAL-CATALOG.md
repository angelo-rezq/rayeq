# Arabic and English catalog

Additive catalog fields, with no automatic translation:

- Service: `nameAr`, `nameEn`, `descriptionAr`, `descriptionEn`, `category` (Arabic), `categoryEn`.
- Area: `nameAr`, `nameEn`.
- Both DTOs add `englishReady`. Services need an English name/category plus an English description when their Arabic description is nonempty. Areas need an English name.
- Existing price, duration, version, active and image fields are unchanged. All money stays integer minor units.

`GET /api/v1/catalog` and `GET /api/v1/admin/catalog` return these fields. The admin service and area POST/PATCH routes accept the English fields. Old clients can still send Arabic-only payloads. On PATCH, omitted English fields preserve the saved values; explicit null or an empty string clears them. There is no Arabic fallback inside English fields. PATCH still requires the current version. Old APIs can leave a record untranslated, so clients should check `englishReady` and use a language-appropriate placeholder rather than Arabic text in English mode.

The dashboard has separate Arabic/English inputs. An active record requires complete English text there; an incomplete translation can be saved as inactive. This prevents newly activated dashboard services from mixing languages without breaking older API clients. Disable a service to remove it from the customer catalog; do not delete booking history.

Quotes add `serviceNameEn` and `areaNameEn`. New bookings snapshot `service.nameEn` and `area.nameEn`; later catalog edits do not rewrite booked names or prices. The old prototype page is not the native Flutter app. Flutter must read the new fields to display them.

## Demo-only backfill

`node --env-file=.env.local --import tsx scripts/demo-catalog-english.ts` is dry-run by default. `--confirm` fills missing English fields only on the two service IDs and one area ID owned by the removable pilot manifest, with expected fictional Arabic names. It never changes prices, payments, intake or release settings. The seed module retains preview prices haircut 200 EGP, beard 100 EGP, travel 0, and future seeding includes English text.

## Checks

`node --env-file=.env.local --import tsx scripts/isolated-test.ts catalog-test permission-test` creates separate temporary schemas inside the dedicated Rayeq Neon database, runs both suites, and drops those schemas. It uses a direct connection because pooled startup search-path options are not supported. It never runs the permission suite against the live public schema. Catalog checks refuse to run outside their isolated schema.

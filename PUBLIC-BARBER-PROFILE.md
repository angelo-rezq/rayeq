# Customer-visible barber profiles

All routes use the existing `/api/v1` prefix and `{data: ...}` success envelope. This change is additive. Release metadata and installer behavior are unchanged.

## Customer detail

`GET /barbers/:employeeId` still requires an authenticated customer and the existing visibility rules. Use an employee ID, not a worker user ID.

Existing fields remain: `id`, `nameAr`, `nameEn`, `ratingAverage`, `reviewCount`, `demoOnly`, `gallery`.

Added fields:

- `titleAr`, `titleEn`, `bioAr`, `bioEn`: plain strings, empty when not provided.
- `yearsExperience`: integer 0..80 or null when not provided.
- `specialtiesAr`, `specialtiesEn`: string arrays, empty by default.
- `portraitUrl`: absolute public WebP URL or null. This is a separately uploaded public portrait, not the private account avatar.
- `areaNameAr`, `areaNameEn`: joined names of active admin-assigned service areas, not a street address, home address or live location.
- `serviceAreas`: `[{id,nameAr,nameEn}]`.
- `services`: `[{id,nameAr,nameEn,descriptionAr,descriptionEn,priceMinor,durationMinutes,currency:"EGP",priceExcludesTravel:true}]`. Only active, admin-assigned services appear.
- `startingPriceMinor`: lowest included service base price, or null when no service is assigned.
- `currency`: `"EGP"`.
- `priceExcludesTravel`: true. Use the existing quote endpoint for the final price.

`GET /barbers/featured` items and `POST /barbers/nearby` barber summaries also include `portraitUrl` and `galleryThumbnailUrl`, each an absolute URL or null. A gallery thumbnail can be used when no public portrait exists. These fields do not change availability or reserve a slot.

Existing review and gallery endpoints are unchanged. Demo visibility remains restricted to explicitly allowlisted pilot customers, and demo data remains marked `demoOnly`.

## Worker editing

Approved active workers can use:

- `GET /worker/public-profile`
- `PATCH /worker/public-profile`
- `PUT /worker/public-profile/portrait`
- `DELETE /worker/public-profile/portrait`

GET/PATCH/PUT return one flat object inside `data`, not a nested `workerProfile`: `{employeeId,nameAr,nameEn,demoOnly,...all added public fields above}`.

PATCH accepts any nonempty subset of:

- `titleAr`, `titleEn`: strings, at most 100 characters each.
- `bioAr`, `bioEn`: strings, at most 1500 characters each.
- `yearsExperience`: integer 0..80 or null to clear.
- `specialtiesAr`, `specialtiesEn`: at most 12 strings per array, each 1..80 characters.

Unknown fields are rejected. Workers cannot select another employee, change service/area assignments, publish private contact fields, change prices, activate an account or alter ratings through this endpoint. User-entered text is plain text, not HTML. Tell workers explicitly that these fields are customer-visible.

Portrait PUT accepts a raw JPEG/PNG/WebP body and matching Content-Type, not JSON or multipart. Maximum input is 5 MiB and 16 million pixels; animated/forged/corrupt formats are rejected. Images are auto-oriented, metadata stripped, resized within 512 px, and stored as WebP at at most 250 KiB. Ten upload attempts per hour per actor. Public portraits and gallery images share the serialized 60 MiB public-image budget. A portrait does not consume one of the six gallery slots.

DELETE returns 204 and removes the public portrait. It does not delete a private account avatar. Public portrait URLs return 404 for deleted/inactive/unapproved or expired demo records.

## Administration

Admins use the equivalent routes at `/admin/employees/:employeeId/public-profile` and `/portrait`. The dashboard has a `الملف العام` button on employee rows. Editing an employee's public profile does not change their private employment information.

Demo fixtures can be added with `scripts/demo-public-profiles.ts` only while the ownership-checked pilot manifest is active and intake is off. The demo portraits are existing credited stock assets or a monogram. Bios explicitly identify the stock portrait, years and specialties as fictional display data. Existing edited profiles are not overwritten. The guarded demo-reset dry run includes the public-profile count; no reset is executed as part of this feature.

## Desktop editor and public image delivery

The employee public-profile editor uses a 1040px maximum-width dialog and paired Arabic/English fields on desktop. Under 800px it returns to a single column. Other dialogs keep their existing width. The upload control is labelled and keyboard-focusable.

Only `/api/v1/work-photos/:id` and `/api/v1/barber-portraits/:id` allow unauthenticated public media reads with `Access-Control-Allow-Origin: *` and `Cross-Origin-Resource-Policy: cross-origin`. GET, HEAD and OPTIONS are supported. HEAD has the image content type but no body. Cache-Control remains no-store and X-Content-Type-Options remains nosniff. Staff activation, demo expiry, deletion and existing rate limits still apply. Private account avatars, administrative images and JSON APIs do not gain these public media headers.

The backed-up build-2 featured-card widget used a fixed scissors icon, and its customer profile had no portrait input. The previous API had no portrait URL. Adding transport headers alone cannot make those widgets display a portrait. The mobile client must consume the additive portraitUrl/galleryThumbnailUrl fields and render the new profile fields. No device-wide image failure is claimed fixed without a real-device check of the updated app.

Read-only live HTTP/decode check: `node --import tsx scripts/public-media-http-smoke.ts`. It checks the seeded demo portrait/gallery URLs, public methods and headers, actual WebP decoding and that the private avatar remains protected. It does not create a login session or change content.

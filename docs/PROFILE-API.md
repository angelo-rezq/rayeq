# Profile and images API

All paths are under `https://rayeq-platform.onrender.com/api/v1`. Send the signed-in user's Bearer token. Every operation is scoped to that authenticated user, with no user-ID parameter. JSON follows the normal `{ "data": ... }` envelope.

## GET /profile
Returns `id`, `name`, `email`, `emailVerified`, `role`, `phone` and `avatarUrl` (null when absent). A mapped worker also receives read-only `workerProfile` with `employeeId`, `employeeName`, `active`, `serviceIds` and `areaIds`.

## PATCH /profile
JSON: `{ "name": "...", "phone": "+201..." }`. Either field can be omitted, but at least one is required. Name is trimmed, 1 to 100 characters. Phone is contact-only, up to 20 characters; empty string clears it. No SMS verification or login identity is granted by the phone field. Email, account role and employee mapping cannot be changed here. For mapped workers, the contact phone is also reflected in their employee contact record. The official employee name remains admin-managed.

Returns the updated profile.

## PUT /profile/avatar
Raw image bytes, not multipart or base64 JSON. Content-Type must be `image/jpeg`, `image/png` or `image/webp`. Input is capped at 2 MiB, 16,777,216 decoded pixels, and one static image. MIME must match the decoded format. SVG/GIF and malformed data are rejected. The server rotates according to orientation, resizes within 512 by 512 without enlarging, strips metadata by re-encoding, and saves WebP with an additional 512 KiB output cap. Maximum 10 upload attempts per hour per account. A busy processor can return 429 for a retry.

Returns the updated profile with versioned `avatarUrl`. The URL is private: GET it using the same Bearer credentials and display the returned bytes, for example as an in-memory image. Do not treat it as a public `Image.network` URL without authentication. Errors are normal JSON envelopes, not image bytes.

## GET /profile/avatar
Returns the current authenticated user's WebP bytes with `Content-Type: image/webp`, no-store caching and nosniff. Missing avatar returns 404, anonymous access 401. Query parameters cannot select another user's avatar.

## DELETE /profile/avatar
Removes the current user's avatar. Returns 204.

## Service images
Catalog and admin service DTOs include optional `imageUrl` (string or null). Admin service create/update accepts optional `imageUrl`, an HTTPS URL without embedded credentials. Omitting it on update preserves the existing URL; null clears it. The demo catalog uses the existing bundled generic grooming photo. There are no invented employee portraits.

## Persistence
Profile phone and bounded avatar bytes are stored in the existing dedicated Neon database in `rayeq_profiles`, not on Render's ephemeral filesystem. They survive application sleep and redeployment and count against the existing free database quota. Bundled service images are versioned in the repository and redeployed with the app. No paid storage service has been added. Existing backup/restore limitations still apply.

# Clean launch preparation

Do not wipe while the design is still being reviewed. The clean-launch command below is dry-run unless `--confirm` is supplied. Execution requires a later explicit approval.

## Prepared command

Preview and run all preflight guards without deleting anything:

```sh
npm run demo:reset -- --clean-launch
```

Only after approval, the operator can add `--confirm`. The clean-launch mode implies removal of the two pilot accounts and mapped pilot employee, plus the two manifest-owned nearby preview employees. It also sets `isDemo=false`, removes the demo allowlist/expiry config and leaves public booking intake closed.

The wipe is scoped by the `rayeq-pilot-20261122` ownership manifest and `demoSeed`, not display names. It removes its bookings, their idempotency records, seeded services/area, pilot sessions and verification/reset codes, pilot users and all three manifest-owned employees. User profile/avatar rows are removed by their user foreign-key cascade. The real admin account and credentials are preserved. Historical admin audit entries remain, with retired test actors detached. Those entries can contain old fictional fixture labels; they are not active customer/booking data.

Preflight aborts if unexpected account ownership, unrelated bookings, payroll, or other employees reference the pilot records/catalog. It never deletes an unrelated real record to make a wipe succeed.

## Expected state from the current pilot

The last dry-run found two bookings, two services, one area, two test accounts and three test employees to remove, including the two nearby preview employees. There is currently one real admin and no payroll. If no new real records arrive before execution, a successful approved cleanup would leave:

- One real admin account with the same credentials.
- Zero customer/worker accounts, employee records, bookings, services, areas and payroll records.
- No pilot allowlist or seed manifest; no pilot sessions/codes/profiles.
- `isDemo=false`, `intakeEnabled=false`.
- Empty public catalog and normal empty states, not invented sample people/services/bookings.
- No enabled payments, automatic dispatch or new commercial commitments.

Run a fresh dry-run immediately before any approved execution. Inspect the result afterward, including anonymous catalog flags, admin counts, retired-account sign-in failure, and the app's empty states.

## Separate launch gates

Database cleanup does not remove hardcoded sample content from a compiled Flutter bundle or APK. Flutter must remove sample staff cards, sample favorites/reviews, dummy service fallbacks and any preview-only registration behavior, and show real empty states. A new clean bundle/APK must be verified before calling the whole app clean.

Real account registration requires working verification email. The registration API remains email-gated; never bypass it merely to show a clean screen. Real workers register pending approval and must be activated/mapped by the admin. Opening real booking intake is a separate decision requiring real catalog/coverage/staff, verified support/payment policy and working email. Do not open it as part of the wipe.

The current APK/version metadata remains unchanged by cleanup preparation. Release and upload a clean APK separately when the final design and behavior are approved.

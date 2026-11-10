# Cleaning up the test data (after the lab viva)

**Do not run any of this yet.** The `@test.com` accounts and sample data are still needed for the CSE 3218 lab viva. This page lists exactly what to remove afterwards, before the app goes to the App Store.

Everything here is done by hand in the [Firebase console](https://console.firebase.google.com/) (project `kuetbuslive`), so nothing is deleted by accident. Deleted accounts and documents cannot be brought back, so take an export first.

## 0. Back up first

Firestore > Import/Export > Export, or with the CLI:

```
gcloud firestore export gs://<your-bucket>/before-cleanup
```

Exports need the Blaze plan and a Cloud Storage bucket. Without them, at least screenshot the `users` collection so you know who was there.

## 1. Test accounts in Authentication

Authentication > Users, search for `test.com`. Delete every account whose email ends in **`@test.com`** (for example `student2@test.com`, `teacher@test.com`, `driver@test.com`).

Keep:

- the real transport admin account,
- `appreview.student@kuetbuslive.app` and `appreview.driver@kuetbuslive.app` (Apple's review accounts, see [docs/app-review-notes.md](../docs/app-review-notes.md)),
- any real KUET accounts (`@stud.kuet.ac.bd`, `@kuet.ac.bd`).

Note each deleted account's **User UID** before you delete it; step 2 needs them.

## 2. Their profiles in Firestore

Firestore > `users`. Delete the document for each UID from step 1. Their documents also have `email` ending in `@test.com`, which makes them easy to spot. A profile whose login no longer exists does nothing but take up space.

## 3. Buses left on the map

Firestore > `buses`. A bus document only exists while a trip runs, so outside bus hours this collection should be **empty**. Delete any document whose `driverId` is one of the UIDs from step 1, and any bus whose `updatedAt` is more than a day old (a trip that was never ended).

## 4. Test announcements

Firestore > `announcements`. Delete the ones posted while testing (titles like "Test", "Hello", demo text). Keep real notices from the transport office, if any.

## 5. Data from the newer features

- `complaints`: delete the ones sent while testing (any from the `@test.com` accounts).
- `fleet`: keep the buses, but clear any test drivers set as `defaultDriverId` or `cover` and assign the real drivers.
- `driverAbsences` and `trips`: delete the ones belonging to test drivers.
- For each deleted user, their `users/{uid}/places` and `users/{uid}/rideHistory` subcollections (the console doesn't delete subcollections with the parent document, so open each one).
- `buses/{busId}/waves`: should be empty outside bus hours; delete any left over.

## 6. Timetable and routes

Firestore > `schedules` and `routes`. These hold the official KUET timetable and the sample routes loaded with **Load official KUET timetable** and **Add sample KUET routes**. **Keep them**, but ask the transport office to check the stop names and coordinates; the sample routes are approximate. Delete any extra trips or routes made while testing the editor.

## 7. Turn the new rules on

The repository's `firestore.rules` is the tightened production version, tested in `firestore-tests/`. Deploy it once the cleanup is done:

```
firebase deploy --only firestore:rules
```

**Until this is deployed, Profile > Delete account fails** on the live project (the rules running now only let the admin delete profiles), and so do complaints, My places, waves, the ride-history backup and bus assignment. Set up the fleet and give each real driver a bus in **Drivers & buses** first: with the new rules a driver can start a trip only on the bus assigned to them today.

## 8. Check

- Sign in as the admin: Approvals shows no `@test.com` people.
- Sign in as each App Review account: both still work.
- The student map shows "No buses are running right now".

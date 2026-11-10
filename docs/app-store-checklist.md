# App Store checklist

What KUET Bus Live needs before it can be submitted, and where each item stands. ✅ done in the repository, 🟡 prepared but needs a step from Muttakin, ⬜ not started.

| # | Item | Status |
|---|---|---|
| 1 | Paid Apple Developer account | ⬜ |
| 2 | Privacy policy URL and privacy labels | ✅ |
| 3 | Account deletion in the app | 🟡 |
| 4 | Demo login for App Review | 🟡 |
| 5 | Clear location permission text | ✅ |
| 6 | Remove test data, deploy production rules | 🟡 |
| 7 | TestFlight on a real iPhone | ⬜ |
| 8 | Store listing: screenshots, description, age rating | ⬜ |
| 9 | Permission from the KUET transport office | ⬜ |

## 1. Paid Apple Developer account ⬜

Join the [Apple Developer Program](https://developer.apple.com/programs/) (USD 99 a year, as an individual). Free accounts can run the app on a phone for 7 days but cannot use TestFlight or the App Store. Push notifications also need the paid account.

Then, in Xcode, pick the new team for both targets and change the bundle IDs from `KUETBusLive` / `KUETBusLive.KUETBusWidget` to reverse-DNS ones you own, for example `io.github.shadowfax505.kuetbuslive` and `io.github.shadowfax505.kuetbuslive.widget`. The App Group (`group.KUETBusLive`) must be renamed to match, in both entitlements files and in `SharedStore.appGroup`. Register the new bundle ID in Firebase too and download a fresh `GoogleService-Info.plist`.

## 2. Privacy policy and privacy labels ✅

- Policy: [docs/privacy-policy.md](privacy-policy.md), linked from the README and from **Profile > About** in the app. URL for App Store Connect:
  `https://github.com/shadowfax-505/KUETBusLive/blob/main/docs/privacy-policy.md`
- Privacy manifests: `KUETBusLive/PrivacyInfo.xcprivacy` and `KUETBusWidget/PrivacyInfo.xcprivacy` (no tracking; name, email, user ID, precise location and other user content for app functionality; UserDefaults reasons CA92.1 and 1C8F.1).
- Answers for App Store Connect's questionnaire: [docs/app-store-privacy-labels.md](app-store-privacy-labels.md).
- Updated for complaints, My places, waves, bus assignment, smart suggestions (on-device, optional account backup) and the on-device assistant (sends nothing).

## 3. Account deletion 🟡

Done in the app: **Profile > Delete account** asks for the password, ends a driver's running trip and removes their bus, deletes the profile (with the push token), saved places, an open wave, complaints, ride history and the login, then clears the passcode, Face ID setting, alerts, widget data and Live Activity on the phone. The last transport admin cannot delete themselves. Unit tests in `AccountDeletionTests`; tried end to end against the local Firebase emulators.

**Still to do:** deploy `firestore.rules` (step 6). The rules on the live project still only let the admin delete profiles, so deletion fails there until then.

## 4. Demo login for App Review 🟡

Done in the app: exactly `appreview.student@kuetbuslive.app` and `appreview.driver@kuetbuslive.app` skip the KUET email checks (`KUETVerifier.appReviewEmails`). Release builds reject `@test.com`.

**Still to do:** create both accounts and their profiles in the Firebase console, **assign the review driver a bus** in Drivers & buses, and put the passwords in App Store Connect only. Step by step, with notes to paste for the reviewer: [docs/app-review-notes.md](app-review-notes.md).

## 5. Location permission text ✅

Both location messages say exactly when location is used, in English and Bangla (`KUETBusLive/InfoPlist.xcstrings`). Only a driver starting a trip is asked for "Always"; riders are only asked for "While Using" on the map.

## 6. Clean up test data and deploy production rules 🟡

The tightened `firestore.rules` is written and covered by 43 emulator tests (`firestore-tests/`, also run in CI). It is **not deployed yet**, and no accounts or data have been deleted, because the `@test.com` accounts are needed for the lab viva.

**Still to do, after the viva:** follow [scripts/cleanup-test-data.md](../scripts/cleanup-test-data.md), then `firebase deploy --only firestore:rules`.

These features only work on the live project after the rules are deployed: Delete account, complaints, My places, "I'm waiting here", ride-history backup, bus assignment (fleet, driver absences, trip history), and the assigned-bus check when a driver starts a trip. Before deploying, an admin must also create the fleet and give each driver a bus in **Drivers & buses**, or no driver can start a trip.

## 7. TestFlight on a real iPhone ⬜

1. Product > Archive in Xcode (Release), then Distribute App > App Store Connect.
2. In App Store Connect, add yourself as an internal tester and install from the TestFlight app.
3. On the phone, check: sign-up with a real KUET email and the verification link; a driver trip with the screen locked for 10+ minutes (the bus keeps moving on another phone); the widget and Live Activity; Face ID lock; Delete account; Bangla.
4. Push notifications need an APNs key uploaded to Firebase and the Cloud Function deployed (Blaze plan). If that isn't ready, leave push out of the store description.

## 8. Store listing ⬜

- **Smart assistant:** if you mention it, say it is optional and works only on iPhones with Apple Intelligence (iOS 26).
- **Screenshots:** 3 to 10 per size. The 6.7"/6.9" set (1290 × 2796 from an iPhone 15/16 Plus or Pro Max simulator, or 1320 × 2868 from an iPhone 17 Pro Max) and the 6.5" set (1284 × 2778 or 1242 × 2688). App Store Connect scales them for smaller phones. Good screens: the live map with a bus, the trip card with ETA, the timetable, the widget, the Live Activity, Bangla dark mode.
- **Description:** what it does for KUET students and drivers, that it needs a KUET account, and that it is a student project not run by KUET (unless item 9 says otherwise).
- **Category:** Navigation (or Travel). **Price:** free.
- **Age rating:** answer "None" to every content question; the result should be 4+.
- **Support URL:** `https://github.com/shadowfax-505/KUETBusLive/issues`.

## 9. KUET transport office permission ⬜

The app uses KUET's name, its bus timetable and its routes, and asks drivers to share their location. Before a public release, get written permission from the KUET transport office (and ideally the registrar), agree who will be the transport admin, and ask them to confirm the timetable and stop locations. Apple may reject an app that looks official for an institution without proof of permission, so keep the letter ready to attach in App Review notes.

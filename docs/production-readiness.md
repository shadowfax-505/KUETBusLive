# Production readiness and growth

Notes for taking KUET Bus Live (iOS and Android, one Firebase project) from a lab
project to the whole campus. Last reviewed 23 November 2026.

## Done

| Area | What changed | Apps |
|---|---|---|
| Firestore cost | A driver's phone sends the bus position only after moving 15 m (at most every 5 s), plus a "still here" update every 20 s while standing. Every write is one read for every rider watching, so this cuts reads at stops and signals. | both |
| Battery and data | Android pauses the live bus feed and the ETA refresh a minute after the rider leaves the map (15 minutes when arrival alerts are on). iOS already stops when the map closes. | Android |
| Offline | An "Offline" pill on the live map and on the driver screen during a trip. | both |
| Routing | 10 s timeout, status check, and a swappable server (`OSRMBaseURL` in Info.plist on iOS, `Osrm.BASE_URL` on Android). | iOS |
| Logs | `os.Logger` with private values instead of `print`, so release logs hold no emails or IDs. | iOS |
| Crash reporting | Firebase Crashlytics in release builds, not linked to the user. Privacy policy, labels and manifest updated. | both |
| Release build | R8 shrinking, upload key from CI secrets or `~/.gradle/gradle.properties`, target API 36, no cloud backup or device transfer, CI builds the release too. | Android |
| Rules | Size and type limits on profiles, complaints, trips, absences, ride history, places, waves and drop-offs; fleet and learned stats readable only with a profile; drop-off counts only for routes that exist. 79 emulator tests. | shared |

## Still to do by hand

1. **Deploy the rules:** `firebase deploy --only firestore:rules` (after merging).
2. **Crashlytics:** open Crashlytics in the Firebase console once for each app so it starts accepting reports. Build a Release on the Mac once so the iOS symbol upload runs.
3. **Android release key:** create an upload key (`keytool -genkeypair -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`), keep it out of git, and add the GitHub secrets `KUETBUS_RELEASE_STORE_BASE64` (`base64 -i upload.jks`), `KUETBUS_RELEASE_STORE_PASSWORD`, `KUETBUS_RELEASE_KEY_ALIAS`, `KUETBUS_RELEASE_KEY_PASSWORD`. Then enrol in Play App Signing.
4. **Test a release build** on a real phone before publishing: R8 problems only show up when the app runs.

## On hold (decided 23 Nov 2026)

- **Blaze plan.** The free plan allows 50,000 reads and 20,000 writes a day. That is enough for a pilot, not for the whole campus at rush hour. Before a wide launch, move to Blaze with a budget alert (about USD 5 to 20 a month at full campus use). It also turns on the departure-push Cloud Function. The other option is moving live positions to Realtime Database, which bills by data volume instead of per read.
- **App Check.** This blocks requests that don't come from the real apps. It needs the paid Apple account (App Attest) and a Play Console listing (Play Integrity).

## Rough numbers

- Writes: 31 trips a day × about 45 minutes. A 5 s timer used to give about 17,000 writes a day. Sending only on movement, plus the 20 s heartbeat, should roughly halve that.
- Reads: each rider on the map reads every update of every bus they can see. 200 riders watching 5 buses for 10 minutes used to be about 120,000 reads. Expect about half that now, which is still over the free 50,000 on a busy day.
- OSRM: each rider asks for an ETA at most every 30 s. The public demo server has fair-use limits, so for a campus-wide release run a small OSRM server with Bangladesh map data and set its address.

## Growing the user base

- **Get endorsed:** a letter from the transport office (also needed for App Review, see the App Store checklist). Ask them to share the link on KUET's notice board and Facebook page.
- **QR posters** at every stop, in halls and on the buses, pointing to one download page (GitHub Pages) that sends iPhones to the App Store and Android phones to Play.
- **Class reps as launch champions:** a short demo in each department's group, Bangla first.
- **Bangla store listings** with screenshots of the live map, the widget and the Live Activity.
- **Low-friction sign-up:** students already sign up with their roll and KUET email. Keep it to one screen, and remind people to check spam for the verification email.
- **In the app (next steps):** a "Share KUET Bus Live" link in Profile, and a review prompt (SKStoreReviewController / Play In-App Review) after a few trips that went well.
- **Measure:** Crashlytics crash-free users for stability. Count weekly active riders from the Firestore `users` collection, without adding analytics.

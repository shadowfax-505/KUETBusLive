# App Review demo accounts

Apple's reviewers have no KUET email, so they cannot sign up like a real student. The app lets exactly two addresses skip the KUET email checks, in every build:

| Account | Email | Role |
|---|---|---|
| Student | `appreview.student@kuetbuslive.app` | student |
| Driver | `appreview.driver@kuetbuslive.app` | driver |

The addresses live in one place: `KUETVerifier.appReviewEmails` in `KUETBusLive/Services/KUETVerifier.swift`. No other address on that domain is allowed, and release builds reject new `@test.com` sign-ups.

Demo only: these two accounts and existing `@test.com` accounts never see the "verify your KUET email" screen, in any build (`DemoAccounts`). Remove `DemoAccounts.swift` before a public release.

**Passwords never go in this repository.** They are typed only into the Firebase console and into App Store Connect's review notes.

## Part 1: create the accounts (before submitting)

Do this in the [Firebase console](https://console.firebase.google.com/) for the `kuetbuslive` project.

1. **Create both logins.** Authentication > Users > Add user. Enter each email above with a strong password of its own (use a password manager). Copy each account's **User UID**.

2. **Create the student profile.** Firestore Database > `users` > Add document. Use the student's User UID as the **Document ID** and add these fields:

   | Field | Type | Value |
   |---|---|---|
   | `name` | string | `App Review Student` |
   | `email` | string | `appreview.student@kuetbuslive.app` |
   | `role` | string | `student` |
   | `kuetId` | string | `2207001` (any 7-digit sample roll) |
   | `isApproved` | boolean | `true` |
   | `favoriteStopName` | string | the name of a stop on a route, exactly as it is written in `routes` |
   | `favoriteStopLat` | number | that stop's `lat` |
   | `favoriteStopLng` | number | that stop's `lng` |

   Instead of the three `favoriteStop` fields, you can sign in as the student once and pick a stop in **Routes**.

3. **Create the driver profile.** Same again with the driver's User UID as the Document ID:

   | Field | Type | Value |
   |---|---|---|
   | `name` | string | `App Review Driver` |
   | `email` | string | `appreview.driver@kuetbuslive.app` |
   | `role` | string | `driver` |
   | `kuetId` | string | `D-REVIEW` |
   | `isApproved` | boolean | `true` |

   (Or create it with `isApproved` set to `false` and approve it from the admin's **Approvals** tab.)

4. **Give the driver a bus.** Drivers can only start trips on the bus assigned to them. Sign in as the admin, open **Drivers & buses** (under More), tap **Create buses from the timetable** if the list is empty, open a bus (for example Normal-1) and choose **App Review Driver** as its regular driver. Pick a bus that has trips on most days so the reviewer can always start one.

5. **Check it works.** Sign in as each account on a TestFlight build. The student should land on the map; the driver on the Driver screen showing "Your bus today" with that bus's trips. If the driver sees "The transport admin hasn't added trips or routes yet", load the official timetable and routes as admin first.

6. **Give Apple the logins.** App Store Connect > your version > App Review Information > Sign-In Information: tick "Sign-in required", enter the **student** email and password, and paste the driver login and the walkthrough below into **Notes**.

## Part 2: notes to paste for the reviewer

> KUET Bus Live is a campus bus tracker for Khulna University of Engineering & Technology (KUET). Normal sign-up needs a KUET university email, so we created two demo accounts for you.
>
> Student: appreview.student@kuetbuslive.app / (password)
> Driver: appreview.driver@kuetbuslive.app / (password)
>
> **To see a bus move live (two devices):**
> 1. On device A, sign in as the driver. The screen shows the bus assigned for today. Pick one of its trips and a route, tap **Start trip**, and allow location. The app shares the bus position only while the trip runs; iOS shows the blue location indicator.
> 2. On device B, sign in as the student. The bus appears on the **Map** tab. Tap it to see the arrival time at the student's stop and to report how crowded it is.
> 3. On device A, tap **End trip**. The bus disappears from device B's map.
>
> **With one device:** sign in as the student. The **Schedule** tab shows the full KUET timetable, **Routes** shows every route and stop, and **News** shows transport announcements. These work without a running bus. The map says "No buses are running right now" when no driver is on a trip, which is the normal state outside bus hours.
>
> **Account deletion:** Profile > Delete account (asks for the password, then removes the profile and login).
>
> **Location:** only drivers share location, and only while a trip is running. Students' own location is shown on their map but never uploaded.

## Part 3: after approval

Keep both accounts for future updates. Before each new submission, check they still sign in, that the driver profile is still approved and active, and that the review driver is still the regular driver of a bus.

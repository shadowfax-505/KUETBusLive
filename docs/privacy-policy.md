# KUET Bus Live: Privacy Policy

_Last updated: 10 November 2026_

KUET Bus Live is a student project by Muttakin Rahman Shoscho, a CSE student at Khulna University of Engineering & Technology (KUET). It shows KUET buses live on a map, the bus timetable and transport announcements. This page explains, in plain words, what the app stores about you, why, and how to remove it.

The short version: the app only keeps what it needs to show you the right buses. There are no ads, no analytics and no tracking, and nothing is sold or shared with anyone for marketing.

## What the app stores

### Your account

When you sign up, the app saves:

- your **name**
- your **email address** (your KUET email, or the address a driver signs up with)
- your **KUET ID**: roll number for students, employee ID for teachers, driver ID for drivers
- your **role** (student, teacher, driver or transport admin) and whether the transport admin has **approved** you
- your **favourite stop**, if you pick one

Your password is handled by Firebase Authentication. The app never sees or stores it.

**Why:** to check that you belong to KUET, to show you only the buses you are allowed to ride, and to work out when the bus will reach your stop.

### Location

- **Drivers:** while a trip is running, the app sends the bus's position (latitude, longitude, direction and speed) about every five seconds, so students can see the bus on the map. It keeps doing this if the phone is locked, and iOS shows the blue location indicator the whole time. When the driver ends the trip, the bus and its position are deleted. **No location is collected when no trip is running.**
- **Students and teachers:** the app may show your own position on the map so you can see where you are compared with the bus. That position stays on your phone and is never uploaded.

### Crowd reports

Riders can tap "Seats available" or "Full" for a running bus. The report is saved on that bus while the trip runs and is removed together with the bus when the trip ends. It is not saved with your name.

### Push notifications (optional)

If you allow notifications, Firebase Cloud Messaging gives your phone a **push token**. The app saves it on your profile and subscribes your phone to your route, so you can be told when your bus leaves campus.

### Things that stay on your phone

These never leave your device:

- which announcements you have already read
- your arrival alert setting and how many minutes early you want it
- the app passcode (only a scrambled hash, kept in the iOS Keychain) and the Face ID setting
- the trips, stop and bus details shown in the home screen widget and Live Activity

## Where it is kept

Account details, push tokens and running buses are stored in **Google Firebase** (Firebase Authentication and Cloud Firestore), run by Google. Google's own privacy terms are at <https://firebase.google.com/support/privacy>.

To draw route lines and estimate arrival times, the app asks the public OSRM routing service (router.project-osrm.org) for a route between a bus and its stops. Only those map coordinates are sent, never your name, email or account.

## Who can see what

- **Students and teachers** see the position, route and crowd level of buses they can ride. They cannot see other people's profiles.
- **Drivers** see their own trip.
- **The transport admin** can see profiles (name, email, KUET ID and role) so they can approve teachers and drivers.
- Nobody else. The database rules on the server block everyone else, and the data is not given to anyone outside the project.

## How long it is kept

- Your profile stays until you delete your account.
- A bus's live position and crowd level are deleted as soon as its trip ends.
- Data saved only on your phone is removed when you delete the app.

## Deleting your account

Open **Profile > Delete account**. After you confirm with your password, the app deletes your profile (including your favourite stop and push token) and your login, signs you out and clears the app's settings on that phone. A driver's running trip is ended first. This cannot be undone.

If you can no longer sign in, open an issue on the project page (below) and your account will be removed by hand.

## Children

The app is meant for KUET students, teachers and drivers, and is not aimed at children.

## Changes

If this policy changes, the new version will be posted on this page with a new date.

## Contact

Questions or requests: open an issue at <https://github.com/shadowfax-505/KUETBusLive/issues>.

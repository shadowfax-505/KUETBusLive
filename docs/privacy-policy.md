# KUET Bus Live: Privacy Policy

_Last updated: 10 November 2026 (second version)_

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

### My places and "I'm waiting here"

- **My places:** riders can save up to five places of their own (for example home or a tuition centre), each with a short name and a map position, to use as their boarding point. They are stored with your account so they work on a new phone, and only you can see them.
- **"I'm waiting here":** when you tap it for a running bus, the app shares the point on the route where you are waiting, with the place's name, with **that bus's driver only**. It disappears when the bus passes, when you cancel, when the trip ends, or after 15 minutes at most. Other riders can't see it.

### Complaints

If you use **Report a problem**, the app saves your complaint (category, optional bus, route and time, and your text) with your name and role, so the transport office can reply. Only you and the transport admin can read it. You can't change it after sending; deleting your account deletes it.

### Drivers: bus assignment and trip history

For drivers, the app keeps which bus each driver drives, any "I can't drive" requests (dates and reason), and a record of each trip (which bus, which timetable trip, start and end time). The transport admin sees these to arrange cover; each driver sees their own.

### Smart suggestions

To suggest "your usual bus", the app remembers on **your phone** when you follow a bus, get an arrival alert, wave at a bus or are next to it at your boarding point (trip name, route, boarding point, day and time), for up to 90 days. It also learns how late each trip usually leaves. This stays on the phone unless you turn on **Keep my ride history in my account**, which copies those events to your account so a new phone can use them. **Profile > Reset what the app has learned** deletes all of it, on the phone and in your account. You can also turn suggestions off.

### Smart assistant (optional)

On iPhones that support Apple Intelligence you can turn on **Smart assistant (on this iPhone)**. It is off by default. It uses Apple's model **on your iPhone**: your questions, and the timetable, live bus and news information the app gives it, are processed on the phone and **never sent anywhere**, not to the app's servers and not to anyone else. Its answers may be wrong.

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
- which announcements you hid, and whether news alerts are on
- your chosen boarding point and any wave you have open
- what smart suggestions learned (unless you keep it in your account)
- anything you ask the smart assistant

## Where it is kept

Account details, places, complaints, push tokens, driver assignments and running buses are stored in **Google Firebase** (Firebase Authentication and Cloud Firestore), run by Google. Google's own privacy terms are at <https://firebase.google.com/support/privacy>.

To draw route lines and estimate arrival times, the app asks the public OSRM routing service (router.project-osrm.org) for a route between a bus and its stops. Only those map coordinates are sent, never your name, email or account.

## Who can see what

- **Students and teachers** see the position, route and crowd level of buses they can ride. They cannot see other people's profiles.
- **Drivers** see their own trip.
- **The transport admin** can see profiles (name, email, KUET ID and role) so they can approve teachers and drivers, complaints so they can answer them, and drivers' assignments, requests and trip records.
- **A bus's driver** sees the waiting points ("I'm waiting here") of riders who waved at that bus.
- Nobody else. The database rules on the server block everyone else, and the data is not given to anyone outside the project.

## How long it is kept

- Your profile, places and complaints stay until you delete your account.
- A wave lasts at most 15 minutes.
- Smart-suggestion events older than 90 days are deleted automatically.
- Drivers' trip records and requests are kept as the transport office's records while the driver works for KUET.
- A bus's live position and crowd level are deleted as soon as its trip ends.
- Data saved only on your phone is removed when you delete the app.

## Deleting your account

Open **Profile > Delete account**. After you confirm with your password, the app deletes your profile (including your favourite stop and push token), your places, your complaints, any open wave, your smart-suggestion history and your login, signs you out and clears the app's settings on that phone. A driver's running trip is ended first. This cannot be undone.

If you can no longer sign in, open an issue on the project page (below) and your account will be removed by hand.

## Children

The app is meant for KUET students, teachers and drivers, and is not aimed at children.

## Changes

If this policy changes, the new version will be posted on this page with a new date.

## Contact

Questions or requests: open an issue at <https://github.com/shadowfax-505/KUETBusLive/issues>.

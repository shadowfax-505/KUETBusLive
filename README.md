# KUET Bus Live

[![Build](https://github.com/shadowfax-505/KUETBusLive/actions/workflows/build.yml/badge.svg)](https://github.com/shadowfax-505/KUETBusLive/actions/workflows/build.yml)

A real-time campus bus tracker for KUET, built with SwiftUI and Firebase.

**Author:** Muttakin Rahman Shoscho ([shadowfax-505](https://github.com/shadowfax-505))
**Course:** CSE 3218 Mobile Computing Lab, Open-Ended Project

## What it does

- **Students and teachers** sign up with their KUET details and see every bus they may ride move on a live map. Tapping a bus shows its trip, last update, crowd level and the **ETA to their stop**.
- **Bus allocation:** KUET runs *Normal* trips for students and *Special* trips (including AC buses) for teachers. Students only see and report on Normal buses. Teachers can ride any bus.
- **Schedule:** the official timetable from [kuet.ac.bd/transport](https://www.kuet.ac.bd/transport) (Sunday to Thursday and Saturday; morning, noon, afternoon and night) with the next trip you can take today.
- **Drivers** pick today's trip and a route, then tap **Start trip**. The phone shares its GPS position to Firestore every 5 seconds until **End trip**.
- **Transport admin** keeps the timetable up to date when KUET changes it (add, edit, delete trips, or reload the official one), and approves teachers and drivers.
- Riders can report a bus as **Seats available** or **Full**, and everyone sees it instantly. An optional alert fires when a bus is about 5 minutes from their stop.

## KUET ID verification

| Role | Sign-up checks | Before using the app |
| --- | --- | --- |
| Student | 7-digit roll number (batch year not in the future), `@stud.kuet.ac.bd` email that contains the roll number | Open the verification link sent to the KUET email |
| Teacher | Employee ID, KUET staff email (`kuet.ac.bd` or a department subdomain) | Verification link, then approval by the transport admin |
| Driver | Driver ID | Approval by the transport admin |
| Transport admin | Can't sign up in the app | Set up by the transport office (see below) |

The checks live in `KUETVerifier`, and `firestore.rules` enforces them on the server: nobody can make themselves an admin or approve themselves, only approved drivers can start a trip, and students can't change a teacher bus.

Debug builds also accept `@test.com` emails without a verification link, so the app can be demonstrated without real KUET mailboxes. Release builds don't.

**Making an admin:** sign up normally, then in the Firebase console open **Firestore > users > (your uid)** and change `role` to `admin`.

## Course topics used

| Topic | Where |
| --- | --- |
| Optionals, `guard let`, `??` | `AppUser.favoriteStop`, `Bus.allocation`, `DriverViewModel`, `BusDetailView` |
| `enum` + `switch` | `UserRole`, `BusAudience`, `TripDays`, `TripPeriod`, `CrowdLevel`, `KUETVerifier.validate`, `ContentView` |
| Closures / completion handlers | `AuthViewModel`, `ETAService`, snapshot listeners, `filter` / `sorted` / `map` in `ScheduleViewModel` |
| Struct vs class, computed and `static` properties | Models are structs; view models are classes; `BusSchedule.isUpcoming`, `KUETVerifier` |
| Protocols and the delegate pattern | `LocationUpdateDelegate`, `CLLocationManagerDelegate`, `UNUserNotificationCenterDelegate` |
| `@State`, `@Binding` | Forms; `RolePicker`, `DaysPicker`, `AudiencePicker`, `SchedulePicker`, `ArrivalAlertToggle` |
| `NavigationStack`, `NavigationLink`, `.navigationDestination`, `TabView`, `.sheet` | Map to Bus Detail, Routes, schedule editor |
| Firebase Auth | `AuthViewModel`: sign up, sign in, email verification |
| Firestore add / read / update / delete | Profiles, trips, routes, buses; batch write in `loadOfficialTimetable`; approvals |
| JSON parsing | `ETAService` + `RouteResponse` (OSRM REST API), `Timetable` (`kuet_schedule.json`) |
| `onAppear` / `onDisappear` | Listeners in `LiveMapView`, `SchedulesView`, `ApprovalsView`, `RoutesListView`, `DriverHomeView` |
| MapKit, CoreLocation, local notifications | `LiveMapView`, `LocationManager`, `NotificationManager` |

## Firestore data

| Collection | Document ID | Fields |
| --- | --- | --- |
| `users` | Auth uid | `name`, `email`, `role`, `kuetId`, `isApproved`, `favoriteStopName`, `favoriteStopLat`, `favoriteStopLng` |
| `schedules` | auto | `tripName`, `audience`, `days`, `period`, `campusTime`, `spot`, `spotTime`, `remarks` |
| `routes` | auto | `name`, `stops` (array of `{name, lat, lng}`) |
| `buses` | `bus-<schedule id>` | `number`, `routeId`, `routeName`, `driverId`, `lat`, `lng`, `updatedAt`, `crowd`, `audience`, `scheduleId` |

## Setup

1. Clone the repository and open `KUETBusLive.xcodeproj` in Xcode 26 or later. Xcode resolves the Firebase packages (**FirebaseAuth**, **FirebaseFirestore**) from `Package.resolved` on first open.
2. `GoogleService-Info.plist` is not in the repository because it holds the Firebase project keys. In the [Firebase console](https://console.firebase.google.com/), create a project, add an iOS app with the bundle ID `KUETBusLive` (or change the bundle ID in the target to match yours), download your own `GoogleService-Info.plist` and put it in the `KUETBusLive/` folder next to `KUETBusLiveApp.swift`.
3. In Firebase: enable **Authentication > Email/Password**, create a **Firestore** database, and deploy the rules with `firebase deploy --only firestore:rules` (update `.firebaserc` with your project ID first).
4. In the target's **Signing & Capabilities**, choose your team. Keychain Sharing and the location usage text are already set in the project.
5. Run the app, sign up, make that account an admin (see above), then tap **Load official KUET timetable** in Schedule and **Add sample KUET routes** in Routes.
6. Sign up a driver and approve them in **Approvals**.

The deployment target is iOS 17.0 (the new `Map` API needs it). If Xcode reports concurrency errors, set **Build Settings > Swift Language Version** to **Swift 5**.

## Demo with two simulators

1. Run the app on one simulator and sign in as an approved **driver**. Pick a trip and tap **Start trip**.
2. Choose a second simulator in Xcode and run again. Sign in as a **student**, set a stop in **Routes**, and open the **Map**.
3. Move the driver simulator along a route from Terminal:

   ```
   xcrun simctl list devices booted
   xcrun simctl location <driver-simulator-id> start --speed=12 22.8999,89.5024 22.8660,89.5170 22.8170,89.5440
   ```

   Stop it with `xcrun simctl location <driver-simulator-id> clear`. The coordinates are approximate points from KUET to Sonadanga.

The ETA uses the public OSRM demo server (`router.project-osrm.org`), which needs no key and has fair-use limits, so the app asks at most every 30 seconds per bus.

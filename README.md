# KUET Bus Live

[![Build](https://github.com/shadowfax-505/KUETBusLive/actions/workflows/build.yml/badge.svg)](https://github.com/shadowfax-505/KUETBusLive/actions/workflows/build.yml)
![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-yellow)

**See your campus bus move on a map, know exactly when it reaches your stop, and never chase the wrong bus again.**

**Author:** Muttakin Rahman Shoscho ([shadowfax-505](https://github.com/shadowfax-505))
**Course:** CSE 3218 Mobile Computing Lab, KUET (Open-Ended Project)

---

## Contents

1. [Why I built this](#why-i-built-this)
2. [What the app does](#what-the-app-does)
3. [Who uses it](#who-uses-it)
4. [The big picture](#the-big-picture)
5. [How the code is organised](#how-the-code-is-organised)
6. [Signing up and KUET ID verification](#signing-up-and-kuet-id-verification)
7. [Which bus can I take?](#which-bus-can-i-take)
8. [Live tracking, step by step](#live-tracking-step-by-step)
9. [How the ETA is calculated](#how-the-eta-is-calculated)
10. [The arrival alert](#the-arrival-alert)
11. [The bus timetable](#the-bus-timetable)
12. [Crowd reports](#crowd-reports)
13. [Screens and navigation](#screens-and-navigation)
14. [Listeners, onAppear and onDisappear](#listeners-onappear-and-ondisappear)
15. [Firestore data model](#firestore-data-model)
16. [Security rules](#security-rules)
17. [Course topics used](#course-topics-used)
18. [Continuous integration](#continuous-integration)
19. [Setup](#setup)
20. [Running a demo with two simulators](#running-a-demo-with-two-simulators)
21. [Limitations and ideas for later](#limitations-and-ideas-for-later)

---

## Why I built this

Anyone who has waited for a KUET bus knows the feeling. You leave the hall early, stand at Fulbarigate or Shibbari, and keep looking down the road without knowing whether the bus left five minutes ago or hasn't left campus yet. The timetable on the website helps, but it doesn't tell you where the bus is *right now*, whether it's packed, or whether that bus is even one you're allowed to ride.

KUET Bus Live answers those three questions:

- **Where is my bus?** The driver's phone shares its location, and everyone sees it move live.
- **When will it reach me?** The app asks a routing server for the real driving time to your stop.
- **Can I get on it?** Student buses and teacher buses are kept separate, so you only see the buses you can actually take.

---

## What the app does

| Feature | In one line |
| --- | --- |
| 🗺️ Live map | Every running bus moves on the map as the driver drives. |
| ⏱️ ETA to your stop | "6 min, 5.3 km" to the stop you picked, refreshed as the bus moves. |
| 🔔 Arrival alert | A notification when your bus is about 5 minutes away. |
| 📅 Official timetable | All KUET trips (Sunday to Thursday and Saturday), with the next bus you can take today. |
| 🎓 Bus allocation | Students see only *Normal* (student) buses. Teachers can ride any bus. |
| 🪪 KUET ID verification | Roll number or employee ID, KUET email, email link and admin approval. |
| 👥 Crowd reports | One tap to say "Seats available" or "Full", and everyone sees it instantly. |
| 🛠️ Transport admin | Edits the timetable when KUET changes it, and approves teachers and drivers. |

---

## Who uses it

There are four kinds of people in the app. Each one sees a different set of screens.

```mermaid
flowchart LR
    S["🎓 Student"]
    T["👩‍🏫 Teacher"]
    D["🚌 Driver"]
    A["🛠️ Transport admin"]

    S -->|"sees Normal buses only"| MAP["Live map + ETA"]
    T -->|"sees every bus"| MAP
    S --> SCH["Timetable"]
    T --> SCH
    S --> CR["Crowd reports"]
    T --> CR

    D -->|"shares GPS every 5 s"| TRIP["Start / end a trip"]

    A --> EDIT["Edit timetable"]
    A --> APP["Approve teachers and drivers"]
    A --> ROUTES["Manage routes"]
```

| Role | How they get in | What they do |
| --- | --- | --- |
| **Student** | Roll number + `@stud.kuet.ac.bd` email + email link | Track student buses, set a stop, get ETAs and alerts, report crowd |
| **Teacher** | Employee ID + KUET staff email + email link + admin approval | Same as students, but for every bus |
| **Driver** | Driver ID + admin approval | Pick today's trip and share the bus location |
| **Transport admin** | Set up by the transport office in Firebase | Keep the timetable up to date, approve accounts, add routes |

---

## The big picture

The app talks to three outside services: **Firebase Authentication** for accounts, **Cloud Firestore** as a live database, and the **OSRM routing API** for travel times. Nothing runs on a server of my own. The driver's phone writes, and every rider's phone listens.

```mermaid
flowchart TB
    subgraph Phones["📱 iPhones running KUET Bus Live"]
        DP["Driver's phone<br/>CoreLocation GPS"]
        RP["Student / teacher phone<br/>MapKit map"]
        AP["Admin's phone<br/>timetable editor"]
    end

    subgraph Firebase["☁️ Firebase"]
        AUTH["Authentication<br/>email + password,<br/>email verification"]
        FS[("Cloud Firestore<br/>users · buses · schedules · routes")]
        RULES["Security rules"]
    end

    OSRM["🛣️ OSRM routing API<br/>router.project-osrm.org"]

    DP -- "position every 5 s" --> FS
    FS -- "real-time snapshot listener" --> RP
    AP -- "add / edit / delete trips,<br/>approve accounts" --> FS
    FS -- "live timetable" --> RP
    RP -- "GET /route (bus → my stop)" --> OSRM
    OSRM -- "JSON: duration, distance" --> RP
    DP & RP & AP -. "sign in" .-> AUTH
    RULES -. "guards every read and write" .- FS
```

The key idea is that **nobody polls**. Firestore pushes every change to the phones that are listening, so a bus moving on the driver's phone shows up on everyone's map about a second later.

---

## How the code is organised

The app follows **MVVM** (Model, View, ViewModel), the same pattern used in the lab classes.

- **Models** are plain `struct`s that match Firestore documents.
- **ViewModels** are `ObservableObject` classes. They talk to Firebase and publish data with `@Published`.
- **Views** are SwiftUI screens. They only show what the view model publishes.
- **Services** wrap system frameworks: GPS, notifications, the routing API, and the KUET ID rules.

```mermaid
flowchart LR
    subgraph Views
        LV[LoginView / SignUpView]
        MV[LiveMapView]
        BD[BusDetailView]
        SV[SchedulesView]
        DH[DriverHomeView]
        AV[ApprovalsView]
    end

    subgraph ViewModels
        AUVM[AuthViewModel]
        BVM[BusViewModel]
        SVM[ScheduleViewModel]
        DVM[DriverViewModel]
        ADVM[AdminViewModel]
        RVM[RouteViewModel]
    end

    subgraph Services
        LM[LocationManager]
        ETA[ETAService]
        NM[NotificationManager]
        KV[KUETVerifier]
    end

    subgraph Models
        U[AppUser]
        B[Bus]
        BS[BusSchedule]
        BR[BusRoute]
    end

    LV --> AUVM --> KV
    MV --> BVM
    BD --> BVM
    BVM --> ETA
    BVM --> NM
    SV --> SVM
    DH --> DVM --> LM
    AV --> ADVM
    AUVM & BVM & SVM & DVM & ADVM & RVM --> Models
```

```
KUETBusLive/
├── KUETBusLiveApp.swift        App entry, configures Firebase
├── ContentView.swift           Picks the first screen (login, verify, waiting, or the role's tabs)
├── Models/
│   ├── AppUser.swift           User profile + UserRole enum
│   ├── Bus.swift               A running bus + CrowdLevel enum
│   ├── BusRoute.swift          A route and its stops
│   ├── BusSchedule.swift       One timetable trip + BusAudience, TripDays, TripPeriod
│   ├── Timetable.swift         Reads kuet_schedule.json
│   └── RouteResponse.swift     OSRM JSON response
├── Services/
│   ├── LocationManager.swift   GPS, with a custom delegate protocol
│   ├── ETAService.swift        Calls the OSRM REST API
│   ├── NotificationManager.swift  Local arrival alerts
│   └── KUETVerifier.swift      Roll number and KUET email rules
├── ViewModels/                 Auth, Bus, Driver, Route, Schedule, Admin
├── Views/                      All SwiftUI screens
└── Resources/
    └── kuet_schedule.json      Official KUET timetable
```

---

## Signing up and KUET ID verification

When you create an account, the app checks your KUET details **before** it creates anything in Firebase. `KUETVerifier.validate` uses a `switch` on your role:

```mermaid
flowchart TD
    START(["Tap Sign Up"]) --> ROLE{"Which role?"}

    ROLE -->|Student| R1{"Roll number is<br/>7 digits, e.g. 2107001?"}
    R1 -->|no| E1["❌ Roll number must be 7 digits"]
    R1 -->|yes| R2{"Email ends with<br/>@stud.kuet.ac.bd?"}
    R2 -->|no| E2["❌ Use your KUET student email"]
    R2 -->|yes| R3{"Roll number appears<br/>inside the email?"}
    R3 -->|no| E3["❌ Roll doesn't match the email"]
    R3 -->|yes| OK

    ROLE -->|Teacher| T1{"Employee ID given and<br/>email ends with kuet.ac.bd?"}
    T1 -->|no| E4["❌ Use your KUET staff email"]
    T1 -->|yes| OK

    ROLE -->|Driver| D1{"Driver ID given?"}
    D1 -->|no| E5["❌ Enter your driver ID"]
    D1 -->|yes| OK

    OK["✅ Create Firebase account<br/>and save profile in Firestore"] --> MAIL{"Student or teacher?"}
    MAIL -->|yes| LINK["📧 Firebase sends a<br/>verification link"]
    MAIL -->|no| DONE(["Signed in"])
    LINK --> DONE
```

Signing up isn't the end of it. Every time the app starts, `ContentView` decides which screen you should see. Because the profile is loaded with a **live listener**, the moment the admin approves you, your phone moves past the waiting screen by itself. You don't need to sign out and back in.

```mermaid
stateDiagram-v2
    [*] --> SignedOut
    SignedOut --> LoadingProfile: sign in / sign up
    LoadingProfile --> VerifyEmail: student or teacher,<br/>email not verified
    VerifyEmail --> LoadingProfile: tapped "I've verified my email"
    LoadingProfile --> WaitingForApproval: teacher or driver,<br/>not approved yet
    WaitingForApproval --> RoleScreens: admin taps Approve<br/>(arrives through the listener)
    LoadingProfile --> RoleScreens: everything checks out

    state RoleScreens {
        [*] --> Which
        Which --> StudentTabs: student / teacher
        Which --> DriverHome: driver
        Which --> AdminTabs: admin
    }

    RoleScreens --> SignedOut: Sign Out
```

> **Demo accounts:** debug builds also accept `@test.com` emails and skip the email link, so the app can be shown in the lab without real KUET mailboxes. Release builds never accept them.

---

## Which bus can I take?

KUET runs two kinds of trips:

- **Normal** trips (Normal-1, Normal-2) are **student buses**.
- **Special** trips (Special-1, Special-1 (AC)) are **teacher buses**.

Teachers can get on any bus. Students can only get on student buses. The whole rule is one small function, `BusAudience.canBoard(_:)`:

```swift
func canBoard(_ role: UserRole) -> Bool {
    switch role {
    case .teacher, .driver, .admin:
        return true
    case .student:
        return self == .student
    }
}
```

```mermaid
flowchart LR
    BUS["A bus is running"] --> Q{"Who is looking?"}
    Q -->|Teacher| YES1["✅ Shown on map<br/>(purple ring if it's a teacher bus)"]
    Q -->|Student| Q2{"Normal or Special?"}
    Q2 -->|Normal| YES2["✅ Shown on map<br/>(blue ring)"]
    Q2 -->|Special| NO["🚫 Hidden from map and timetable"]
```

The same rule is used in four places, so it can't be dodged:

1. `BusViewModel` filters the buses on the map.
2. `ScheduleViewModel` filters the timetable.
3. `BusDetailView` hides the crowd buttons if you can't ride that bus.
4. `firestore.rules` rejects a crowd report from a student on a teacher bus, even if someone edits the app.

---

## Live tracking, step by step

This is the heart of the app. It uses the **delegate pattern** twice: Apple's `CLLocationManagerDelegate`, and my own `LocationUpdateDelegate` protocol, so the GPS code stays separate from the Firebase code.

```mermaid
sequenceDiagram
    autonumber
    actor Driver
    participant DH as DriverHomeView
    participant DVM as DriverViewModel
    participant LM as LocationManager
    participant GPS as CoreLocation
    participant FS as Firestore
    participant BVM as BusViewModel<br/>(rider's phone)
    participant Map as LiveMapView

    Driver->>DH: picks trip + route, taps Start trip
    DH->>DVM: startTrip(schedule, route, driverId)
    DVM->>LM: start()
    LM->>GPS: startUpdatingLocation()

    loop every time the bus moves 10 m
        GPS-->>LM: didUpdateLocations (CLLocationManagerDelegate)
        LM-->>DVM: didUpdateLocation (LocationUpdateDelegate)
        alt first position of the trip
            DVM->>FS: setData: create buses/bus-{trip}
        else 5 s since the last write
            DVM->>FS: updateData: lat, lng, updatedAt
        end
        FS-->>BVM: snapshot listener fires
        BVM->>BVM: keep only buses this rider can board
        BVM-->>Map: @Published buses changes
        Map->>Map: bus icon moves
    end

    Driver->>DH: taps End trip
    DH->>DVM: endTrip()
    DVM->>LM: stop()
    DVM->>FS: delete buses/bus-{trip}
    FS-->>BVM: bus removed
    BVM-->>Map: bus disappears
```

Two small choices here are worth calling out:

- **Writes are limited to one every 5 seconds.** GPS can fire many times a second, and writing every update would waste battery and Firestore quota.
- **Later updates use `updateData`, not `setData`.** That way only the position changes, and crowd reports that riders sent in the meantime aren't overwritten.

---

## How the ETA is calculated

Straight-line distance would be wrong in Khulna's roads, so the app asks **OSRM**, a free routing server, for the actual driving time. The answer comes back as JSON and is decoded with `Codable`.

```mermaid
sequenceDiagram
    participant BVM as BusViewModel
    participant ETA as ETAService
    participant OSRM as router.project-osrm.org
    participant UI as BusDetailView

    BVM->>BVM: has 30 s passed since the last ETA for this bus?
    BVM->>ETA: fetchETA(from: bus, to: my stop)
    ETA->>OSRM: GET /route/v1/driving/{bus lng,lat}#59;{stop lng,lat}
    OSRM-->>ETA: {"routes":[{"duration": 362.4, "distance": 5310.7}]}
    ETA->>ETA: JSONDecoder → RouteResponse
    ETA-->>BVM: completion(RouteInfo) on the main thread
    BVM->>BVM: etaText[busId] = "6 min, 5.3 km"
    BVM-->>UI: @Published update
```

The response is mapped to two small structs:

```swift
struct RouteResponse: Codable {
    let routes: [RouteInfo]
}

struct RouteInfo: Codable {
    let duration: Double   // seconds
    let distance: Double   // metres
}
```

OSRM's public server has fair-use limits, so the app asks **at most once every 30 seconds per bus**, unless you open the bus screen or change your stop.

---

## The arrival alert

If you turn on **"Alert me 5 min before my bus arrives"** in your profile, every new ETA is checked against that limit. The alert fires once per bus, so it won't keep buzzing.

```mermaid
flowchart LR
    NEW["New ETA arrives"] --> ON{"Alerts turned on?"}
    ON -->|no| SKIP["Do nothing"]
    ON -->|yes| CLOSE{"≤ 5 minutes away?"}
    CLOSE -->|no| SKIP
    CLOSE -->|yes| SENT{"Already alerted<br/>for this bus?"}
    SENT -->|yes| SKIP
    SENT -->|no| FIRE["🔔 Local notification:<br/>'Normal-1 · Rupsha is almost here'"]
```

`NotificationManager` is the `UNUserNotificationCenterDelegate`, so the banner shows even while the app is open.

---

## The bus timetable

The official timetable is on [kuet.ac.bd/transport](https://www.kuet.ac.bd/transport), and it changes from time to time. So it isn't hard-coded into the screens. It lives in Firestore, where the transport admin can change it from inside the app, and every phone sees the change straight away.

The first copy ships with the app as `kuet_schedule.json`: 31 trips across Sunday to Thursday and Saturday, split into morning, noon, afternoon and night.

```mermaid
flowchart TB
    WEB["kuet.ac.bd/transport"] -->|"copied into"| JSON["kuet_schedule.json<br/>(in the app bundle)"]
    JSON -->|"Admin taps 'Load official KUET timetable'<br/>JSONDecoder → [TimetableRow]"| BATCH["One Firestore batch write<br/>(delete old trips, add 31 new ones)"]
    BATCH --> COL[("schedules collection")]

    ADMIN["🛠️ Admin edits a trip<br/>(e.g. KUET moves 5:10 PM to 5:20 PM)"] -->|"setData"| COL

    COL -->|"snapshot listener"| P1["🎓 Student's phone<br/>Normal trips only"]
    COL -->|"snapshot listener"| P2["👩‍🏫 Teacher's phone<br/>all trips"]
    COL -->|"snapshot listener"| P3["🚌 Driver's phone<br/>today's trips to pick from"]
```

Each trip looks like this in the JSON file:

```json
{
  "tripName": "Normal-1",
  "days": "sunToThu",
  "period": "morning",
  "campusTime": "06:30",
  "spot": "Rupsha",
  "spotTime": "07:10",
  "remarks": "Will back via Royal Mor & Ferighat"
}
```

There's no `audience` field in the file. The app works it out from the name: anything starting with "Special" is a teacher bus. The admin's editor does the same, so typing "Special-2" flips the badge to *Teacher bus* automatically.

The timetable screen also shows **"Next bus you can take today"**. It checks today's weekday (Sunday to Thursday, Saturday, or no buses on Friday), compares the times with the clock, and only looks at trips your role can ride.

---

## Crowd reports

Anyone allowed on a bus can tap **Seats available** or **Full**. The report is a single field update on the bus document, so it reaches every other rider almost instantly, and the bus icon on the map changes colour.

```mermaid
sequenceDiagram
    actor Rider as Rider A
    participant FS as Firestore
    actor Other as Rider B
    Rider->>FS: updateData(["crowd": "full"])
    Note over FS: Rule check: only the crowd field changed,<br/>and Rider A is allowed on this bus
    FS-->>Other: listener fires
    Other->>Other: bus icon turns 🔴, "Full" shown
```

| Crowd level | Map colour |
| --- | --- |
| No report yet | ⚪ grey |
| Seats available | 🟢 green |
| Full | 🔴 red |

---

## Screens and navigation

```mermaid
flowchart TD
    CV{"ContentView"} -->|signed out| LOGIN["LoginView"]
    LOGIN -->|NavigationLink| SIGNUP["SignUpView"]
    CV -->|email not verified| VERIFY["VerifyEmailView"]
    CV -->|waiting for admin| WAIT["PendingApprovalView"]

    CV -->|student / teacher| ST["StudentTabView"]
    ST --> T1["🗺️ Map<br/>LiveMapView"]
    T1 -->|tap a bus| BUS["BusDetailView<br/>ETA · crowd · allocation"]
    ST --> T2["📅 Schedule<br/>SchedulesView"]
    ST --> T3["📍 Routes<br/>RoutesListView"]
    T3 --> RD["RouteDetailView<br/>'Set as my stop'"]
    ST --> T4["👤 Profile<br/>ProfileView"]

    CV -->|driver| DR["DriverHomeView<br/>pick trip · Start / End trip"]

    CV -->|admin| AT["AdminTabView"]
    AT --> A1["📅 Schedule + editor sheet"]
    AT --> A2["✅ Approvals"]
    AT --> A3["🗺️ Map"]
    AT --> A4["📍 Routes"]
    AT --> A5["👤 Profile"]
```

---

## Listeners, onAppear and onDisappear

Every live list in the app follows the same pattern: start listening when the screen appears, and remove the listener when it goes away. This keeps the app from downloading updates for screens nobody is looking at.

```mermaid
sequenceDiagram
    participant View as SchedulesView
    participant VM as ScheduleViewModel
    participant FS as Firestore

    View->>VM: .onAppear → startListening()
    VM->>FS: addSnapshotListener
    FS-->>VM: current trips
    FS-->>VM: ...every later change
    View->>VM: .onDisappear → stopListening()
    VM->>FS: listener.remove()
```

| Screen | What it listens to |
| --- | --- |
| `LiveMapView` | running buses |
| `SchedulesView` | the timetable |
| `RoutesListView` | routes and stops |
| `DriverHomeView` | routes and today's trips (also ends the trip if you leave) |
| `ApprovalsView` | teachers and drivers waiting for approval |
| `AuthViewModel` | your own profile (so approval shows up instantly) |

---

## Firestore data model

```mermaid
erDiagram
    USERS {
        string id "Auth uid"
        string name
        string email
        string role "student, teacher, driver, admin"
        string kuetId "roll / employee / driver ID"
        bool isApproved
        string favoriteStopName
        double favoriteStopLat
        double favoriteStopLng
    }
    SCHEDULES {
        string id "auto"
        string tripName "Normal-1, Special-1 (AC)"
        string audience "student or teacher"
        string days "sunToThu or saturday"
        string period "morning, noon, afternoon, night"
        string campusTime "06:30"
        string spot "Rupsha"
        string spotTime "07:10"
        string remarks
    }
    ROUTES {
        string id "auto"
        string name
        array stops "name, lat, lng"
    }
    BUSES {
        string id "bus-{scheduleId}"
        string number "Normal-1 · Rupsha"
        string routeId
        string routeName
        string driverId
        double lat
        double lng
        timestamp updatedAt
        string crowd "unknown, seats, full"
        string audience
        string scheduleId
    }

    USERS ||--o{ BUSES : "a driver runs"
    SCHEDULES ||--o| BUSES : "a trip becomes"
    ROUTES ||--o{ BUSES : "a bus follows"
```

A `buses` document only exists while a trip is running. Ending the trip deletes it, which is how the bus disappears from every map.

---

## Security rules

The checks in the app are friendly, but the real protection is `firestore.rules`, which Firebase runs on the server for every request.

```mermaid
flowchart TB
    REQ["Read / write request"] --> SIGNED{"Signed in?"}
    SIGNED -->|no| DENY["🚫 Denied"]
    SIGNED -->|yes| WHAT{"Which collection?"}

    WHAT -->|users| U{"Own profile?"}
    U -->|"create"| UC["role must be student / teacher / driver,<br/>only students start approved"]
    U -->|"update"| UU["can't change role, isApproved,<br/>kuetId or email (admin can)"]

    WHAT -->|"schedules / routes"| SR["everyone reads,<br/>only admin writes"]

    WHAT -->|buses| B{"What kind of write?"}
    B -->|create| BC["only an approved driver,<br/>as themselves"]
    B -->|"update position"| BU["only the bus's own driver"]
    B -->|"update crowd"| BCR["only the crowd field,<br/>and only riders allowed on that bus"]
    B -->|delete| BD["the bus's driver or admin"]
```

In plain words: nobody can make themselves an admin, nobody can approve themselves, only approved drivers can put a bus on the map, and a student can't touch a teacher bus.

---

## Course topics used

| Topic | Where to find it |
| --- | --- |
| Optionals, `guard let`, `??` | `AppUser.favoriteStop`, `Bus.allocation`, `DriverViewModel.startTrip`, `BusDetailView` |
| `enum` + `switch` | `UserRole`, `BusAudience`, `TripDays`, `TripPeriod`, `CrowdLevel`, `KUETVerifier.validate`, `ContentView` |
| Closures and completion handlers | `AuthViewModel`, `ETAService.fetchETA`, every snapshot listener, `filter` / `sorted` / `map` |
| Structs vs classes, computed and `static` properties | Models are structs, view models are classes; `BusSchedule.isUpcoming`, `ETAService.baseURL` |
| Protocols and the delegate pattern | `LocationUpdateDelegate` (my own), `CLLocationManagerDelegate`, `UNUserNotificationCenterDelegate` |
| `@State`, `@Binding` | `RolePicker`, `DaysPicker`, `AudiencePicker`, `SchedulePicker`, `ArrivalAlertToggle` |
| `@StateObject`, `@ObservedObject`, `@EnvironmentObject`, `@AppStorage` | View models, shared `AuthViewModel`, the alert toggle |
| Navigation | `NavigationStack`, `NavigationLink`, `.navigationDestination`, `TabView`, `.sheet` |
| Firebase Authentication | Sign up, sign in, sign out, email verification |
| Firestore add / read / update / delete | Profiles, trips, routes, buses, approvals, and one batch write |
| JSON parsing | `ETAService` + `RouteResponse` (OSRM REST API) and `Timetable` (`kuet_schedule.json`) |
| `onAppear` / `onDisappear` | Every listener screen in the table above |
| MapKit, CoreLocation, local notifications | `LiveMapView`, `LocationManager`, `NotificationManager` |

---

## Continuous integration

Every push to `main` and every pull request is built on GitHub Actions, so a broken build shows up straight away.

```mermaid
flowchart LR
    PUSH["git push / pull request"] --> GA["GitHub Actions<br/>macOS runner"]
    GA --> X["Select Xcode"]
    X --> PL["Write a placeholder<br/>GoogleService-Info.plist"]
    PL --> SPM["Resolve Firebase packages<br/>(cached)"]
    SPM --> BUILD["xcodebuild for the<br/>iOS Simulator, no signing"]
    BUILD --> BADGE["✅ / ❌ build badge<br/>at the top of this page"]
```

The real `GoogleService-Info.plist` is never committed. CI only needs a placeholder to compile.

---

## Setup

1. **Clone and open.** Clone the repository and open `KUETBusLive.xcodeproj` in Xcode 26 or later. Xcode fetches the Firebase packages (**FirebaseAuth**, **FirebaseFirestore**) from `Package.resolved` the first time.
2. **Add your Firebase config.** `GoogleService-Info.plist` isn't in the repository because it holds project keys. In the [Firebase console](https://console.firebase.google.com/), create a project, add an iOS app with the bundle ID `KUETBusLive` (or change the bundle ID to match yours), download `GoogleService-Info.plist`, and put it in the `KUETBusLive/` folder next to `KUETBusLiveApp.swift`.
3. **Turn on Firebase features.** Enable **Authentication > Email/Password**, create a **Firestore** database, put your project ID in `.firebaserc`, then deploy the rules:
   ```
   firebase deploy --only firestore:rules
   ```
4. **Signing.** In the target's **Signing & Capabilities**, choose your team. Keychain Sharing and the location permission text are already set.
5. **Make an admin.** Run the app and sign up. In the Firebase console, open **Firestore > users > (your uid)** and change `role` to `admin`.
6. **Load the data.** As the admin, tap **Load official KUET timetable** in Schedule and **Add sample KUET routes** in Routes.
7. **Add a driver.** Sign up a driver on another simulator and approve them in **Approvals**.

The deployment target is iOS 17.0, because the new `Map` API needs it. If Xcode reports concurrency errors, set **Build Settings > Swift Language Version** to **Swift 5**.

---

## Running a demo with two simulators

```mermaid
flowchart LR
    subgraph SimA["Simulator A"]
        D["🚌 Driver<br/>Start trip"]
    end
    subgraph SimB["Simulator B"]
        R["🎓 Student<br/>Map + ETA"]
    end
    TERM["💻 Terminal<br/>xcrun simctl location"] -->|"fake GPS route"| D
    D -->|"Firestore"| R
```

1. Run the app on one simulator and sign in as an approved **driver**. Pick a trip and tap **Start trip**.
2. Pick a second simulator in Xcode and run again. Sign in as a **student**, set a stop in **Routes**, and open the **Map**.
3. Make the driver's simulator "drive" from KUET towards Sonadanga:

   ```
   xcrun simctl list devices booted
   xcrun simctl location <driver-simulator-id> start --speed=12 22.8999,89.5024 22.8660,89.5170 22.8170,89.5440
   ```

   Stop it with `xcrun simctl location <driver-simulator-id> clear`. The coordinates are approximate.

Things worth showing in a demo: start a **Special** trip and notice the student can't see it while a teacher can; tap **Full** on one phone and watch the icon turn red on the other; change a trip time as admin and watch the timetable update on the student's phone.

---

## Limitations and ideas for later

- The routes and stop coordinates are approximate. A future version could let the admin draw routes on the map.
- The public OSRM server is meant for light use. A real deployment would host its own OSRM instance.
- Location sharing only runs while the driver's app is open. Background location would need extra permission and battery care.
- Students who belong to a specific route could get a personal "my bus" view and push notifications from a server.

---

Made with care at KUET by **Muttakin Rahman Shoscho**.

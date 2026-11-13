# Data model

Everything KUET Bus Live keeps in Cloud Firestore, written so that an Android (or web) version can read and write the same documents. Every field is a plain Firestore type: string, number, boolean, timestamp, array or map. Nothing is stored in an iOS-only format.

The rules that protect each collection live in [`firestore.rules`](../firestore.rules) and are tested in [`firestore-tests/rules.test.js`](../firestore-tests/rules.test.js). The "Who can do what" lines below summarise them.

## Shared constants

Use exactly these strings on every platform.

| Name | Values |
|---|---|
| Role (`users.role`) | `student`, `teacher`, `driver`, `admin` |
| Bus audience (`audience`) | `student`, `teacher` (students may ride only `student` buses; teachers ride any) |
| Crowd level (`buses.crowd`) | `unknown`, `seats`, `full` |
| Trip days (`schedules.days`) | `sunToThu`, `saturday` (no buses on Friday) |
| Trip period (`schedules.period`) | `morning`, `noon`, `afternoon`, `night` |
| Complaint category | `late`, `driverBehaviour`, `overcrowding`, `busCondition`, `app`, `other` |
| Complaint status | `open`, `inReview`, `resolved` |
| Place kind | `home`, `tuition`, `other` |
| Ride event kind | `followed`, `alerted`, `waved`, `boarded` |
| Day type (ride history) | `sunToThu`, `saturday`, `friday` |
| Absence status | `open`, `covered`, `cancelled` |
| Push topic for a route | `route-<routeId>` |

**Dates for assignments** are days in Khulna (time zone `Asia/Dhaka`) written `yyyy-MM-dd`, e.g. `2026-11-10`. Text comparison of these strings gives the right order. **Times in the timetable** are 24-hour `HH:mm` strings, e.g. `06:30`. **Coordinates** are `lat` / `lng` numbers in degrees (WGS 84).

## `users/{uid}`

One profile per Firebase Auth account. The document ID is the Auth uid.

| Field | Type | Notes |
|---|---|---|
| `name` | string | 1–100 characters |
| `email` | string | must equal the login email when created |
| `role` | string | see Role |
| `kuetId` | string | roll number (students), employee ID (teachers), driver ID (drivers) |
| `isApproved` | boolean | students start `true`; teachers and drivers wait for the admin |
| `active` | boolean, optional | `false` once the admin deactivates the account (a driver who left). Missing means active |
| `favoriteStopName` | string, optional | English stop name, the stop's identity |
| `favoriteStopLat`, `favoriteStopLng` | number, optional | |
| `fcmToken` | string, optional | push token |

Who can do what: you read and create your own profile; you may change only `name`, the favourite stop fields and `fcmToken`. The admin reads and changes every profile. You or the admin may delete it.

### `users/{uid}/places/{p1…p5}`: My places

| Field | Type | Notes |
|---|---|---|
| `label` | string | 1–40 characters, e.g. "Home" |
| `kind` | string | see Place kind |
| `lat`, `lng` | number | where the rider dropped the pin (the snap onto a route is worked out on the phone) |
| `createdAt` | timestamp | |

At most five: the document ID must be `p1` … `p5`. Only the owner reads or writes.

### `users/{uid}/rideHistory/{eventId}`: optional backup of smart suggestions

Only written when the rider turns on "Keep my ride history in my account". Same fields as the event kept on the phone:

| Field | Type |
|---|---|
| `id` | string (same as the document ID) |
| `kind` | string, see Ride event kind |
| `tripTitle` | string, e.g. `Normal-2 · Rupsha` |
| `routeId` | string |
| `boardingKey` | string, `stop:<name>` or `place:<p1…p5>` |
| `boardingName` | string |
| `dayType` | string, see Day type |
| `minuteOfDay` | integer 0–1439 |
| `date` | timestamp |

Only the owner reads, creates and deletes.

## `schedules/{id}`: the timetable

| Field | Type | Notes |
|---|---|---|
| `tripName` | string | `Normal-1`, `Special-1 (AC)`; also the fleet bus name |
| `audience` | string | |
| `days` | string | |
| `period` | string | |
| `campusTime` | string | `HH:mm`, leaves KUET |
| `spot` | string | starting place in the city, English |
| `spotBn` | string, optional | Bangla name of the spot |
| `spotTime` | string | `HH:mm`, leaves the spot |
| `remarks` | string | |

Everyone signed in reads; only the admin writes.

## `routes/{id}`

| Field | Type | Notes |
|---|---|---|
| `name` | string | e.g. `KUET to Sonadanga` |
| `nameBn` | string, optional | |
| `stops` | array of maps | each `{name, nameBn?, lat, lng}` in driving order, KUET first |

Everyone signed in reads; only the admin writes. The road path between stops is not stored; each app asks the OSRM server (`https://router.project-osrm.org/route/v1/driving/…`) for it.

## `announcements/{id}`

| Field | Type |
|---|---|
| `title` | string, 1–200 characters |
| `body` | string, 1–5000 characters |
| `createdAt` | timestamp |
| `postedBy` | string (the admin's name) |
| `routeName` | string, optional |

Everyone signed in reads; only the admin writes. Whether a rider has read or hidden an announcement is kept on their phone, not here.

## `fleet/{busId}`: buses and who drives them

The document ID is made from the name: lower case, anything that isn't a letter or digit becomes `-` (`Normal-1` → `normal-1`, `Special-1 (AC)` → `special-1-ac`).

| Field | Type | Notes |
|---|---|---|
| `name` | string | same as `schedules.tripName` |
| `defaultDriverId` | string or null | the regular driver |
| `cover` | map, optional | a temporary replacement, see below |
| `tripDrivers` | map, optional | a different driver for single trips: `schedules` document ID → driver uid. Missing or empty for most buses |

`cover` map:

| Field | Type | Notes |
|---|---|---|
| `driverId` | string | |
| `fromDate`, `untilDate` | string | first and last day, `yyyy-MM-dd` in Dhaka, inclusive |
| `start` | timestamp | 00:00 on `fromDate` in Dhaka |
| `end` | timestamp | 00:00 on the day after `untilDate` in Dhaka |
| `reason` | string | |
| `setBy` | string | the admin's uid |

**Who drives today:** the cover driver if today is between `fromDate` and `untilDate`, otherwise `defaultDriverId`, otherwise nobody. The rules use `start ≤ now < end` for the same check.

**Who drives one trip:** the driver in `tripDrivers[scheduleId]` if there is one, otherwise whoever drives the bus today (above). A trip driver comes first even while a cover is active. Every client must resolve it in this order; the rules do the same when a trip starts.

Everyone signed in reads; only the admin writes. `tripDrivers`, when present, must be a map.

## `buses/{busId}`: live trips

Exists only while a trip runs. The ID is `bus-<fleetBusId>`, so a fleet bus can have only one live trip.

| Field | Type | Notes |
|---|---|---|
| `number` | string | `Normal-2 · Rupsha` (trip name · spot) |
| `routeId`, `routeName` | string | |
| `driverId` | string | |
| `fleetBusId` | string | |
| `scheduleId` | string | |
| `audience` | string | |
| `lat`, `lng` | number | |
| `heading` | number, optional | degrees from north |
| `speed` | number, optional | metres per second |
| `updatedAt` | timestamp | |
| `crowd` | string | |

Who can do what: an approved, active driver creates it, as themselves, only for a trip (`scheduleId`) of the fleet bus that they drive (see "Who drives one trip"). They may move it afterwards even if their cover ends during the trip, but a move changes only `lat`, `lng`, `heading`, `speed` and `updatedAt`; changing the route, trip or audience means starting the trip again, which is checked like a new trip. Riders allowed on the bus change only `crowd`. The driver or the admin deletes it (end of trip).

### `buses/{busId}/waves/{uid}`: "I'm waiting here"

| Field | Type | Notes |
|---|---|---|
| `uid` | string | same as the document ID: one wave per rider per bus |
| `label` | string | place or stop name shown to the driver |
| `lat`, `lng` | number | the point on the route where the rider waits |
| `createdAt` | timestamp | |
| `expiresAt` | timestamp | at most 20 minutes ahead (the app uses 15) |

An approved rider allowed on the bus creates their own. The rider, the bus's driver and the admin read and delete.

## `driverAbsences/{id}`: "I can't drive"

| Field | Type |
|---|---|
| `driverId`, `driverName` | string |
| `fromDate`, `untilDate` | string, `yyyy-MM-dd` |
| `reason` | string, 1–300 characters |
| `status` | string, see Absence status (created as `open`) |
| `createdAt` | timestamp |
| `coverDriverId` | string, optional, set by the admin |

A driver creates and reads their own and may withdraw it. The admin reads and updates all.

## `trips/{id}`: who drove what

| Field | Type |
|---|---|
| `driverId`, `fleetBusId`, `scheduleId`, `routeId` | string |
| `startedAt` | timestamp |
| `endedAt` | timestamp, added when the trip ends |

The driver creates it (only for a trip they drive, as for `buses`) and later adds `endedAt`. The driver reads their own; the admin reads all.

## `complaints/{id}`

| Field | Type | Notes |
|---|---|---|
| `uid`, `userName` | string | the sender |
| `userRole` | string | must match the sender's role |
| `category` | string | see Complaint category |
| `routeName`, `busName` | string, optional | |
| `tripTime` | timestamp, optional | |
| `text` | string | 1–2000 characters |
| `createdAt` | timestamp | |
| `status` | string | created as `open` |
| `readByAdmin` | boolean | created as `false` |
| `adminReply` | string, optional | |
| `repliedAt` | timestamp, optional | |

The sender creates and reads their own and can't edit it; deleting is allowed (account deletion). The admin reads all and changes only `status`, `adminReply`, `repliedAt` and `readByAdmin`.

## Kept only on the phone

These never go to Firestore: announcements read and hidden, the "Show news" switch, the app passcode hash (Keychain), Face ID and alert settings, the chosen boarding point, the current wave, the smart-suggestions history and learned delays (unless the backup is on), and the widget / Live Activity data.

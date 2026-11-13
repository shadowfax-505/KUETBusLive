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
| `crowd` | string | `full` while a rider on board reported it overcrowded |
| `crowdAt` | timestamp, optional | server time of that report; shown as "Crowded" for 10 minutes |
| `reportLat`, `reportLng` | number, optional | where the reporting rider was; must be within 0.001° of the bus |

Who can do what: an approved, active driver creates it, as themselves, only for a trip (`scheduleId`) of the fleet bus that they drive (see "Who drives one trip"). They may move it afterwards even if their cover ends during the trip, but a move changes only `lat`, `lng`, `heading`, `speed` and `updatedAt`; changing the route, trip or audience means starting the trip again, which is checked like a new trip. Riders allowed on the bus may only report it overcrowded: `crowd` = `full`, `crowdAt` = the server time, and `reportLat`/`reportLng` within 0.001° (about 100 m) of the bus. The app only offers this when it finds the rider on board (within 30 m of the moving bus for a minute). The driver or the admin deletes it (end of trip).

### `buses/{busId}/waves/{uid}`: "I'm waiting here"

| Field | Type | Notes |
|---|---|---|
| `uid` | string | same as the document ID: one wave per rider per bus |
| `label` | string | place or stop name shown to the driver |
| `lat`, `lng` | number | the point on the route where the rider waits |
| `createdAt` | timestamp | |
| `expiresAt` | timestamp | at most 20 minutes ahead (the app uses 15) |

An approved rider allowed on the bus creates their own. The rider, the bus's driver and the admin read and delete.

### `buses/{busId}/dropoffs/{uid}`: "Please stop here"

Same fields and readers as waves: `uid`, `label` (the place the rider gets off near), `lat`, `lng` (the drop-off point on the route), `createdAt`, `expiresAt` (at most 120 minutes ahead). The driver's screen lists them in order along the road.

## Learned travel model

Aggregated numbers only: no GPS track and no record of who rode where. Every signed-in user reads them. The driver of a running bus adds exactly one trip per write (each counter or `n` goes up by one), only for that bus's route and before the trip ends (`lastBusId` must be their running bus). See [catch-point.md](catch-point.md) for the formulas.

### `segmentStats/{id}`: time on each stretch and at each stop

Document IDs (built the same way on every platform; `bucket` is `{dayType}-{slot}`, slot = minutes since midnight / 30):

| ID | Meaning |
|---|---|
| `{routeId}_t{segment}_{bucket}_{driverUid}` | stretch from stop `segment` to `segment + 1`, this driver, this kind of day and half-hour |
| `{routeId}_u{segment}_…` | the same three kinds, for buses driving back towards the route's first stop (stops numbered in that order) |
| `{routeId}_t{segment}_{bucket}` | the same stretch, any driver, this half-hour |
| `{routeId}_t{segment}_all` | the same stretch, any time |
| `{routeId}_d{stop}_all` | time standing at stop `stop` |

| Field | Type | Notes |
|---|---|---|
| `routeId` | string | must match the start of the ID |
| `kind` | string | `travel`, `travelBack` (the `u` documents) or `dwell` |
| `index` | int | the segment or stop number |
| `dayType`, `slot` | string, int | only on bucketed documents |
| `driverId` | string | only on per-driver documents; must be the writer |
| `n` | int | trips so far |
| `mean`, `variance` | number | seconds and seconds²; weighted average with weight max(1/n, 0.1) |
| `lastBusId` | string | the running bus that wrote last |
| `updatedAt` | timestamp | |

### `spotStats/{routeId}_{lat}_{lng}`: where riders wave and get off

`lat`/`lng` are rounded to a 0.0003° grid (about 30 m), written with 4 decimals, so nearby points share a document.

| Field | Type | Notes |
|---|---|---|
| `routeId`, `lat`, `lng` | string, number, number | fixed once created |
| `asks` | int | waves the driver saw here (driver writes, +1) |
| `stops` | int | of those, how many the bus stopped for (+0 or +1 with each ask) |
| `dropoffs` | int | riders who got off here (a rider writes +1, nothing else, no uid) |
| `lastBusId` | string | set by drivers only |
| `updatedAt` | timestamp | |

### `driverStats/{uid}`: how often a driver stops for a wave

`asks` (int, +1 per wave seen) and `stops` (int, +0 or +1 each time), plus `updatedAt`. Only that driver writes it.

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

These never go to Firestore: announcements read and hidden, the "Show news" switch, the app passcode hash (Keychain), Face ID and alert settings, the chosen boarding point, the current wave, the smart-suggestions history and learned delays (unless the backup is on), the rider's walking speed (learned from their own steps for "best place to wait"), and the widget / Live Activity data.

# Best place to wait, best place to get off

Two suggestions in the bus sheet on the live map:

- **Best place to wait**: which point on the route the rider should walk to, and when to leave, so they reach it before the bus does.
- **Best place to get off**: for any destination, even one off the route, where to get off so the rider gets there soonest. It can also compare today's buses for that destination.

Both rely on a small model that learns from real trips. There is no server code (no Cloud Functions) and no machine-learning library. Each formula is short, and the unit tests check them.

Code: `TravelModel.swift` (the model), `CatchPoint.swift` (the two planners), `TripLearner.swift` (learning from a trip), `StatsStore.swift` (Firestore), `TripPlanner.swift` (rider side), `PlanViews.swift` (screens). Tests: `CatchPointTests`, `TripLearnerTests`, and the Firestore rules tests.

## 1. What is learned, and from what

At the end of every trip, the driver's phone turns its own GPS track (one point every 2 s) into a few numbers. The track itself never leaves the phone.

| Learned | How it is measured |
|---|---|
| Time on each stretch (stop *i* to stop *i+1*) | From 20 m past stop *i* until 20 m before stop *i+1* |
| Time standing at each stop | The time between those two moments around a stop |
| Whether the driver stops for a wave | The bus was within 20 m of the waving rider and slower than 1.5 m/s (walking pace) |
| Where riders get off | A rider's phone stayed within 30 m of the moving bus for a minute at about the same speed (OnBoardDetector), then left it. The last point it was on board is added as one drop-off, with no name saved |
| The rider's walking speed | From the rider's own GPS speed while walking (0.5–2.5 m/s). This stays on the phone only |

Stretch times are kept for each **kind of day** (Sunday–Thursday or Saturday), each **half-hour of the day**, and also for each **driver**. A stretch at 8:00 is a different number from the same stretch at 14:00.

## 2. A running average that keeps up with change

Each number is an average plus a spread, updated one trip at a time (`RunningStat`):

    weight   = the larger of 1/n and 0.1        (n = trips so far, including this one)
    change   = new value - old average
    average  = old average + weight × change
    variance = (1 - weight) × (old variance + weight × change²)

For the first ten trips this is the ordinary average and variance. After that, each new trip keeps a weight of one tenth, so the average follows road works or a new driver instead of being stuck on old trips. The spread (standard deviation) is the square root of the variance.

## 3. Using the most specific data available (fallback chain)

To estimate one stretch, the app tries these in order. It uses the first one that has at least 3 trips behind it:

1. this driver, this kind of day, this half-hour
2. any driver, this kind of day, this half-hour
3. this stretch at any time
4. the road distance divided by a speed: the router's (OSRM) speed for this bus when known, otherwise 20 km/h. Its spread is taken as a third of the time.

The card shows which kind of answer the rider is seeing: "From 34 past trips", or "Road-distance estimate" when nothing has been learned yet.

## 4. When the bus reaches a point

The bus's time to a point ahead of it is:

    the part of each stretch between the bus and the point (in proportion to its length)
    + the usual standing time at every stop in between

The spreads add up the same way (as variances). With few trips the average itself is less certain, so each stretch counts as `variance × (1 + 1/n)`.

## 5. Safety margin

    margin = 1.28 × the spread        (at least 30 seconds)

With a normal (bell-curve) spread, about 90% of buses arrive later than "average minus 1.28 spreads". So a rider who is there by then catches the bus about 9 times out of 10. The margin gets smaller as more trips are learned, because the spread of the average itself shrinks.

## 6. Best place to wait

The candidates are points the bus has not reached yet:

- the official stops
- spots where riders waved before and the driver stopped
- the point on the route closest to the rider

For each candidate:

    walk time  = straight-line distance × 1.3 (streets aren't straight) / the rider's walking speed
    P(catch)   = chance that the bus time is more than the walk time, from the average and spread
    stop chance:
        official stop                 1
        learned spot                  (times stopped + 1) / (times asked + 2)
        any other point on the route  the driver's own wave-stopping rate × 0.8
    score      = P(catch) × stop chance - 0.04 for each minute of walking

Points with less than a 50% chance of catching the bus are left out. The highest score wins. After that, Apple Maps works out the real walking route and distance for the chosen point, and that is what the map shows.

    leave in = bus time - walk time - margin        ("Leave now" when this is 0 or less)

"Wave here" sends the usual "I'm waiting" wave, but from this point, so the driver's banner shows where the rider actually stands.

## 7. Best place to get off

The candidates are points after the rider gets on: stops, spots where riders often get off, and the point on the route closest to the destination. For each one:

    arrival = bus time to the point + time to stop + walk time to the destination
    cost    = arrival + (1 - stop chance) × 3 minutes

The extra 3 minutes stands for the risk that the bus doesn't stop there, so the rider has to ride on and walk back. The lowest cost wins, and the card says, for example, "Get off near Sonadanga Bus Terminal, Arrive ~1:04 PM · 3 min walk".

"Ask to stop here" saves a request in `buses/{busId}/dropoffs/{uid}`. The driver's screen shows a blue "2 getting off ahead" banner and flags on the map.

**Compare buses** runs both planners for every running bus the rider is allowed on, and for every trip that leaves later today. It then sorts them by arrival time. A trip that hasn't started is placed at its first stop at its timetable time, and its route is the one whose name contains the trip's city spot. A bus the rider can't reach in time is left out.

## 8. Four ways it gets more accurate

**Today's pace (live correction).** While the map is open, the app watches the selected bus. Over the last 10 minutes it compares how long the bus really took with what the model expected for that stretch of road:

    factor = real seconds / expected seconds        (kept between 0.6 and 1.8)
    used   = 1 + trust × (factor - 1),  trust = distance covered / 2 km (at most 1)

The rest of today's trip is then multiplied by `used`, so rain or a jam on the way also delays the suggested leaving time. When the bus is clearly off its usual pace, the sheet shows one small line: "Slower than usual today" or "Faster than usual today". Standing at a stop doesn't add a point. That time counts when the bus moves on.

**Timetable lateness.** When a trip ends, the driver's phone compares the moment the bus left its first stop with the timetable time: the campus time for trips from KUET, or the city spot's time for trips back. It saves how late it was (never below 0). A trip that hasn't started yet is then assumed to leave by the usual amount late. Before 3 such trips exist, the delay this phone has seen itself (smart suggestions) is used.

**Special days.** The transport admin marks exam days, holidays and events under More → Special days (`specialDays/{yyyy-MM-dd}`). Trips on those days are learned under their own buckets, for example `exam-16` instead of `sunToThu-16`. Until a special bucket has 3 trips, the same half-hour on an ordinary day is used. The fallback chain becomes: driver on this special day → anyone on this special day → driver on an ordinary day → anyone on an ordinary day → the stretch at any time → road distance.

**Margin checked against real trips (calibration).** When a trip ends, the driver's phone also asks: what would the model have predicted, when the bus left, for up to 4 later stops, using only the numbers from before this trip? It then measures how far each real arrival was from that prediction, in spreads:

    z = (real - predicted) / spread

The z values add up in a running average and spread per route. Once there are 10 of them, the margin's 1.28 is replaced by the value that really gives 90%:

    k = 1.28 × spread of z - average of z        (kept between 0.8 and 3)

If buses tend to come earlier than predicted, k grows and riders are told to leave a little sooner. If predictions turn out steady, k shrinks and riders wait less.

## 9. Where it is stored, and who may write

See [data-model.md](data-model.md): `segmentStats`, `spotStats`, `driverStats` and `buses/{busId}/dropoffs`. The Firestore rules (`firestore.rules`, the single source of truth for every platform) only allow these writes:

- **Drivers**: the driver of a running bus adds exactly one trip per write, only for that bus's route, and only to their own per-driver numbers.
- **Riders**: a rider can only add one drop-off at a time, and no uid is stored.
- **Values**: they must look sane (0–2 hours, no extra fields).
- **Reading**: everyone signed in can read the numbers.

## 10. Limits

- With no trips learned yet, the times come only from the road distance. They improve once each stretch has 3 trips at that time of day.
- Drop-offs, walking speed and today's pace are learned only while the map is open on the rider's phone (there is no background tracking for riders).
- Special days help only once the admin marks them.
- A rider could add false drop-offs. Each write adds only one, and a spot only counts after two drop-offs, but the counts are not checked against real trips.

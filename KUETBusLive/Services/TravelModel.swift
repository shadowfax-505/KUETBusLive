//
//  TravelModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  How long the bus takes between stops, learned from real trips. Plain Swift
//  with no Firebase, so every formula can be unit tested. The numbers are kept
//  in Firestore (segmentStats) by StatsStore; docs/catch-point.md explains them.
//
//  - RunningStat: an average and a spread that update one trip at a time. The
//    first trips count equally; after ten, newer trips count a little more, so
//    the average follows road works and new drivers.
//  - TimeBucket: kind of day and half-hour of the day, because 8:00 traffic
//    is not 14:00 traffic.
//  - SegmentProfile: the best estimate for one stretch of road, trying the most
//    specific data first: this driver at this time, then anyone at this time,
//    then the route at any time, then the road distance at a typical speed.
//  - RouteTiming: adds the stretches up to answer "when does the bus reach
//    this point", with how sure we are (the spread).
//

import Foundation
import CoreLocation

// An exponentially weighted average and variance (West/Welford style update).
struct RunningStat: Codable, Equatable {
    var n: Int = 0
    var mean: Double = 0
    var variance: Double = 0

    // After this many samples each new one keeps a weight of 1/10.
    static let minWeight = 0.1

    mutating func add(_ x: Double) {
        n += 1
        let weight = max(1 / Double(n), Self.minWeight)
        let difference = x - mean
        mean += weight * difference
        variance = (1 - weight) * (variance + weight * difference * difference)
    }

    var standardDeviation: Double {
        sqrt(max(variance, 0))
    }
}

// Kind of day plus the half-hour slot: "sunToThu-16" is Sunday to Thursday, 8:00 to 8:30.
struct TimeBucket: Hashable {
    var dayType: DayType
    var slot: Int
    // A day the admin marked in the special-days calendar ("exam", "holiday", "event"):
    // traffic and riders differ, so it is learned on its own.
    var special: String?

    static let slotMinutes = 30

    init(dayType: DayType, slot: Int, special: String? = nil) {
        self.dayType = dayType
        self.slot = slot
        self.special = special
    }

    init(_ date: Date, special: String? = nil, calendar: Calendar = .current) {
        dayType = DayType(date, calendar: calendar)
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        slot = ((parts.hour ?? 0) * 60 + (parts.minute ?? 0)) / Self.slotMinutes
        self.special = special
    }

    var key: String {
        "\(special ?? dayType.rawValue)-\(slot)"
    }

    // The same half-hour on an ordinary day of this kind.
    var ordinary: TimeBucket {
        TimeBucket(dayType: dayType, slot: slot)
    }
}

// Where an estimate came from, from most to least specific.
enum EstimateSource: String, Comparable {
    case driverSlot, slot, route, router

    private var rank: Int {
        switch self {
        case .driverSlot: return 0
        case .slot: return 1
        case .route: return 2
        case .router: return 3
        }
    }

    static func < (a: EstimateSource, b: EstimateSource) -> Bool {
        a.rank < b.rank
    }
}

struct Estimate: Equatable {
    var seconds: Double
    var variance: Double
    var samples: Int          // past trips behind it; 0 for the router fallback
    var source: EstimateSource

    // The spread, plus how unsure the average itself is with few trips.
    var totalVariance: Double {
        samples > 0 ? variance + variance / Double(samples) : variance
    }
}

// The document IDs used in segmentStats. Platform-neutral: Android builds the same strings.
// Buses run both ways: "t" is a stretch in the route's own stop order (from KUET),
// "u" the same road driven the other way (back to KUET), numbered in that order.
enum StatKey {
    static func letter(_ reversed: Bool) -> String {
        reversed ? "u" : "t"
    }

    static func travel(route: String, segment: Int, bucket: TimeBucket, driver: String, reversed: Bool = false) -> String {
        "\(route)_\(letter(reversed))\(segment)_\(bucket.key)_\(driver)"
    }

    static func travel(route: String, segment: Int, bucket: TimeBucket, reversed: Bool = false) -> String {
        "\(route)_\(letter(reversed))\(segment)_\(bucket.key)"
    }

    static func travel(route: String, segment: Int, reversed: Bool = false) -> String {
        "\(route)_\(letter(reversed))\(segment)_all"
    }

    static func dwell(route: String, stop: Int) -> String {
        "\(route)_d\(stop)_all"
    }

    // How late a timetable trip usually leaves its first stop.
    static func late(route: String, schedule: String) -> String {
        "\(route)_late_\(schedule)"
    }

    // How far real arrivals fell from the predictions, in spreads (for the margin).
    static func calibration(route: String) -> String {
        "\(route)_calib_all"
    }
}

struct SegmentProfile {
    // Loaded segmentStats documents, by document ID.
    var stats: [String: RunningStat]

    // A level is used only once it has this many trips behind it.
    static let minSamples = 3
    // With no learned data: road distance at this speed (about 20 km/h, city traffic),
    // or the speed the router reported for this bus, when known.
    static let defaultSpeed = 5.5
    // The router fallback is assumed to be off by about a third either way.
    static let routerSpread = 0.33

    static let defaultDwell = Estimate(seconds: 20, variance: 15 * 15, samples: 0, source: .router)

    func travel(route: String, segment: Int, bucket: TimeBucket, driver: String?,
                metres: Double, routerSpeed: Double? = nil, reversed: Bool = false) -> Estimate {
        var keys: [(String, EstimateSource)] = []
        // On a special day, that day's own numbers first, then an ordinary day's.
        let buckets = bucket.special == nil ? [bucket] : [bucket, bucket.ordinary]
        for slotBucket in buckets {
            if let driver {
                keys.append((StatKey.travel(route: route, segment: segment, bucket: slotBucket, driver: driver,
                                            reversed: reversed), .driverSlot))
            }
            keys.append((StatKey.travel(route: route, segment: segment, bucket: slotBucket, reversed: reversed), .slot))
        }
        keys.append((StatKey.travel(route: route, segment: segment, reversed: reversed), .route))
        for (key, source) in keys {
            if let stat = stats[key], stat.n >= Self.minSamples {
                return Estimate(seconds: stat.mean, variance: stat.variance, samples: stat.n, source: source)
            }
        }
        let speed = (routerSpeed ?? 0) > 1 ? routerSpeed! : Self.defaultSpeed
        let seconds = metres / speed
        return Estimate(seconds: seconds, variance: pow(seconds * Self.routerSpread, 2), samples: 0, source: .router)
    }

    // Seconds a timetable trip usually leaves late (0 until 3 trips are known).
    func lateness(route: String, schedule: String) -> Double {
        guard let stat = stats[StatKey.late(route: route, schedule: schedule)], stat.n >= Self.minSamples else { return 0 }
        return stat.mean
    }

    // Past prediction errors for this route, in spreads.
    func calibration(route: String) -> RunningStat? {
        stats[StatKey.calibration(route: route)]
    }

    func dwell(route: String, stop: Int) -> Estimate {
        if let stat = stats[StatKey.dwell(route: route, stop: stop)], stat.n >= Self.minSamples {
            return Estimate(seconds: stat.mean, variance: stat.variance, samples: stat.n, source: .route)
        }
        return Self.defaultDwell
    }
}

// A route laid out along its road path: where each stop sits, in metres from the start.
// `reversed` lays it out the other way round, for a bus driving back to KUET:
// stop 0 is then the route's last stop.
struct RouteLine {
    var routeId: String
    var path: [CLLocationCoordinate2D]
    var stopAlong: [Double]
    var stops: [CLLocationCoordinate2D]   // in this line's order
    var reversed = false

    init(routeId: String, path: [CLLocationCoordinate2D], stops: [CLLocationCoordinate2D], reversed: Bool = false) {
        self.routeId = routeId
        self.reversed = reversed
        let forward = path.count >= 2 ? path : stops
        let line = reversed ? Array(forward.reversed()) : forward
        let stops = reversed ? Array(stops.reversed()) : stops
        self.path = line
        self.stops = stops
        var along: [Double] = []
        for stop in stops {
            // Stops come in order, so never let one sit before the previous one.
            let value = PathMath.distanceAlong(stop, path: line) ?? 0
            along.append(max(value, along.last ?? 0))
        }
        self.stopAlong = along
    }

    var length: Double {
        stopAlong.last ?? 0
    }

    // The stop's number in the route's own order, whichever way the line is laid out.
    func routeStopIndex(_ index: Int) -> Int {
        reversed ? stopAlong.count - 1 - index : index
    }

    // The same route laid out the other way round.
    func flipped() -> RouteLine {
        let forwardPath = reversed ? Array(path.reversed()) : path
        let forwardStops = reversed ? Array(stops.reversed()) : stops
        return RouteLine(routeId: routeId, path: forwardPath, stops: forwardStops, reversed: !reversed)
    }

    // Compass bearing of the path where it passes closest to `point`.
    func bearing(at point: CLLocationCoordinate2D) -> Double? {
        guard path.count >= 2, let snap = PathMath.snap(point, to: path) else { return nil }
        let a = self.point(at: max(snap.distanceAlong - 15, 0))
        let b = self.point(at: snap.distanceAlong + 15)
        let dLng = (b.longitude - a.longitude) * cos(a.latitude * .pi / 180)
        let dLat = b.latitude - a.latitude
        guard dLng != 0 || dLat != 0 else { return nil }
        let degrees = atan2(dLng, dLat) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    // Is a bus at `point` heading the other way along this line? From its compass
    // heading when known: more than 90 degrees off the road's direction.
    func isAgainst(heading: Double, at point: CLLocationCoordinate2D) -> Bool {
        guard let road = bearing(at: point) else { return false }
        let difference = abs((heading - road + 540).truncatingRemainder(dividingBy: 360) - 180)
        return difference > 90
    }

    func along(_ point: CLLocationCoordinate2D) -> Double {
        PathMath.distanceAlong(point, path: path) ?? 0
    }

    // The coordinate at a distance along the path.
    func point(at distance: Double) -> CLLocationCoordinate2D {
        guard path.count >= 2 else { return path.first ?? CLLocationCoordinate2D() }
        var travelled = 0.0
        for index in 0..<(path.count - 1) {
            let a = path[index], b = path[index + 1]
            let piece = CLLocation(latitude: a.latitude, longitude: a.longitude)
                .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            if travelled + piece >= distance, piece > 0 {
                let t = (distance - travelled) / piece
                return CLLocationCoordinate2D(latitude: a.latitude + t * (b.latitude - a.latitude),
                                              longitude: a.longitude + t * (b.longitude - a.longitude))
            }
            travelled += piece
        }
        return path.last!
    }
}

// "When does the bus reach this point, and how sure are we?"
struct RouteTiming {
    var line: RouteLine
    var profile: SegmentProfile
    var bucket: TimeBucket
    var driver: String?
    var routerSpeed: Double? = nil
    // Today's bus compared with the usual (LiveCorrection): 1.2 means 20% slower.
    var liveFactor: Double = 1

    // From one distance along the route to a later one: travel on each stretch it
    // covers (in proportion), plus the usual stop time at every stop it passes.
    func estimate(from start: Double, to end: Double) -> Estimate {
        guard end > start, line.stopAlong.count >= 2 else {
            return Estimate(seconds: 0, variance: 0, samples: 0, source: .router)
        }
        var seconds = 0.0
        var variance = 0.0
        var fewestSamples = Int.max
        var weakest = EstimateSource.driverSlot
        for segment in 0..<(line.stopAlong.count - 1) {
            let a = line.stopAlong[segment], b = line.stopAlong[segment + 1]
            let overlap = min(end, b) - max(start, a)
            guard overlap > 0, b > a else { continue }
            let fraction = overlap / (b - a)
            let part = profile.travel(route: line.routeId, segment: segment, bucket: bucket,
                                      driver: driver, metres: b - a, routerSpeed: routerSpeed,
                                      reversed: line.reversed)
            seconds += fraction * part.seconds * liveFactor
            variance += fraction * part.totalVariance * liveFactor * liveFactor
            fewestSamples = min(fewestSamples, part.samples)
            weakest = max(weakest, part.source)
        }
        // Stops strictly between the two points: the bus usually pauses there.
        for (index, along) in line.stopAlong.enumerated() where along > start + 1 && along < end - 1 {
            let dwell = profile.dwell(route: line.routeId, stop: line.routeStopIndex(index))
            seconds += dwell.seconds
            variance += dwell.totalVariance
        }
        return Estimate(seconds: seconds, variance: variance,
                        samples: fewestSamples == .max ? 0 : fewestSamples, source: weakest)
    }
}

// The safety margin: how much earlier than the average to be there.
enum Margin {
    // About 90% of buses come later than "average minus 1.28 spreads" (normal distribution).
    static let k = 1.2816
    static let minimumSeconds = 30.0
    // Real errors are used once this many trips have been checked.
    static let minCalibrationTrips = 10

    // k checked against real trips. Each trip leaves one number: how far the bus
    // really was from the prediction, in spreads (z = (real - predicted) / spread).
    // If z has average m and spread s, 90% of buses come later than
    // "predicted - (1.28 x s - m) spreads", so that is the k to use.
    static func k(calibration: RunningStat?) -> Double {
        guard let calibration, calibration.n >= minCalibrationTrips else { return k }
        return min(max(k * calibration.standardDeviation - calibration.mean, 0.8), 3)
    }

    static func seconds(for estimate: Estimate, k: Double = Margin.k) -> Double {
        max(k * sqrt(estimate.totalVariance), minimumSeconds)
    }

    // Chance a normal variable with this mean and spread is above zero.
    static func probabilityPositive(mean: Double, sd: Double) -> Double {
        guard sd > 0 else { return mean >= 0 ? 1 : 0 }
        return 0.5 * (1 + erf(mean / (sd * 2.squareRoot())))
    }
}

// Today's bus against the usual: while the map is open the app watches how long
// the selected bus takes for the road it has just driven, and compares that with
// what the model expected. Rain or a jam makes the rest of today's trip slower too.
//     factor = real seconds / expected seconds, over the last 10 minutes,
//     pulled towards 1 until the bus has covered 2 km, and kept within 0.6 ... 1.8.
struct LiveCorrection {
    struct Point: Equatable {
        var date: Date
        var along: Double
    }

    private(set) var points: [Point] = []
    static let window: TimeInterval = 10 * 60
    static let trustedMetres = 2000.0
    static let range = 0.6...1.8

    mutating func add(date: Date, along: Double) {
        // A new position only once the bus has moved on (it may stand at a stop; that
        // time is counted when it moves again).
        if let last = points.last, along <= last.along + 5 || date <= last.date { return }
        points.append(Point(date: date, along: along))
        points.removeAll { date.timeIntervalSince($0.date) > Self.window }
    }

    func factor(timing: RouteTiming) -> Double {
        guard let first = points.first, let last = points.last, last.along - first.along > 100 else { return 1 }
        var plain = timing
        plain.liveFactor = 1
        let expected = plain.estimate(from: first.along, to: last.along).seconds
        guard expected > 0 else { return 1 }
        let real = last.date.timeIntervalSince(first.date)
        let raw = min(max(real / expected, Self.range.lowerBound), Self.range.upperBound)
        let trust = min((last.along - first.along) / Self.trustedMetres, 1)
        return 1 + trust * (raw - 1)
    }
}

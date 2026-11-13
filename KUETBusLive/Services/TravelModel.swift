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

    static let slotMinutes = 30

    init(dayType: DayType, slot: Int) {
        self.dayType = dayType
        self.slot = slot
    }

    init(_ date: Date, calendar: Calendar = .current) {
        dayType = DayType(date, calendar: calendar)
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        slot = ((parts.hour ?? 0) * 60 + (parts.minute ?? 0)) / Self.slotMinutes
    }

    var key: String {
        "\(dayType.rawValue)-\(slot)"
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
enum StatKey {
    static func travel(route: String, segment: Int, bucket: TimeBucket, driver: String) -> String {
        "\(route)_t\(segment)_\(bucket.key)_\(driver)"
    }

    static func travel(route: String, segment: Int, bucket: TimeBucket) -> String {
        "\(route)_t\(segment)_\(bucket.key)"
    }

    static func travel(route: String, segment: Int) -> String {
        "\(route)_t\(segment)_all"
    }

    static func dwell(route: String, stop: Int) -> String {
        "\(route)_d\(stop)_all"
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
                metres: Double, routerSpeed: Double? = nil) -> Estimate {
        var keys: [(String, EstimateSource)] = []
        if let driver {
            keys.append((StatKey.travel(route: route, segment: segment, bucket: bucket, driver: driver), .driverSlot))
        }
        keys.append((StatKey.travel(route: route, segment: segment, bucket: bucket), .slot))
        keys.append((StatKey.travel(route: route, segment: segment), .route))
        for (key, source) in keys {
            if let stat = stats[key], stat.n >= Self.minSamples {
                return Estimate(seconds: stat.mean, variance: stat.variance, samples: stat.n, source: source)
            }
        }
        let speed = (routerSpeed ?? 0) > 1 ? routerSpeed! : Self.defaultSpeed
        let seconds = metres / speed
        return Estimate(seconds: seconds, variance: pow(seconds * Self.routerSpread, 2), samples: 0, source: .router)
    }

    func dwell(route: String, stop: Int) -> Estimate {
        if let stat = stats[StatKey.dwell(route: route, stop: stop)], stat.n >= Self.minSamples {
            return Estimate(seconds: stat.mean, variance: stat.variance, samples: stat.n, source: .route)
        }
        return Self.defaultDwell
    }
}

// A route laid out along its road path: where each stop sits, in metres from the start.
struct RouteLine {
    var routeId: String
    var path: [CLLocationCoordinate2D]
    var stopAlong: [Double]

    init(routeId: String, path: [CLLocationCoordinate2D], stops: [CLLocationCoordinate2D]) {
        self.routeId = routeId
        let line = path.count >= 2 ? path : stops
        self.path = line
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
                                      driver: driver, metres: b - a, routerSpeed: routerSpeed)
            seconds += fraction * part.seconds
            variance += fraction * part.totalVariance
            fewestSamples = min(fewestSamples, part.samples)
            weakest = max(weakest, part.source)
        }
        // Stops strictly between the two points: the bus usually pauses there.
        for (index, along) in line.stopAlong.enumerated() where along > start + 1 && along < end - 1 {
            let dwell = profile.dwell(route: line.routeId, stop: index)
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

    static func seconds(for estimate: Estimate) -> Double {
        max(k * sqrt(estimate.totalVariance), minimumSeconds)
    }

    // Chance a normal variable with this mean and spread is above zero.
    static func probabilityPositive(mean: Double, sd: Double) -> Double {
        guard sd > 0 else { return mean >= 0 ? 1 : 0 }
        return 0.5 * (1 + erf(mean / (sd * 2.squareRoot())))
    }
}

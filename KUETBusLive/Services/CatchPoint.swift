//
//  CatchPoint.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  "Best place to wait" and "Best place to get off", in plain Swift so the
//  choices can be unit tested. docs/catch-point.md explains it in words.
//
//  Best place to wait: every point the bus has still to reach is a candidate
//  (official stops, spots where drivers have stopped for waves, and the spot on
//  the route nearest the rider). For each one:
//     bus time   = learned time for the bus to get there (RouteTiming)
//     walk time  = walking distance / the rider's own walking speed
//     P(catch)   = chance the bus comes after the rider is there
//     score      = P(catch) x how likely the bus stops there - a small cost per walking minute
//  The best score wins, and "leave in" = bus time - walk time - safety margin.
//
//  Best place to get off: every point after the rider's boarding point is a
//  candidate. For each one:
//     arrival = bus time to the point + time to stop + walk time to the destination
//               + a penalty if drivers rarely stop there
//  The earliest arrival wins.
//

import Foundation
import CoreLocation

// A place on the route where a rider could get on or off.
struct RoutePoint: Equatable {
    enum Kind: Equatable {
        case stop(index: Int)             // an official stop on the route
        case spot(stops: Int, asks: Int)  // a spot where riders waved or got off before
        case nearest                      // the route's nearest point to the rider or destination
    }

    var name: String
    var coordinate: CLLocationCoordinate2D
    var along: Double
    var kind: Kind

    static func == (a: RoutePoint, b: RoutePoint) -> Bool {
        a.name == b.name && a.along == b.along && a.kind == b.kind
    }

    // How likely the bus stops here when asked, 0...1.
    // Stops: always. Learned spots: (times it stopped + 1) / (times asked + 2), a
    // Laplace average that starts at one half and moves with each outcome.
    // Anywhere else: the driver's own habit of stopping for waves, a bit lower.
    func stopChance(driverWaveRate: Double) -> Double {
        switch kind {
        case .stop:
            return 1
        case .spot(let stops, let asks):
            return Double(stops + 1) / Double(asks + 2)
        case .nearest:
            return driverWaveRate * 0.8
        }
    }
}

// How fast this rider walks, learned on the phone from their own steps.
struct WalkingSpeed: Codable, Equatable {
    var stat = RunningStat()

    static let defaultSpeed = 1.3          // metres per second, an average adult
    static let storageKey = "walkingSpeed"
    // Roads are not straight lines: walking distance is about this much longer.
    static let detour = 1.3

    var metresPerSecond: Double {
        // Blend towards the default until there are 20 samples.
        let weight = min(Double(stat.n) / 20, 1)
        return weight * stat.mean + (1 - weight) * Self.defaultSpeed
    }

    // Only speeds that look like walking (not standing, not riding).
    mutating func add(speed: Double) {
        guard speed >= 0.5, speed <= 2.5 else { return }
        stat.add(speed)
    }

    func seconds(straightLineMetres metres: Double) -> Double {
        metres * Self.detour / metresPerSecond
    }

    static func load(_ defaults: UserDefaults = .standard) -> WalkingSpeed {
        guard let data = defaults.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(WalkingSpeed.self, from: data) else { return WalkingSpeed() }
        return saved
    }

    func save(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}

struct CatchPlan: Equatable {
    var point: RoutePoint
    var busSeconds: Double         // until the bus reaches the point
    var walkSeconds: Double        // for the rider to walk there
    var marginSeconds: Double
    var catchChance: Double        // 0...1
    var samples: Int               // past trips behind the bus time

    // Seconds to wait before leaving; 0 means leave now.
    var leaveInSeconds: Double {
        max(busSeconds - walkSeconds - marginSeconds, 0)
    }

    var leaveInMinutes: Int {
        Int(leaveInSeconds / 60)
    }

    var walkMinutes: Int {
        max(Int((walkSeconds / 60).rounded(.up)), 1)
    }
}

struct DropPlan: Equatable {
    var point: RoutePoint
    var busSeconds: Double         // until the bus reaches the point
    var walkSeconds: Double        // from the point to the destination
    var arrivalSeconds: Double     // from now (or from the trip's start) to the destination
    var samples: Int

    var walkMinutes: Int {
        max(Int((walkSeconds / 60).rounded(.up)), 1)
    }
}

enum CatchPlanner {
    // A walking minute costs this much score, so a slightly safer far point
    // doesn't beat a sure near one.
    static let walkCostPerMinute = 0.04
    // Points the rider can't reach in time are dropped below this chance.
    static let minimumChance = 0.5

    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    // Stops and learned spots ahead of the bus, plus the route's nearest point to `place`.
    static func candidates(line: RouteLine, stopNames: [String], spots: [RoutePoint],
                           after start: Double, near place: CLLocationCoordinate2D) -> [RoutePoint] {
        var points: [RoutePoint] = []
        for (index, along) in line.stopAlong.enumerated() where along > start && index < stopNames.count {
            points.append(RoutePoint(name: stopNames[index], coordinate: line.point(at: along),
                                     along: along, kind: .stop(index: index)))
        }
        points += spots.filter { $0.along > start }
        if let snap = PathMath.snap(place, to: line.path), snap.distanceAlong > start {
            // Name it after the closest stop, for "near Fulbarigate".
            let near = zip(stopNames, line.stopAlong).min { abs($0.1 - snap.distanceAlong) < abs($1.1 - snap.distanceAlong) }
            points.append(RoutePoint(name: near?.0 ?? "", coordinate: snap.point,
                                     along: snap.distanceAlong, kind: .nearest))
        }
        return points
    }

    // The best place to wait for a bus that is at `busAlong` on the route, or that
    // leaves its first stop in `startsIn` seconds.
    static func bestCatch(rider: CLLocationCoordinate2D, busAlong: Double, candidates: [RoutePoint],
                          timing: RouteTiming, walking: WalkingSpeed,
                          driverWaveRate: Double, startsIn: Double = 0) -> CatchPlan? {
        var best: (plan: CatchPlan, score: Double)?
        for point in candidates where point.along > busAlong {
            let bus = timing.estimate(from: busAlong, to: point.along)
            let busSeconds = startsIn + bus.seconds
            let walk = walking.seconds(straightLineMetres: distance(rider, point.coordinate))
            let sd = sqrt(bus.totalVariance)
            let chance = Margin.probabilityPositive(mean: busSeconds - walk, sd: sd)
            guard chance >= minimumChance else { continue }
            let score = chance * point.stopChance(driverWaveRate: driverWaveRate)
                - walkCostPerMinute * walk / 60
            let plan = CatchPlan(point: point, busSeconds: busSeconds, walkSeconds: walk,
                                 marginSeconds: Margin.seconds(for: bus), catchChance: chance,
                                 samples: bus.samples)
            if best == nil || score > best!.score {
                best = (plan, score)
            }
        }
        return best?.plan
    }

    // Extra time counted when drivers rarely stop at a point: the rider may have to
    // ride on to the next stop and walk back.
    static let missedStopPenalty = 180.0

    // The best place to get off for `destination`, on a bus at `busAlong`, for a
    // rider who boards at `boardAlong` (the same as busAlong once on board).
    static func bestDrop(destination: CLLocationCoordinate2D, busAlong: Double, boardAlong: Double,
                         candidates: [RoutePoint], timing: RouteTiming, walking: WalkingSpeed,
                         driverWaveRate: Double) -> DropPlan? {
        var best: (plan: DropPlan, cost: Double)?
        for point in candidates where point.along > max(busAlong, boardAlong) {
            let bus = timing.estimate(from: busAlong, to: point.along)
            let stopping: Double
            if case .stop(let index) = point.kind {
                stopping = timing.profile.dwell(route: timing.line.routeId, stop: index).seconds / 2
            } else {
                stopping = SegmentProfile.defaultDwell.seconds
            }
            let walk = walking.seconds(straightLineMetres: distance(point.coordinate, destination))
            let arrival = bus.seconds + stopping + walk
            let cost = arrival + (1 - point.stopChance(driverWaveRate: driverWaveRate)) * missedStopPenalty
            let plan = DropPlan(point: point, busSeconds: bus.seconds, walkSeconds: walk,
                                arrivalSeconds: arrival, samples: bus.samples)
            if best == nil || cost < best!.cost {
                best = (plan, cost)
            }
        }
        return best?.plan
    }
}

// One way to get somewhere today: a running bus, or a trip that hasn't started.
struct TripOption: Equatable {
    var title: String
    var startsIn: Double        // seconds until the bus leaves its first stop (0 if running)
    var catchPlan: CatchPlan?
    var dropPlan: DropPlan

    // Seconds from now until the rider reaches the destination.
    var arrivalSeconds: Double {
        startsIn + dropPlan.arrivalSeconds
    }

    // Seconds from now until the rider should leave for the catch point, if known.
    var leaveInSeconds: Double? {
        catchPlan?.leaveInSeconds
    }

    // Earliest arrival first. A trip the rider can't catch is left out by the caller.
    static func ranked(_ options: [TripOption]) -> [TripOption] {
        options.sorted { $0.arrivalSeconds < $1.arrivalSeconds }
    }
}

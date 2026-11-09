//
//  TripProgress.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  How far along its route a bus is, from KUET to the rider's stop, as a number
//  from 0 (just left KUET) to 1 (at the rider's stop). Compiled into the app and
//  the widget extension, so it must not use Firebase.
//
//  The route is treated as straight lines between its stops. The bus position is
//  "projected" onto the nearest of those lines, and the distance travelled along
//  the route is divided by the distance from the first stop to the rider's stop.
//

import Foundation
import CoreLocation

// A stop in the small form the widget understands.
struct SharedStop: Codable, Hashable {
    var name: String
    var nameBn: String? = nil

    var displayName: String {
        PlaceNames.display(name, bangla: nameBn)
    }
    var lat: Double
    var lng: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

struct TripProgress: Codable, Hashable {
    var fraction: Double          // 0...1, where the bus is between KUET and the rider's stop
    var stopFractions: [Double]   // where each stop before the rider's stop sits on the track

    static let empty = TripProgress(fraction: 0, stopFractions: [])

    // Distance in metres between two points. Good enough for a city-sized route.
    static func metres(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    // Running total of distance at each stop: [0, d1, d1+d2, ...]
    static func cumulative(_ points: [CLLocationCoordinate2D]) -> [Double] {
        var totals = [0.0]
        for index in 1..<max(points.count, 1) {
            totals.append(totals[index - 1] + metres(points[index - 1], points[index]))
        }
        return totals
    }

    // How far along the route (in metres) the point is, using the nearest line between stops.
    static func distanceAlong(_ point: CLLocationCoordinate2D, route: [CLLocationCoordinate2D]) -> Double {
        guard route.count >= 2 else { return 0 }
        let totals = cumulative(route)
        var best = (gap: Double.greatestFiniteMagnitude, along: 0.0)
        for index in 0..<(route.count - 1) {
            let a = route[index], b = route[index + 1]
            // Flat x/y in metres around point a (fine over a few kilometres).
            let metresPerDegreeLat = 111_320.0
            let metresPerDegreeLng = 111_320.0 * cos(a.latitude * .pi / 180)
            let bx = (b.longitude - a.longitude) * metresPerDegreeLng
            let by = (b.latitude - a.latitude) * metresPerDegreeLat
            let px = (point.longitude - a.longitude) * metresPerDegreeLng
            let py = (point.latitude - a.latitude) * metresPerDegreeLat
            let lengthSquared = bx * bx + by * by
            // t is how far along this line the closest spot is: 0 = at a, 1 = at b.
            let t = lengthSquared > 0 ? min(max((px * bx + py * by) / lengthSquared, 0), 1) : 0
            let gap = hypot(px - t * bx, py - t * by)
            if gap < best.gap {
                best = (gap, totals[index] + t * sqrt(lengthSquared))
            }
        }
        return best.along
    }

    // Progress of a bus at `bus` towards stop number `stopIndex` of `stops`.
    static func make(bus: CLLocationCoordinate2D, stops: [CLLocationCoordinate2D], stopIndex: Int) -> TripProgress {
        guard stopIndex > 0, stopIndex < stops.count else { return .empty }
        let route = Array(stops[0...stopIndex])
        let totals = cumulative(route)
        guard let total = totals.last, total > 0 else { return .empty }
        let along = distanceAlong(bus, route: route)
        // The stops in between, as fractions of the whole track (KUET and my stop are the two ends).
        let middle = totals.dropFirst().dropLast().map { $0 / total }
        return TripProgress(fraction: min(max(along / total, 0), 1), stopFractions: Array(middle))
    }

    // Timetable only (no live bus): how much of the scheduled travel time has passed.
    static func fromTimetable(departure: Date, arrival: Date, now: Date = Date()) -> Double {
        let length = arrival.timeIntervalSince(departure)
        guard length > 0 else { return 0 }
        return min(max(now.timeIntervalSince(departure) / length, 0), 1)
    }
}

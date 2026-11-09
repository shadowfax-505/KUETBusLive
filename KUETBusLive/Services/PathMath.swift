//
//  PathMath.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Small map maths for "My places" and waves, kept free of Firebase and SwiftUI
//  so it can be unit tested.
//
//  A route's road path is a list of points (a polyline). "Snapping" a place to the
//  route finds the closest spot on any of the lines between those points: that is
//  where the bus actually passes, and where the rider should stand.
//

import Foundation
import CoreLocation

enum PathMath {
    // Places further than this from a route get a warning: the bus doesn't pass close by.
    static let farFromRouteMetres = 300.0

    struct Snap {
        let point: CLLocationCoordinate2D   // closest spot on the route
        let distanceFromRoute: Double       // metres from the place to that spot
        let distanceAlong: Double           // metres from the start of the route to that spot
    }

    // Closest spot on the polyline to `place`. nil if the path has fewer than two points.
    static func snap(_ place: CLLocationCoordinate2D, to path: [CLLocationCoordinate2D]) -> Snap? {
        guard path.count >= 2 else { return nil }
        var best: Snap?
        var travelled = 0.0
        for index in 0..<(path.count - 1) {
            let a = path[index], b = path[index + 1]
            // Flat x/y in metres around a, which is accurate enough over a city.
            let metresPerDegreeLat = 111_320.0
            let metresPerDegreeLng = 111_320.0 * cos(a.latitude * .pi / 180)
            let bx = (b.longitude - a.longitude) * metresPerDegreeLng
            let by = (b.latitude - a.latitude) * metresPerDegreeLat
            let px = (place.longitude - a.longitude) * metresPerDegreeLng
            let py = (place.latitude - a.latitude) * metresPerDegreeLat
            let lengthSquared = bx * bx + by * by
            let length = sqrt(lengthSquared)
            // t: 0 means the closest spot is a, 1 means it is b.
            let t = lengthSquared > 0 ? min(max((px * bx + py * by) / lengthSquared, 0), 1) : 0
            let gap = hypot(px - t * bx, py - t * by)
            if best == nil || gap < best!.distanceFromRoute {
                let point = CLLocationCoordinate2D(latitude: a.latitude + t * (b.latitude - a.latitude),
                                                   longitude: a.longitude + t * (b.longitude - a.longitude))
                best = Snap(point: point, distanceFromRoute: gap, distanceAlong: travelled + t * length)
            }
            travelled += length
        }
        return best
    }

    // Metres along the route from the start to the closest spot to `point`.
    static func distanceAlong(_ point: CLLocationCoordinate2D, path: [CLLocationCoordinate2D]) -> Double? {
        snap(point, to: path)?.distanceAlong
    }

    // How far ahead of the bus a waiting rider is, along the route. Negative means the
    // bus has already passed them. nil when the path is too short to tell.
    static func metresAhead(of bus: CLLocationCoordinate2D, rider: CLLocationCoordinate2D,
                            path: [CLLocationCoordinate2D]) -> Double? {
        guard let busAlong = distanceAlong(bus, path: path),
              let riderAlong = distanceAlong(rider, path: path) else { return nil }
        return riderAlong - busAlong
    }
}

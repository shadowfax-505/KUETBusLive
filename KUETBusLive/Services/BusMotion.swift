//
//  BusMotion.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The maths that makes buses glide and turn on the live map, kept free of
//  SwiftUI and Firebase so it can be unit tested.
//
//  A driver's phone sends a position about every 5 seconds. Drawn as it arrives,
//  the bus would jump from point to point. Instead the map remembers where the
//  bus was drawn and where the new point is, and moves it in a straight line
//  between the two over about the time until the next point is due:
//
//      shown position = from + (to - from) * fraction,  fraction = elapsed / duration (0...1)
//
//  The icon turns to the direction of travel. GPS gives that as the "course";
//  when the course is missing (standing still, weak signal) it is worked out
//  from the last two points instead. Turning always takes the short way round:
//  from 350° to 10° is a 20° turn to the right, not 340° to the left.
//

import Foundation
import CoreLocation

enum BusMotion {
    // Shortest and longest glide between two positions, in seconds.
    static let minGlide: TimeInterval = 1
    static let maxGlide: TimeInterval = 5
    // Moves shorter than this are GPS noise: they don't change the heading.
    static let minMoveForBearing = 3.0
    // A bus this close to its route is drawn on the road line.
    static let snapToRouteMetres = 25.0

    // Compass bearing from a to b in degrees, 0 = north, 90 = east, 0..<360.
    static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLng = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
        return normalized(atan2(y, x) * 180 / .pi)
    }

    // Any angle in degrees brought into 0..<360.
    static func normalized(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    // The angle to turn the icon to, starting from `current` (which may be outside
    // 0..<360 after many turns), so the turn is never more than 180°.
    // 350 -> 10 gives 370 (turn right by 20), 10 -> 350 gives -10 (turn left by 20).
    static func shortestRotation(from current: Double, to target: Double) -> Double {
        var delta = normalized(target) - normalized(current)
        if delta > 180 { delta -= 360 }
        if delta <= -180 { delta += 360 }
        return current + delta
    }

    // Direction of travel: the GPS course when it is valid (0...360), otherwise the
    // bearing from the previous point, if the bus moved far enough to tell.
    static func heading(course: Double?, from previous: CLLocationCoordinate2D?,
                        to current: CLLocationCoordinate2D) -> Double? {
        if let course = course, course >= 0, course <= 360 {
            return normalized(course)
        }
        guard let previous = previous, distance(previous, current) >= minMoveForBearing else { return nil }
        return bearing(from: previous, to: current)
    }

    // How long to glide to a new point: the gap since the last point, kept between
    // minGlide and maxGlide, so the bus keeps moving until the next one arrives.
    static func glideDuration(previousUpdate: Date?, newUpdate: Date) -> TimeInterval {
        guard let previousUpdate = previousUpdate else { return minGlide }
        return min(max(newUpdate.timeIntervalSince(previousUpdate), minGlide), maxGlide)
    }

    // How far through a glide we are, 0 at the start and 1 at the end.
    static func fraction(start: Date, duration: TimeInterval, now: Date) -> Double {
        guard duration > 0 else { return 1 }
        return min(max(now.timeIntervalSince(start) / duration, 0), 1)
    }

    // The point `fraction` of the way from a to b. Over a few hundred metres a
    // straight line in latitude and longitude is close enough.
    static func interpolate(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D,
                            fraction: Double) -> CLLocationCoordinate2D {
        let t = min(max(fraction, 0), 1)
        return CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * t,
                                      longitude: a.longitude + (b.longitude - a.longitude) * t)
    }

    // The point moved onto the route line when it is within snapToRouteMetres,
    // so a bus drawn between two GPS points still sits on the road.
    static func snapped(_ point: CLLocationCoordinate2D, to path: [CLLocationCoordinate2D]?) -> CLLocationCoordinate2D {
        guard let path = path, let snap = PathMath.snap(point, to: path),
              snap.distanceFromRoute <= snapToRouteMetres else { return point }
        return snap.point
    }

    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}

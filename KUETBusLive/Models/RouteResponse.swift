//
//  RouteResponse.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Matches the JSON returned by the OSRM routing API. Only the fields the app
//  needs are declared; JSONDecoder ignores the rest.
//
//  Example:
//  { "code": "Ok",
//    "routes": [ { "duration": 412.3, "distance": 5180.4,
//                  "geometry": { "coordinates": [[89.5024, 22.8999], [89.5095, 22.8890]] } } ] }
//

import Foundation
import CoreLocation

struct RouteResponse: Codable {
    let code: String
    let routes: [RouteInfo]
}

struct RouteInfo: Codable {
    let duration: Double   // seconds
    let distance: Double   // metres
    let geometry: RouteGeometry?

    var minutes: Int {
        Int((duration / 60).rounded(.up))
    }

    // When the routing server can't be reached: the distance along the route (or the
    // straight line, a third longer for the roads) at a city bus's 18 km/h. Same
    // numbers on Android. nil once the bus has passed the stop.
    static let fallbackSpeed = 5.0          // metres per second
    static let roadFactor = 1.35

    static func estimate(alongRoute metres: Double?, straightLine: Double) -> RouteInfo? {
        let distance = metres ?? straightLine * roadFactor
        guard distance >= 0 else { return nil }
        return RouteInfo(duration: distance / fallbackSpeed, distance: distance, geometry: nil)
    }

    var kilometres: Double {
        distance / 1000
    }

    var summary: String {
        String(localized: "\(minutes) min, \(String(format: "%.1f", kilometres)) km")
    }

    // The road path as map coordinates, ready for a MapPolyline.
    var path: [CLLocationCoordinate2D] {
        geometry?.coordinates ?? []
    }
}

// GeoJSON line: a list of [longitude, latitude] pairs.
struct RouteGeometry: Codable {
    let rawCoordinates: [[Double]]

    enum CodingKeys: String, CodingKey {
        case rawCoordinates = "coordinates"
    }

    // GeoJSON puts longitude first, so swap the order for CoreLocation.
    var coordinates: [CLLocationCoordinate2D] {
        rawCoordinates.compactMap { pair in
            guard pair.count == 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }
    }
}

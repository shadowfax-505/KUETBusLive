//
//  RouteResponse.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Matches the JSON returned by the OSRM routing API. Only the fields the app
//  needs are declared; JSONDecoder ignores the rest.
//
//  Example: { "code": "Ok", "routes": [ { "duration": 412.3, "distance": 5180.4 } ] }
//

import Foundation

struct RouteResponse: Codable {
    let code: String
    let routes: [RouteInfo]
}

struct RouteInfo: Codable {
    let duration: Double   // seconds
    let distance: Double   // metres

    var minutes: Int {
        Int((duration / 60).rounded(.up))
    }

    var kilometres: Double {
        distance / 1000
    }

    var summary: String {
        "\(minutes) min, \(String(format: "%.1f", kilometres)) km"
    }
}

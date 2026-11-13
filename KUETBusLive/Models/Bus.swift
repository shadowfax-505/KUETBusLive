//
//  Bus.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import SwiftUI
import CoreLocation
import FirebaseFirestore

enum CrowdLevel: String, Codable, CaseIterable {
    case unknown
    case seats
    case full

    var label: String {
        switch self {
        case .unknown:
            return String(localized: "No report yet")
        case .seats:
            return String(localized: "Seats available")
        case .full:
            return String(localized: "Full")
        }
    }

    // One or two words, for small spaces like the trip card's tiles.
    var shortLabel: String {
        switch self {
        case .unknown:
            return String(localized: "No report")
        case .seats:
            return String(localized: "Seats free")
        case .full:
            return String(localized: "Full")
        }
    }

    var color: Color {
        switch self {
        case .unknown:
            return .gray
        case .seats:
            return .green
        case .full:
            return .red
        }
    }
}

// One document in the "buses" collection. It exists only while a trip is running.
struct Bus: Identifiable, Codable {
    @DocumentID var id: String?
    var number: String
    var routeId: String
    var routeName: String
    var driverId: String
    var lat: Double
    var lng: Double
    var updatedAt: Date
    var crowd: CrowdLevel
    var audience: BusAudience?
    var scheduleId: String?
    var fleetBusId: String?   // which fleet bus is driving this trip, e.g. "normal-2"
    var heading: Double?   // degrees from north, from the driver's GPS
    var speed: Double?     // metres per second
    // The last "overcrowded" report, from a rider the app found on board, and where
    // that rider was (the rules check it is near the bus).
    var crowdAt: Date?
    var reportLat: Double?
    var reportLng: Double?

    // Older trips saved before allocation existed count as student buses.
    var allocation: BusAudience {
        audience ?? .student
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var speedText: String {
        guard let speed = speed, speed >= 0 else { return "--" }
        return String(localized: "\(Int(speed * 3.6)) km/h")
    }

    // A crowd report fades after ten minutes: people get off.
    static let crowdLifetime: TimeInterval = 10 * 60

    // Overcrowded, reported by a rider on board in the last ten minutes.
    func isCrowded(at date: Date = Date()) -> Bool {
        guard crowd == .full, let crowdAt else { return false }
        return date.timeIntervalSince(crowdAt) < Self.crowdLifetime
    }

    // No position for a minute usually means the driver lost signal.
    var isStale: Bool {
        Date().timeIntervalSince(updatedAt) > 60
    }

    var lastUpdateText: String {
        Bus.ageText(seconds: Int(Date().timeIntervalSince(updatedAt)))
    }

    // "12 s ago", "5 min ago", "2 h ago", "1 d ago": long gaps read in hours or
    // days instead of "157 min ago".
    static func ageText(seconds: Int) -> String {
        let seconds = max(seconds, 0)
        if seconds < 60 {
            return String(localized: "\(seconds) s ago")
        }
        if seconds < 3600 {
            return String(localized: "\(seconds / 60) min ago")
        }
        if seconds < 86_400 {
            return String(localized: "\(seconds / 3600) h ago")
        }
        return String(localized: "\(seconds / 86_400) d ago")
    }
}

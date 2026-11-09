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
            return "No report yet"
        case .seats:
            return "Seats available"
        case .full:
            return "Full"
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

    // Older trips saved before allocation existed count as student buses.
    var allocation: BusAudience {
        audience ?? .student
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var lastUpdateText: String {
        let seconds = Int(Date().timeIntervalSince(updatedAt))
        if seconds < 60 {
            return "\(max(seconds, 0)) s ago"
        }
        return "\(seconds / 60) min ago"
    }
}

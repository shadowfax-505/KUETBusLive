//
//  MyPlace.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  A rider's own boarding point between official stops, such as home or a
//  tuition centre, where they ask the driver to stop or wave the bus down.
//  Saved in users/{uid}/places/{id}. Plain fields only (strings, numbers,
//  a timestamp), so an Android app can read them too.
//

import Foundation
import CoreLocation
import FirebaseFirestore

enum PlaceKind: String, Codable, CaseIterable, Identifiable {
    case home
    case tuition
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return String(localized: "Home")
        case .tuition: return String(localized: "Tuition")
        case .other: return String(localized: "Other")
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .tuition: return "book.fill"
        case .other: return "mappin"
        }
    }
}

struct MyPlace: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var label: String        // "Home", "Uncle's house"
    var kind: PlaceKind
    var lat: Double
    var lng: Double
    var createdAt: Date

    // At most five places. Their document IDs are p1 ... p5, which also lets the
    // security rules enforce the limit.
    static let maxCount = 5
    static let slotIds = (1...maxCount).map { "p\($0)" }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

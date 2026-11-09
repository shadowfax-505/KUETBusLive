//
//  Wave.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  "I'm waiting here": a rider tells the driver of one running bus where they
//  are standing. Saved in buses/{busId}/waves/{uid}, so each rider has at most
//  one wave per bus. It lasts 15 minutes, and goes away when the bus passes,
//  the rider cancels, or the trip ends.
//

import Foundation
import CoreLocation
import FirebaseFirestore

struct Wave: Identifiable, Codable {
    @DocumentID var id: String?   // the rider's uid
    var uid: String
    var label: String             // "Home" or a stop name, shown to the driver
    var lat: Double               // the point on the route where the rider waits
    var lng: Double
    var createdAt: Date
    var expiresAt: Date

    static let lifetime: TimeInterval = 15 * 60

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    func isActive(at date: Date = Date()) -> Bool {
        expiresAt > date
    }
}

//
//  BusRoute.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import Foundation
import CoreLocation
import FirebaseFirestore

struct Stop: Codable, Hashable {
    var name: String          // English name, also the stop's identity
    var nameBn: String? = nil // optional Bangla name, e.g. "ফুলবাড়ীগেট"
    var lat: Double
    var lng: Double

    // The name to show: Bangla when the app is in Bangla, otherwise English.
    var displayName: String {
        PlaceNames.display(name, bangla: nameBn)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// One document in the "routes" collection.
struct BusRoute: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var nameBn: String? = nil
    var stops: [Stop]

    var displayName: String {
        PlaceNames.display(name, bangla: nameBn)
    }
}

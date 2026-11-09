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
    var name: String
    var lat: Double
    var lng: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// One document in the "routes" collection.
struct BusRoute: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var stops: [Stop]
}

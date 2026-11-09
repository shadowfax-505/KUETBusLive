//
//  PlacesViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The rider's "My places" (up to five), saved in users/{uid}/places.
//  It also loads every route's road path, so each place can be snapped to the
//  routes and the rider warned when no bus passes close by.
//

import Foundation
import CoreLocation
import FirebaseFirestore

class PlacesViewModel: ObservableObject {
    @Published var places = [MyPlace]()
    @Published var routes = [BusRoute]()
    @Published var routePaths: [String: [CLLocationCoordinate2D]] = [:]   // route ID -> road path
    @Published var errorMessage = ""

    // Which boarding point the rider uses: "" for their official stop, or a place ID.
    static let boardingPlaceKey = "boardingPlaceId"

    private let db = Firestore.firestore()
    private let etaService = ETAService()
    private var placesListener: ListenerRegistration?
    private var routesListener: ListenerRegistration?

    var canAddMore: Bool {
        places.count < MyPlace.maxCount
    }

    func startListening(uid: String) {
        stopListening()
        placesListener = db.collection("users").document(uid).collection("places")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                self.places = (snapshot?.documents.compactMap { try? $0.data(as: MyPlace.self) } ?? [])
                    .sorted { $0.createdAt < $1.createdAt }
            }
        routesListener = db.collection("routes").addSnapshotListener { snapshot, _ in
            self.routes = snapshot?.documents.compactMap { try? $0.data(as: BusRoute.self) } ?? []
            for route in self.routes {
                self.loadPath(for: route)
            }
        }
    }

    func stopListening() {
        placesListener?.remove()
        placesListener = nil
        routesListener?.remove()
        routesListener = nil
    }

    private func loadPath(for route: BusRoute) {
        guard let id = route.id, routePaths[id] == nil else { return }
        // Straight lines between stops first, replaced by the road path when it arrives.
        routePaths[id] = route.stops.map { $0.coordinate }
        etaService.fetchPath(through: route.stops.map { $0.coordinate }) { path in
            if path.count >= 2 {
                self.routePaths[id] = path
            }
        }
    }

    // The route that passes closest to a place, and how close.
    func closestRoute(to place: CLLocationCoordinate2D) -> (route: BusRoute, snap: PathMath.Snap)? {
        routes.compactMap { route -> (BusRoute, PathMath.Snap)? in
            guard let id = route.id, let path = routePaths[id],
                  let snap = PathMath.snap(place, to: path) else { return nil }
            return (route, snap)
        }
        .min { $0.1.distanceFromRoute < $1.1.distanceFromRoute }
    }

    // Add: uses the first free slot p1 ... p5.
    func add(label: String, kind: PlaceKind, coordinate: CLLocationCoordinate2D, uid: String,
             completion: @escaping (String?) -> Void) {
        let used = Set(places.compactMap { $0.id })
        guard let slot = MyPlace.slotIds.first(where: { !used.contains($0) }) else {
            completion(String(localized: "You can save up to \(MyPlace.maxCount) places."))
            return
        }
        let place = MyPlace(label: label.trimmingCharacters(in: .whitespaces), kind: kind,
                            lat: coordinate.latitude, lng: coordinate.longitude, createdAt: Date())
        do {
            try db.collection("users").document(uid).collection("places").document(slot)
                .setData(from: place) { error in
                    completion(error?.localizedDescription)
                }
        } catch {
            completion(error.localizedDescription)
        }
    }

    // Delete
    func delete(_ place: MyPlace, uid: String) {
        guard let id = place.id else { return }
        db.collection("users").document(uid).collection("places").document(id).delete()
        // Removing the place you board at goes back to your official stop.
        if UserDefaults.standard.string(forKey: Self.boardingPlaceKey) == id {
            UserDefaults.standard.set("", forKey: Self.boardingPlaceKey)
        }
    }
}

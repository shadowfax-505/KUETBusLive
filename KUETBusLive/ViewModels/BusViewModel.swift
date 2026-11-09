//
//  BusViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Rider side: listens to running buses, works out ETAs, loads route paths
//  for the map and sends crowd reports.
//  Students only see student buses. Teachers see every bus.
//

import SwiftUI
import CoreLocation
import FirebaseFirestore

class BusViewModel: ObservableObject {
    @Published var buses = [Bus]()
    @Published var etaText: [String: String] = [:]   // bus ID -> "7 min, 5.2 km"
    @Published var etaPaths: [String: [CLLocationCoordinate2D]] = [:]    // bus ID -> road to my stop
    @Published var routeStops: [String: [Stop]] = [:]                    // route ID -> stops
    @Published var routePaths: [String: [CLLocationCoordinate2D]] = [:]  // route ID -> full road path

    // Set by the map screen from the rider's profile.
    var favoriteStop: Stop?
    var viewerRole: UserRole = .student

    static let etaRefreshSeconds: TimeInterval = 30

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let etaService = ETAService()
    private var lastEtaFetch: [String: Date] = [:]
    private var alertedBusIds = Set<String>()

    // Read: real-time updates whenever a driver moves.
    func startListening() {
        guard listener == nil else { return }
        listener = db.collection("buses").addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error getting buses: \(error)")
                return
            }
            let allBuses = snapshot?.documents.compactMap { document in
                try? document.data(as: Bus.self)
            } ?? []
            // Keep only the buses this rider is allowed to get on.
            // The animation makes each bus glide to its new spot instead of jumping.
            withAnimation(.easeInOut(duration: 1)) {
                self.buses = allBuses.filter { $0.allocation.canBoard(self.viewerRole) }
            }

            for bus in self.buses {
                self.refreshETA(for: bus)
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func bus(withId id: String) -> Bus? {
        buses.first { $0.id == id }
    }

    // Loads a route's stops once, then asks OSRM for the road path through them.
    func loadRoute(for bus: Bus) {
        let routeId = bus.routeId
        guard routeStops[routeId] == nil else { return }
        db.collection("routes").document(routeId).getDocument { snapshot, error in
            guard let route = try? snapshot?.data(as: BusRoute.self) else {
                print("Could not load route: \(error?.localizedDescription ?? "not found")")
                return
            }
            self.routeStops[routeId] = route.stops
            self.etaService.fetchPath(through: route.stops.map { $0.coordinate }) { path in
                self.routePaths[routeId] = path
            }
        }
    }

    // The road from the bus to my stop. The path is only fetched every 30 seconds,
    // so drop the points the bus has already passed and start it at the bus.
    func remainingPath(for bus: Bus) -> [CLLocationCoordinate2D] {
        guard let id = bus.id, let path = etaPaths[id], !path.isEmpty else { return [] }
        let busLocation = CLLocation(latitude: bus.lat, longitude: bus.lng)
        var closestIndex = 0
        var closestDistance = Double.greatestFiniteMagnitude
        for (index, point) in path.enumerated() {
            let distance = busLocation.distance(from: CLLocation(latitude: point.latitude,
                                                                 longitude: point.longitude))
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
        }
        return [bus.coordinate] + path[closestIndex...]
    }

    // The stop on the bus's route that the bus is closest to right now.
    func nearestStop(for bus: Bus) -> (stop: Stop, index: Int, count: Int)? {
        guard let stops = routeStops[bus.routeId], !stops.isEmpty else { return nil }
        let busLocation = CLLocation(latitude: bus.lat, longitude: bus.lng)
        let closest = stops.enumerated().min { first, second in
            let a = CLLocation(latitude: first.element.lat, longitude: first.element.lng)
            let b = CLLocation(latitude: second.element.lat, longitude: second.element.lng)
            return busLocation.distance(from: a) < busLocation.distance(from: b)
        }
        guard let nearest = closest else { return nil }
        return (nearest.element, nearest.offset, stops.count)
    }

    // Update: anyone allowed on the bus can report how crowded it is.
    func report(_ crowd: CrowdLevel, for bus: Bus) {
        guard let id = bus.id else { return }
        db.collection("buses").document(id).updateData(["crowd": crowd.rawValue])
    }

    func refreshETA(for bus: Bus, force: Bool = false) {
        guard let busId = bus.id, let stop = favoriteStop else { return }

        // The public routing server has fair-use limits, so ask at most every 30 seconds.
        if !force, let last = lastEtaFetch[busId],
           Date().timeIntervalSince(last) < Self.etaRefreshSeconds {
            return
        }
        lastEtaFetch[busId] = Date()

        etaService.fetchETA(from: bus.coordinate, to: stop.coordinate) { info in
            guard let info = info else {
                self.etaText[busId] = "ETA unavailable"
                return
            }
            self.etaText[busId] = info.summary
            self.etaPaths[busId] = info.path
            self.checkArrivalAlert(bus: bus, minutes: info.minutes)
        }
    }

    private func checkArrivalAlert(bus: Bus, minutes: Int) {
        guard let busId = bus.id else { return }
        let alertsOn = UserDefaults.standard.bool(forKey: "arrivalAlertOn")
        guard alertsOn,
              minutes <= NotificationManager.alertMinutes,
              !alertedBusIds.contains(busId) else { return }

        alertedBusIds.insert(busId)
        NotificationManager.shared.sendArrivalAlert(busNumber: bus.number,
                                                    stopName: favoriteStop?.name ?? "your stop",
                                                    minutes: minutes)
    }
}

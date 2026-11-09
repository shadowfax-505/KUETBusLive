//
//  BusViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Rider side: listens to running buses, works out ETAs and sends crowd reports.
//  Students only see student buses. Teachers see every bus.
//

import Foundation
import FirebaseFirestore

class BusViewModel: ObservableObject {
    @Published var buses = [Bus]()
    @Published var etaText: [String: String] = [:]   // bus ID -> "7 min, 5.2 km"

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
            self.buses = allBuses.filter { $0.allocation.canBoard(self.viewerRole) }

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

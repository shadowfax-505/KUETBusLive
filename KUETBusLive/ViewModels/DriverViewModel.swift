//
//  DriverViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Driver side: starts and ends a trip, and writes the bus position to Firestore.
//  It is the delegate of LocationManager, so it gets every new GPS position.
//  It also listens for riders waiting along the road ("I'm waiting here"), so the
//  driver sees how many are ahead without touching the phone.
//

import Foundation
import CoreLocation
import FirebaseFirestore
import UIKit
import AudioToolbox

class DriverViewModel: ObservableObject, LocationUpdateDelegate {
    @Published var isOnTrip = false
    @Published var updatesSent = 0
    @Published var statusMessage = String(localized: "Not on a trip")
    @Published var currentLat: Double?
    @Published var currentLng: Double?
    @Published var routePath: [CLLocationCoordinate2D] = []
    // Riders waiting further along the road, nearest first.
    @Published var waitingAhead: [(wave: Wave, metres: Double)] = []

    static let sendIntervalSeconds: TimeInterval = 5

    private let db = Firestore.firestore()
    private let locationManager = LocationManager()
    private let etaService = ETAService()
    private var busDocId: String?
    private var pendingBus: Bus?
    private var hasCreatedDocument = false
    private var lastSent = Date.distantPast
    private var wavesListener: ListenerRegistration?
    private var waves: [Wave] = []
    // A wave counts as passed once the bus is this far beyond it.
    static let passedMetres = 40.0

    init() {
        locationManager.delegate = self
    }

    // The driver picks the trip from the timetable, so the bus knows who may ride it.
    func startTrip(schedule: BusSchedule, route: BusRoute, driverId: String) {
        guard let routeId = route.id, let scheduleId = schedule.id else {
            statusMessage = String(localized: "Pick a trip and a route first")
            return
        }
        busDocId = "bus-\(scheduleId)"
        var bus = Bus(number: schedule.title,
                      routeId: routeId,
                      routeName: route.name,
                      driverId: driverId,
                      lat: 0,
                      lng: 0,
                      updatedAt: Date(),
                      crowd: .unknown)
        bus.audience = schedule.audience
        bus.scheduleId = scheduleId
        pendingBus = bus
        hasCreatedDocument = false
        lastSent = .distantPast
        updatesSent = 0
        isOnTrip = true
        statusMessage = String(localized: "Waiting for GPS...")
        // Keep sending the position even if the driver locks the phone or opens another app.
        locationManager.start(inBackground: true)
        listenToWaves()
    }

    var permissionText: String {
        locationManager.permissionText
    }

    // Delete: ending the trip removes the bus from every student's map.
    func endTrip() {
        locationManager.stop()
        stopWaves(deleteAll: true)
        if let id = busDocId {
            db.collection("buses").document(id).delete { error in
                if let error = error {
                    print("Error ending trip: \(error)")
                }
            }
        }
        busDocId = nil
        pendingBus = nil
        isOnTrip = false
        statusMessage = String(localized: "Trip ended")
    }

    // The road path of the chosen route, drawn on the driver's map.
    func loadPath(for route: BusRoute?) {
        guard let route = route else {
            routePath = []
            return
        }
        // Straight lines between stops until the road path arrives (or if it can't be loaded),
        // so riders waiting ahead can still be worked out.
        routePath = route.stops.map { $0.coordinate }
        etaService.fetchPath(through: route.stops.map { $0.coordinate }) { path in
            if path.count >= 2 {
                self.routePath = path
            }
        }
    }

    // MARK: - LocationUpdateDelegate

    func didUpdateLocation(_ location: CLLocation) {
        currentLat = location.coordinate.latitude
        currentLng = location.coordinate.longitude

        guard isOnTrip, let docId = busDocId else { return }
        guard Date().timeIntervalSince(lastSent) >= Self.sendIntervalSeconds else { return }
        lastSent = Date()

        let busRef = db.collection("buses").document(docId)

        if !hasCreatedDocument, var bus = pendingBus {
            // First position of the trip: create the whole document.
            bus.lat = location.coordinate.latitude
            bus.lng = location.coordinate.longitude
            bus.updatedAt = Date()
            bus.heading = location.course >= 0 ? location.course : nil
            bus.speed = location.speed >= 0 ? location.speed : nil
            do {
                try busRef.setData(from: bus)
                hasCreatedDocument = true
            } catch {
                statusMessage = String(localized: "Could not start trip: \(error.localizedDescription)")
                return
            }
        } else {
            // Later positions: only update the moving fields, so crowd reports are kept.
            var fields: [String: Any] = [
                "lat": location.coordinate.latitude,
                "lng": location.coordinate.longitude,
                "updatedAt": Date()
            ]
            // CoreLocation reports -1 when it doesn't know the direction or speed yet.
            if location.course >= 0 {
                fields["heading"] = location.course
            }
            if location.speed >= 0 {
                fields["speed"] = location.speed
            }
            busRef.updateData(fields)
        }

        updatesSent += 1
        statusMessage = String(localized: "Sharing live location")
        updateWaitingAhead()
    }

    func didFailWithLocationError(_ message: String) {
        statusMessage = message
    }

    // MARK: - Riders waiting ahead

    // Read: every wave for this bus, live.
    private func listenToWaves() {
        guard let id = busDocId else { return }
        wavesListener?.remove()
        wavesListener = db.collection("buses").document(id).collection("waves")
            .addSnapshotListener { snapshot, _ in
                self.waves = snapshot?.documents.compactMap { try? $0.data(as: Wave.self) } ?? []
                self.updateWaitingAhead()
            }
    }

    // Stops listening. At the end of a trip it also removes the waves, so none are left behind.
    private func stopWaves(deleteAll: Bool) {
        wavesListener?.remove()
        wavesListener = nil
        if deleteAll, let id = busDocId {
            for wave in waves {
                if let waveId = wave.id {
                    db.collection("buses").document(id).collection("waves").document(waveId).delete()
                }
            }
        }
        waves = []
        waitingAhead = []
    }

    // Works out who is still ahead of the bus. Riders the bus has passed, and waves
    // older than 15 minutes, are removed. A new rider ahead plays a sound and a tap,
    // so the driver doesn't need to look at the phone.
    func updateWaitingAhead() {
        guard let lat = currentLat, let lng = currentLng, routePath.count >= 2 else {
            waitingAhead = []
            return
        }
        let bus = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        var ahead: [(wave: Wave, metres: Double)] = []
        for wave in waves {
            let metres = PathMath.metresAhead(of: bus, rider: wave.coordinate, path: routePath) ?? 0
            if !wave.isActive() || metres < -Self.passedMetres {
                if let id = busDocId, let waveId = wave.id {
                    db.collection("buses").document(id).collection("waves").document(waveId).delete()
                }
            } else {
                ahead.append((wave, max(metres, 0)))
            }
        }
        ahead.sort { $0.metres < $1.metres }

        if ahead.count > waitingAhead.count {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            AudioServicesPlaySystemSound(1315)   // a short chime
        }
        waitingAhead = ahead
    }
}

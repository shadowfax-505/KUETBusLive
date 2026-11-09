//
//  DriverViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Driver side: starts and ends a trip, and writes the bus position to Firestore.
//  It is the delegate of LocationManager, so it gets every new GPS position.
//

import Foundation
import CoreLocation
import FirebaseFirestore

class DriverViewModel: ObservableObject, LocationUpdateDelegate {
    @Published var isOnTrip = false
    @Published var updatesSent = 0
    @Published var statusMessage = "Not on a trip"
    @Published var currentLat: Double?
    @Published var currentLng: Double?
    @Published var routePath: [CLLocationCoordinate2D] = []

    static let sendIntervalSeconds: TimeInterval = 5

    private let db = Firestore.firestore()
    private let locationManager = LocationManager()
    private let etaService = ETAService()
    private var busDocId: String?
    private var pendingBus: Bus?
    private var hasCreatedDocument = false
    private var lastSent = Date.distantPast

    init() {
        locationManager.delegate = self
    }

    // The driver picks the trip from the timetable, so the bus knows who may ride it.
    func startTrip(schedule: BusSchedule, route: BusRoute, driverId: String) {
        guard let routeId = route.id, let scheduleId = schedule.id else {
            statusMessage = "Pick a trip and a route first"
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
        statusMessage = "Waiting for GPS..."
        // Keep sending the position even if the driver locks the phone or opens another app.
        locationManager.start(inBackground: true)
    }

    var permissionText: String {
        locationManager.permissionText
    }

    // Delete: ending the trip removes the bus from every student's map.
    func endTrip() {
        locationManager.stop()
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
        statusMessage = "Trip ended"
    }

    // The road path of the chosen route, drawn on the driver's map.
    func loadPath(for route: BusRoute?) {
        guard let route = route else {
            routePath = []
            return
        }
        etaService.fetchPath(through: route.stops.map { $0.coordinate }) { path in
            self.routePath = path
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
                statusMessage = "Could not start trip: \(error.localizedDescription)"
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
        statusMessage = "Sharing live location"
    }

    func didFailWithLocationError(_ message: String) {
        statusMessage = message
    }
}

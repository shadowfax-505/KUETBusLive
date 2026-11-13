//
//  DriverViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Driver side: starts and ends a trip, and writes the bus position to Firestore.
//  It is the delegate of LocationManager, so it gets every new GPS position.
//  It also listens for riders waiting along the road ("I'm waiting here") and for
//  riders asking to get off ("Please stop here"), so the driver sees both without
//  touching the phone. At the end of a trip it turns its own GPS track into a few
//  numbers for the shared travel model (TripLearner, StatsStore) before the bus
//  is removed.
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
    // Riders who asked the bus to stop where they get off, nearest first.
    @Published var dropoffsAhead: [(wave: Wave, metres: Double)] = []

    static let sendIntervalSeconds: TimeInterval = 5

    private let db = Firestore.firestore()
    private let locationManager = LocationManager()
    private let etaService = ETAService()
    private var busDocId: String?
    private var pendingBus: Bus?
    private var hasCreatedDocument = false
    private var lastSent = Date.distantPast
    private var tripRecordId: String?
    private var wavesListener: ListenerRegistration?
    private var waves: [Wave] = []
    private var dropoffsListener: ListenerRegistration?
    private var dropoffs: [Wave] = []

    // This trip's own track and the waves seen on it, for the travel model.
    private var tripRoute: BusRoute?
    private var tripDriverId: String?
    private var samples: [GPSSample] = []
    private var seenWaves: [String: SeenWave] = [:]
    static let sampleSeconds: TimeInterval = 2
    // Ending a trip waits at most this long for the numbers to be saved.
    static let uploadTimeout: TimeInterval = 8
    // A wave counts as passed once the bus is this far beyond it.
    static let passedMetres = 40.0

    init() {
        locationManager.delegate = self
    }

    // The driver picks the trip from the timetable, so the bus knows who may ride it.
    // `fleetBus` is the bus assigned to this driver today; the rules check it again.
    func startTrip(schedule: BusSchedule, route: BusRoute, fleetBus: FleetBus, driverId: String) {
        guard let routeId = route.id, let scheduleId = schedule.id, let fleetBusId = fleetBus.id else {
            statusMessage = String(localized: "Pick a trip and a route first")
            return
        }
        // One live document per fleet bus, so the same bus can't be on the map twice.
        busDocId = "bus-\(fleetBusId)"
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
        bus.fleetBusId = fleetBusId
        pendingBus = bus
        tripRoute = route
        tripDriverId = driverId
        samples = []
        seenWaves = [:]
        recordTripStart(driverId: driverId, fleetBusId: fleetBusId, scheduleId: scheduleId, routeId: routeId)
        hasCreatedDocument = false
        lastSent = .distantPast
        updatesSent = 0
        isOnTrip = true
        statusMessage = String(localized: "Waiting for GPS...")
        // Keep sending the position even if the driver locks the phone or opens another app.
        locationManager.start(inBackground: true)
        listenToWaves()
        listenToDropoffs()
    }

    var permissionText: String {
        locationManager.permissionText
    }

    // Delete: ending the trip removes the bus from every student's map.
    func endTrip() {
        locationManager.stop()
        recordTripEnd()
        stopWaves(deleteAll: true)
        stopDropoffs(deleteAll: true)
        if let id = busDocId {
            let busRef = db.collection("buses").document(id)
            // The rules accept the numbers only while the bus is running, so save them first.
            learnFromTrip(busId: id) {
                busRef.delete { error in
                    if let error = error {
                        print("Error ending trip: \(error)")
                    }
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
        if isOnTrip, location.horizontalAccuracy >= 0, location.horizontalAccuracy < 50,
           samples.last.map({ location.timestamp.timeIntervalSince($0.date) >= Self.sampleSeconds }) ?? true {
            samples.append(GPSSample(date: location.timestamp, coordinate: location.coordinate,
                                     speed: location.speed >= 0 ? location.speed : nil))
        }

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
                try busRef.setData(from: bus) { error in
                    // The server refused, for example because this bus isn't assigned
                    // to this driver today. Stop instead of pretending to share.
                    if let error = error {
                        self.endTrip()
                        self.statusMessage = String(localized: "Could not start trip: \(error.localizedDescription)")
                    }
                }
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

    // MARK: - Trip history

    // Add: who drove which bus, and when (the "trips" collection).
    private func recordTripStart(driverId: String, fleetBusId: String, scheduleId: String, routeId: String) {
        let record = TripRecord(driverId: driverId, fleetBusId: fleetBusId, scheduleId: scheduleId,
                                routeId: routeId, startedAt: Date(), endedAt: nil)
        let ref = db.collection("trips").document()
        tripRecordId = ref.documentID
        try? ref.setData(from: record)
    }

    // Update: the end time.
    private func recordTripEnd() {
        guard let id = tripRecordId else { return }
        db.collection("trips").document(id).updateData(["endedAt": Date()])
        tripRecordId = nil
    }

    // MARK: - Riders waiting ahead

    // Read: every wave for this bus, live.
    private func listenToWaves() {
        guard let id = busDocId else { return }
        wavesListener?.remove()
        wavesListener = db.collection("buses").document(id).collection("waves")
            .addSnapshotListener { snapshot, error in
                // The bus was removed (for example the admin ended the trip): stop listening.
                if error != nil {
                    self.stopWaves(deleteAll: false)
                    return
                }
                self.waves = snapshot?.documents.compactMap { try? $0.data(as: Wave.self) } ?? []
                for wave in self.waves {
                    if let id = wave.id, self.seenWaves[id] == nil {
                        self.seenWaves[id] = SeenWave(coordinate: wave.coordinate, createdAt: wave.createdAt)
                    }
                }
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
        updateDropoffsAhead()
    }

    // MARK: - "Please stop here"

    private func listenToDropoffs() {
        guard let id = busDocId else { return }
        dropoffsListener?.remove()
        dropoffsListener = db.collection("buses").document(id).collection("dropoffs")
            .addSnapshotListener { snapshot, error in
                if error != nil {
                    self.stopDropoffs(deleteAll: false)
                    return
                }
                self.dropoffs = snapshot?.documents.compactMap { try? $0.data(as: Wave.self) } ?? []
                self.updateDropoffsAhead()
            }
    }

    private func stopDropoffs(deleteAll: Bool) {
        dropoffsListener?.remove()
        dropoffsListener = nil
        if deleteAll, let id = busDocId {
            for request in dropoffs {
                if let requestId = request.id {
                    db.collection("buses").document(id).collection("dropoffs").document(requestId).delete()
                }
            }
        }
        dropoffs = []
        dropoffsAhead = []
    }

    // Requests still ahead, nearest first. Passed or expired ones are removed.
    func updateDropoffsAhead() {
        guard let lat = currentLat, let lng = currentLng, routePath.count >= 2 else {
            dropoffsAhead = []
            return
        }
        let bus = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        var ahead: [(wave: Wave, metres: Double)] = []
        for request in dropoffs {
            let metres = PathMath.metresAhead(of: bus, rider: request.coordinate, path: routePath) ?? 0
            if !request.isActive() || metres < -Self.passedMetres {
                if let id = busDocId, let requestId = request.id {
                    db.collection("buses").document(id).collection("dropoffs").document(requestId).delete()
                }
            } else {
                ahead.append((request, max(metres, 0)))
            }
        }
        ahead.sort { $0.metres < $1.metres }
        if ahead.count > dropoffsAhead.count {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            AudioServicesPlaySystemSound(1315)
        }
        dropoffsAhead = ahead
    }

    // MARK: - Travel model

    // Turns this trip's track into stretch times, stop times and wave outcomes,
    // saves them, then calls `done` (also after a timeout, so ending never hangs).
    private func learnFromTrip(busId: String, done: @escaping () -> Void) {
        guard hasCreatedDocument, let route = tripRoute, let routeId = route.id, let driverId = tripDriverId else {
            done()
            return
        }
        let line = RouteLine(routeId: routeId, path: routePath, stops: route.stops.map { $0.coordinate })
        let observations = TripLearner.learn(samples: samples, line: line, waves: Array(seenWaves.values))
        samples = []
        seenWaves = [:]
        var finished = false
        let finish = {
            guard !finished else { return }
            finished = true
            done()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.uploadTimeout, execute: finish)
        StatsStore.shared.upload(observations, routeId: routeId, busId: busId, driverId: driverId, done: finish)
    }
}

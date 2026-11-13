//
//  BusViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Rider side: listens to running buses, works out ETAs, loads route paths
//  for the map and sends crowd reports and "I'm waiting here" waves.
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
    @Published var etaInfo: [String: RouteInfo] = [:]   // bus ID -> latest ETA (minutes and distance)

    // Set by the map screen from the rider's profile.
    var favoriteStop: Stop?
    var viewerRole: UserRole = .student
    // A place from "My places" the rider boards at instead of their official stop.
    var boardingPlace: MyPlace?

    // Today's timetable, so the app can see how late each bus left (smart suggestions).
    var schedules: [BusSchedule] = []
    private var delayCheckedBusIds = Set<String>()

    // The bus this rider is waving at, if any. One wave at a time.
    @Published var wavingAtBusId: String?
    static let wavingAtKey = "wavingAtBusId"
    static let wavingUntilKey = "wavingUntil"

    init() {
        // A wave sent before the app was closed, if it hasn't run out yet.
        let until = UserDefaults.standard.double(forKey: Self.wavingUntilKey)
        if until > Date().timeIntervalSince1970 {
            wavingAtBusId = UserDefaults.standard.string(forKey: Self.wavingAtKey)
        }
    }

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
                // Stops are needed for the progress track, so load each route once.
                self.loadRoute(for: bus)
                self.refreshETA(for: bus)
                self.learnDelay(for: bus)
                // Crowd or signal changes reach the Lock Screen straight away.
                LiveActivityManager.shared.refresh(bus: bus)
            }

            // The bus I waved at finished its trip, so the wave is gone too.
            if let waved = self.wavingAtBusId, !allBuses.contains(where: { $0.id == waved }) {
                self.wavingAtBusId = nil
            }

            // The followed bus is gone: the driver ended the trip.
            let live = LiveActivityManager.shared
            if let followed = live.followedBusId, !self.buses.contains(where: { $0.id == followed }) {
                live.stop()
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

    // Where this rider gets on this bus, and what to call it.
    // A place from "My places" is moved onto the bus's road path (where the bus really passes).
    // Otherwise it is the rider's official stop.
    func boardingPoint(for bus: Bus) -> (name: String, coordinate: CLLocationCoordinate2D)? {
        if let place = boardingPlace {
            let path = routePaths[bus.routeId] ?? routeStops[bus.routeId]?.map { $0.coordinate } ?? []
            let point = PathMath.snap(place.coordinate, to: path)?.point ?? place.coordinate
            return (place.label, point)
        }
        if let stop = favoriteStop {
            return (stop.name, stop.coordinate)
        }
        return nil
    }

    // The same boarding point as a short key for smart suggestions: "place:p1" or "stop:Fulbarigate".
    var boardingKey: (key: String, name: String)? {
        if let place = boardingPlace, let id = place.id {
            return ("place:\(id)", place.label)
        }
        if let stop = favoriteStop {
            return ("stop:\(stop.name)", stop.name)
        }
        return nil
    }

    // Smart suggestions: remember this moment, on this phone only.
    func remember(_ kind: RideEventKind, bus: Bus) {
        guard let boarding = boardingKey else { return }
        RideHistory.shared.record(kind, tripTitle: bus.number, routeId: bus.routeId,
                                  boardingKey: boarding.key, boardingName: boarding.name)
    }

    // The first time a bus is seen near the start of its route, compare the time
    // with the timetable to learn how late that trip usually leaves.
    func learnDelay(for bus: Bus, now: Date = Date()) {
        guard let busId = bus.id, !delayCheckedBusIds.contains(busId),
              let scheduleId = bus.scheduleId,
              let schedule = schedules.first(where: { $0.id == scheduleId }),
              let departure = BusSchedule.minutes(from: schedule.campusTime),
              let nearest = nearestStop(for: bus) else { return }
        delayCheckedBusIds.insert(busId)
        // Only when the bus is still at its first stop; otherwise we saw it too late to tell.
        guard nearest.index == 0 else { return }
        let late = Double(BusSchedule.minutesNow(now) - departure)
        RideHistory.shared.recordDelay(trip: bus.number, minutesLate: late)
    }

    // How far the bus is from KUET to my stop, for the progress track.
    // nil when my stop isn't on this bus's route (or the route hasn't loaded yet).
    func tripProgress(for bus: Bus) -> TripProgress? {
        if boardingPlace != nil {
            guard let stops = routeStops[bus.routeId], let point = boardingPoint(for: bus) else { return nil }
            let progress = TripProgress.make(bus: bus.coordinate, stops: stops.map { $0.coordinate },
                                             target: point.coordinate)
            return progress == .empty ? nil : progress
        }
        guard let stop = favoriteStop, let stops = routeStops[bus.routeId],
              let index = stops.firstIndex(where: { $0.name == stop.name }), index > 0 else {
            return nil
        }
        return TripProgress.make(bus: bus.coordinate, stops: stops.map { $0.coordinate }, stopIndex: index)
    }

    // Shows this bus's ETA on the Lock Screen and in the Dynamic Island.
    func follow(_ bus: Bus) {
        guard let point = boardingPoint(for: bus) else { return }
        let info = bus.id.flatMap { etaInfo[$0] }
        LiveActivityManager.shared.start(bus: bus, stopName: point.name,
                                         etaMinutes: info?.minutes, distanceKm: info?.kilometres,
                                         progress: tripProgress(for: bus) ?? .empty)
        refreshETA(for: bus, force: true)
        remember(.followed, bus: bus)
    }

    // Update: anyone allowed on the bus can report how crowded it is.
    func report(_ crowd: CrowdLevel, for bus: Bus) {
        guard let id = bus.id else { return }
        db.collection("buses").document(id).updateData(["crowd": crowd.rawValue])
    }

    func refreshETA(for bus: Bus, force: Bool = false) {
        guard let busId = bus.id, let point = boardingPoint(for: bus) else { return }

        // The public routing server has fair-use limits, so ask at most every 30 seconds.
        if !force, let last = lastEtaFetch[busId],
           Date().timeIntervalSince(last) < Self.etaRefreshSeconds {
            return
        }
        lastEtaFetch[busId] = Date()

        etaService.fetchETA(from: bus.coordinate, to: point.coordinate) { info in
            guard let info = info else {
                self.etaText[busId] = String(localized: "ETA unavailable")
                return
            }
            self.etaText[busId] = info.summary
            self.etaPaths[busId] = info.path
            self.etaInfo[busId] = info
            let progress = self.tripProgress(for: bus) ?? .empty
            LiveActivityManager.shared.update(bus: bus, etaMinutes: info.minutes,
                                              distanceKm: info.kilometres, progress: progress)
            // Share it with the home screen widget too.
            WidgetSync.saveLive(LiveTripSnapshot(busNumber: bus.number, stopName: point.name,
                                                 etaMinutes: info.minutes, distanceKm: info.kilometres,
                                                 crowd: bus.crowd.rawValue, progress: progress,
                                                 busLat: bus.lat, busLng: bus.lng, updatedAt: Date()))
            self.checkArrivalAlert(bus: bus, minutes: info.minutes)
            self.checkBoarded(bus: bus, info: info, at: point.coordinate)
        }
    }

    private func checkArrivalAlert(bus: Bus, minutes: Int) {
        guard let busId = bus.id else { return }
        let alertsOn = UserDefaults.standard.bool(forKey: "arrivalAlertOn")
        guard alertsOn,
              minutes <= NotificationManager.alertMinutes,
              !alertedBusIds.contains(busId) else { return }

        alertedBusIds.insert(busId)
        remember(.alerted, bus: bus)
        NotificationManager.shared.sendArrivalAlert(busNumber: bus.number,
                                                    stopName: boardingPoint(for: bus)?.name ?? String(localized: "your stop"),
                                                    minutes: minutes)
    }

    // The bus is at my boarding point and so am I: I probably got on. Remembered once a day.
    private func checkBoarded(bus: Bus, info: RouteInfo, at point: CLLocationCoordinate2D) {
        guard info.kilometres < 0.2, let me = CLLocationManager().location else { return }
        let boardingPoint = CLLocation(latitude: point.latitude, longitude: point.longitude)
        if me.distance(from: boardingPoint) < 300 {
            remember(.boarded, bus: bus)
        }
    }

    // MARK: - "I'm waiting here"

    // Add: tells this bus's driver where the rider is waiting, for 15 minutes.
    // Any earlier wave (on another bus) is removed first: one wave per rider.
    func wave(at bus: Bus, uid: String) {
        guard let point = boardingPoint(for: bus) else { return }
        wave(at: bus, uid: uid, label: point.name, point: point.coordinate)
    }

    // MARK: - "Please stop here"

    // Tells the driver where this rider wants to get off (buses/{busId}/dropoffs/{uid}).
    static let dropoffLifetime: TimeInterval = 90 * 60

    func requestDropoff(at bus: Bus, uid: String, label: String, point: CLLocationCoordinate2D) {
        guard let busId = bus.id else { return }
        let now = Date()
        let request = Wave(uid: uid, label: String(label.prefix(60)), lat: point.latitude, lng: point.longitude,
                           createdAt: now, expiresAt: now.addingTimeInterval(Self.dropoffLifetime))
        do {
            try db.collection("buses").document(busId).collection("dropoffs").document(uid).setData(from: request)
        } catch {
            print("Could not send drop-off request: \(error)")
        }
    }

    func cancelDropoff(busId: String, uid: String) {
        db.collection("buses").document(busId).collection("dropoffs").document(uid).delete()
    }

    // Waves from a chosen point (best place to wait) instead of the usual boarding point.
    func wave(at bus: Bus, uid: String, label: String, point: CLLocationCoordinate2D) {
        guard let busId = bus.id else { return }
        if let old = wavingAtBusId, old != busId {
            db.collection("buses").document(old).collection("waves").document(uid).delete()
        }
        let now = Date()
        let wave = Wave(uid: uid, label: String(label.prefix(60)), lat: point.latitude, lng: point.longitude,
                        createdAt: now, expiresAt: now.addingTimeInterval(Wave.lifetime))
        do {
            try db.collection("buses").document(busId).collection("waves").document(uid).setData(from: wave)
            wavingAtBusId = busId
            remember(.waved, bus: bus)
            UserDefaults.standard.set(busId, forKey: Self.wavingAtKey)
            UserDefaults.standard.set(wave.expiresAt.timeIntervalSince1970, forKey: Self.wavingUntilKey)
        } catch {
            print("Could not send wave: \(error)")
        }
    }

    // Delete: the rider changed their mind.
    func cancelWave(uid: String) {
        guard let busId = wavingAtBusId else { return }
        db.collection("buses").document(busId).collection("waves").document(uid).delete()
        wavingAtBusId = nil
        UserDefaults.standard.removeObject(forKey: Self.wavingAtKey)
    }
}

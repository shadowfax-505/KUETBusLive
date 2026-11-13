//
//  StatsStore.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Reads and writes the learned travel model in Firestore (segmentStats,
//  spotStats, driverStats; see docs/data-model.md). Writes are transactions:
//  read the current numbers, add one trip, write them back, so two buses
//  finishing at the same moment can't overwrite each other.
//

import Foundation
import CoreLocation
import FirebaseFirestore

final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    // What the planners need for one route.
    struct RouteStats {
        var profile = SegmentProfile(stats: [:])
        var spots: [SpotStat] = []
        var updated = Date.distantPast
    }

    struct SpotStat: Equatable {
        var coordinate: CLLocationCoordinate2D
        var asks: Int
        var stops: Int
        var dropoffs: Int

        static func == (a: SpotStat, b: SpotStat) -> Bool {
            a.asks == b.asks && a.stops == b.stops && a.dropoffs == b.dropoffs
                && a.coordinate.latitude == b.coordinate.latitude && a.coordinate.longitude == b.coordinate.longitude
        }
    }

    @Published private(set) var routes: [String: RouteStats] = [:]
    // Driver uid -> chance they stop for a wave, (stops + 1) / (asks + 2).
    @Published private(set) var waveRates: [String: Double] = [:]

    private let db = Firestore.firestore()
    // Numbers change slowly, so read each route at most every ten minutes.
    static let refreshSeconds: TimeInterval = 600

    // MARK: Reading

    func load(route routeId: String, driver: String?) {
        if let driver, waveRates[driver] == nil {
            db.collection("driverStats").document(driver).getDocument { snapshot, _ in
                let asks = snapshot?.get("asks") as? Int ?? 0
                let stops = snapshot?.get("stops") as? Int ?? 0
                self.waveRates[driver] = Double(stops + 1) / Double(asks + 2)
            }
        }
        if let known = routes[routeId], Date().timeIntervalSince(known.updated) < Self.refreshSeconds {
            return
        }
        routes[routeId, default: RouteStats()].updated = Date()

        db.collection("segmentStats").whereField("routeId", isEqualTo: routeId).getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("Could not load travel times: \(error?.localizedDescription ?? "")")
                return
            }
            var stats: [String: RunningStat] = [:]
            for document in documents {
                let data = document.data()
                stats[document.documentID] = RunningStat(n: data["n"] as? Int ?? 0,
                                                         mean: data["mean"] as? Double ?? 0,
                                                         variance: data["variance"] as? Double ?? 0)
            }
            self.routes[routeId, default: RouteStats()].profile = SegmentProfile(stats: stats)
        }
        db.collection("spotStats").whereField("routeId", isEqualTo: routeId).getDocuments { snapshot, _ in
            let spots = snapshot?.documents.compactMap { document -> SpotStat? in
                let data = document.data()
                guard let lat = data["lat"] as? Double, let lng = data["lng"] as? Double else { return nil }
                return SpotStat(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                                asks: data["asks"] as? Int ?? 0, stops: data["stops"] as? Int ?? 0,
                                dropoffs: data["dropoffs"] as? Int ?? 0)
            } ?? []
            self.routes[routeId, default: RouteStats()].spots = spots
        }
    }

    func waveRate(driver: String) -> Double {
        waveRates[driver] ?? 0.5
    }

    // Learned spots as route points: where drivers stopped for waves, or riders got off.
    static func spotPoints(_ spots: [SpotStat], line: RouteLine, nearestStopName: (Double) -> String,
                           forDropOff: Bool) -> [RoutePoint] {
        spots.compactMap { spot in
            // A drop-off spot counts once riders used it twice; a wave spot once asked.
            guard forDropOff ? spot.dropoffs >= 2 : spot.asks >= 1 else { return nil }
            guard let snap = PathMath.snap(spot.coordinate, to: line.path), snap.distanceFromRoute < 40 else {
                return nil
            }
            // Riders getting off is good evidence the bus stops there.
            let stops = spot.stops + (forDropOff ? spot.dropoffs : 0)
            let asks = spot.asks + (forDropOff ? spot.dropoffs : 0)
            return RoutePoint(name: nearestStopName(snap.distanceAlong), coordinate: snap.point,
                              along: snap.distanceAlong, kind: .spot(stops: stops, asks: asks))
        }
    }

    // MARK: Writing (driver, at the end of a trip)

    // Adds one finished trip. Calls `done` when every write has finished or failed.
    func upload(_ observations: TripObservations, routeId: String, busId: String, driverId: String,
                done: @escaping () -> Void) {
        let group = DispatchGroup()
        for stretch in observations.stretches {
            let bucket = TimeBucket(stretch.startedAt)
            let base: [String: Any] = ["routeId": routeId, "kind": "travel", "index": stretch.segment]
            var slotted = base
            slotted["dayType"] = bucket.dayType.rawValue
            slotted["slot"] = bucket.slot
            var mine = slotted
            mine["driverId"] = driverId
            add(stretch.seconds, to: StatKey.travel(route: routeId, segment: stretch.segment, bucket: bucket, driver: driverId),
                fields: mine, busId: busId, group: group)
            add(stretch.seconds, to: StatKey.travel(route: routeId, segment: stretch.segment, bucket: bucket),
                fields: slotted, busId: busId, group: group)
            add(stretch.seconds, to: StatKey.travel(route: routeId, segment: stretch.segment),
                fields: base, busId: busId, group: group)
        }
        for stop in observations.stopTimes {
            add(stop.seconds, to: StatKey.dwell(route: routeId, stop: stop.stop),
                fields: ["routeId": routeId, "kind": "dwell", "index": stop.stop], busId: busId, group: group)
        }
        // Waves one after another: each is +1 on the same driver record.
        let waves = observations.waves
        group.enter()
        recordWaves(waves[...], routeId: routeId, busId: busId, driverId: driverId) { group.leave() }
        group.notify(queue: .main, execute: done)
    }

    private func add(_ value: Double, to id: String, fields: [String: Any], busId: String, group: DispatchGroup) {
        group.enter()
        let ref = db.collection("segmentStats").document(id)
        db.runTransaction({ transaction, _ -> Any? in
            let current = try? transaction.getDocument(ref)
            var stat = RunningStat(n: current?.get("n") as? Int ?? 0,
                                   mean: current?.get("mean") as? Double ?? 0,
                                   variance: current?.get("variance") as? Double ?? 0)
            stat.add(value)
            var data = fields
            data["n"] = stat.n
            data["mean"] = stat.mean
            data["variance"] = stat.variance
            data["lastBusId"] = busId
            data["updatedAt"] = FieldValue.serverTimestamp()
            transaction.setData(data, forDocument: ref)
            return nil
        }) { _, error in
            if let error {
                print("Could not save travel time \(id): \(error.localizedDescription)")
            }
            group.leave()
        }
    }

    private func recordWaves(_ waves: ArraySlice<TripObservations.WaveOutcome>, routeId: String, busId: String,
                             driverId: String, done: @escaping () -> Void) {
        guard let wave = waves.first else {
            done()
            return
        }
        let spotRef = db.collection("spotStats").document(SpotKey.id(route: routeId, coordinate: wave.coordinate))
        let driverRef = db.collection("driverStats").document(driverId)
        let cell = SpotKey.snapped(wave.coordinate)
        db.runTransaction({ transaction, _ -> Any? in
            let spot = try? transaction.getDocument(spotRef)
            let driver = try? transaction.getDocument(driverRef)
            let stopped = wave.stopped ? 1 : 0
            transaction.setData([
                "routeId": routeId,
                "lat": spot?.get("lat") as? Double ?? cell.latitude,
                "lng": spot?.get("lng") as? Double ?? cell.longitude,
                "asks": (spot?.get("asks") as? Int ?? 0) + 1,
                "stops": (spot?.get("stops") as? Int ?? 0) + stopped,
                "dropoffs": spot?.get("dropoffs") as? Int ?? 0,
                "lastBusId": busId,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: spotRef)
            transaction.setData([
                "asks": (driver?.get("asks") as? Int ?? 0) + 1,
                "stops": (driver?.get("stops") as? Int ?? 0) + stopped,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: driverRef)
            return nil
        }) { _, error in
            if let error {
                print("Could not save wave outcome: \(error.localizedDescription)")
            }
            self.recordWaves(waves.dropFirst(), routeId: routeId, busId: busId, driverId: driverId, done: done)
        }
    }

    // MARK: Writing (rider, after getting off)

    // One more rider got off here. No uid is saved.
    func addDropoff(route routeId: String, at coordinate: CLLocationCoordinate2D) {
        let ref = db.collection("spotStats").document(SpotKey.id(route: routeId, coordinate: coordinate))
        let cell = SpotKey.snapped(coordinate)
        db.runTransaction({ transaction, _ -> Any? in
            let spot = try? transaction.getDocument(ref)
            if let spot, spot.exists {
                transaction.updateData(["dropoffs": (spot.get("dropoffs") as? Int ?? 0) + 1,
                                        "updatedAt": FieldValue.serverTimestamp()], forDocument: ref)
            } else {
                transaction.setData(["routeId": routeId, "lat": cell.latitude, "lng": cell.longitude,
                                     "asks": 0, "stops": 0, "dropoffs": 1,
                                     "updatedAt": FieldValue.serverTimestamp()], forDocument: ref)
            }
            return nil
        }) { _, error in
            if let error {
                print("Could not save drop-off: \(error.localizedDescription)")
            }
        }
    }
}

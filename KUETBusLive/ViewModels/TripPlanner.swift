//
//  TripPlanner.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Rider side of "best place to wait" and "best place to get off". It feeds the
//  planners in CatchPoint.swift with the selected bus, the route, the learned
//  numbers (StatsStore) and the rider's own position and walking speed, and asks
//  Apple Maps for the walking route to show on the map.
//
//  It also notices when the rider rides a bus and gets off: the phone stays next
//  to the bus for a while, then moves away from it. Where that happens is added
//  to the shared numbers as one anonymous drop-off, so suggestions improve.
//

import SwiftUI
import MapKit
import CoreLocation

// The rider's position while the map is open, used for walking times. It also
// learns how fast this rider walks (kept on the phone only).
final class RiderLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    private(set) var walking = WalkingSpeed.load()
    private let manager = CLLocationManager()
    private var unsaved = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 5
        manager.activityType = .otherNavigation
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        walking.save()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        location = latest
        if latest.horizontalAccuracy >= 0, latest.horizontalAccuracy < 20, latest.speed >= 0 {
            walking.add(speed: latest.speed)
            unsaved += 1
            if unsaved >= 10 {
                walking.save()
                unsaved = 0
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

// A place the rider wants to go: from search or "My places".
struct Destination: Equatable {
    var name: String
    var coordinate: CLLocationCoordinate2D

    static func == (a: Destination, b: Destination) -> Bool {
        a.name == b.name && a.coordinate.latitude == b.coordinate.latitude
            && a.coordinate.longitude == b.coordinate.longitude
    }
}

final class TripPlanner: ObservableObject {
    @Published private(set) var catchPlan: CatchPlan?
    @Published private(set) var catchWalk: [CLLocationCoordinate2D] = []
    @Published var destination: Destination?
    @Published private(set) var dropPlan: DropPlan?
    @Published private(set) var dropWalk: [CLLocationCoordinate2D] = []
    @Published private(set) var options: [TripOption] = []
    // The bus the rider is riding right now, if the phone thinks so.
    @Published private(set) var ridingBusId: String?
    // The drop-off request this rider sent, by bus.
    @Published private(set) var requestedBusId: String?

    private var lines: [String: RouteLine] = [:]
    private var walkFetchedFor: [String: CLLocationCoordinate2D] = [:]

    // MARK: Route geometry

    func line(for routeId: String, busViewModel: BusViewModel) -> RouteLine? {
        guard let stops = busViewModel.routeStops[routeId], stops.count >= 2 else { return nil }
        let path = busViewModel.routePaths[routeId] ?? []
        // Rebuilt once the road path arrives (until then the stops are joined by straight lines).
        if let cached = lines[routeId], cached.path.count == (path.count >= 2 ? path.count : stops.count) {
            return cached
        }
        let line = RouteLine(routeId: routeId, path: path, stops: stops.map(\.coordinate))
        lines[routeId] = line
        return line
    }

    // The route laid out the way this bus is driving: from its compass heading, or
    // else from whether it moved forwards or backwards since last time.
    private var lastAlong: [String: Double] = [:]
    private var backwards: [String: Bool] = [:]

    func directedLine(for bus: Bus, busViewModel: BusViewModel) -> RouteLine? {
        guard let forward = line(for: bus.routeId, busViewModel: busViewModel), let busId = bus.id else { return nil }
        if let heading = bus.heading, (bus.speed ?? 0) > 1 {
            backwards[busId] = forward.isAgainst(heading: heading, at: bus.coordinate)
        } else {
            let along = forward.along(bus.coordinate)
            if let last = lastAlong[busId], abs(along - last) > 20 {
                backwards[busId] = along < last
            }
            lastAlong[busId] = along
        }
        return backwards[busId] == true ? forward.flipped() : forward
    }

    // Stops in the same order as the line.
    private func ordered(_ stops: [Stop], _ line: RouteLine) -> [Stop] {
        line.reversed ? Array(stops.reversed()) : stops
    }

    private func stopName(_ stops: [Stop], line: RouteLine) -> (Double) -> String {
        { along in
            let index = line.stopAlong.enumerated().min { abs($0.element - along) < abs($1.element - along) }?.offset ?? 0
            return index < stops.count ? stops[index].displayName : ""
        }
    }

    private func timing(for bus: Bus, line: RouteLine, at date: Date = Date(), busViewModel: BusViewModel) -> RouteTiming {
        let stats = StatsStore.shared.routes[bus.routeId]?.profile ?? SegmentProfile(stats: [:])
        // The router's own speed for this bus, when it has answered, calibrates the fallback.
        let routerSpeed = bus.id.flatMap { busViewModel.etaInfo[$0] }.map { $0.distance / max($0.duration, 1) }
        return RouteTiming(line: line, profile: stats, bucket: TimeBucket(date), driver: bus.driverId,
                           routerSpeed: routerSpeed)
    }

    // MARK: Updating

    // Called when the bus or the rider moves.
    func update(bus: Bus, busViewModel: BusViewModel, rider: CLLocation?) {
        StatsStore.shared.load(route: bus.routeId, driver: bus.driverId)
        guard let line = directedLine(for: bus, busViewModel: busViewModel),
              let routeStops = busViewModel.routeStops[bus.routeId] else { return }
        let stops = ordered(routeStops, line)
        let busAlong = line.along(bus.coordinate)
        let timing = timing(for: bus, line: line, busViewModel: busViewModel)
        let names = stops.map(\.displayName)
        let nameFor = stopName(stops, line: line)
        let spots = StatsStore.shared.routes[bus.routeId]?.spots ?? []
        let waveRate = StatsStore.shared.waveRate(driver: bus.driverId)
        let walking = WalkingSpeed.load()

        let onBoard = ridingBusId == bus.id

        // Best place to wait.
        if !onBoard, let rider {
            let candidates = CatchPlanner.candidates(
                line: line, stopNames: names,
                spots: StatsStore.spotPoints(spots, line: line, nearestStopName: nameFor, forDropOff: false),
                after: busAlong, near: rider.coordinate)
            var plan = CatchPlanner.bestCatch(rider: rider.coordinate, busAlong: busAlong, candidates: candidates,
                                              timing: timing, walking: walking, driverWaveRate: waveRate)
            // Use the real walking distance once Apple Maps has answered for this point.
            if let fetched = walkFetchedFor["catch"], let point = plan?.point,
               CatchPlanner.distance(fetched, point.coordinate) < 1, let metres = catchWalkMetres {
                plan?.walkSeconds = metres / walking.metresPerSecond
            }
            if plan?.point != catchPlan?.point {
                catchWalk = []
                catchWalkMetres = nil
            }
            catchPlan = plan
            if let plan {
                fetchWalk(key: "catch", from: rider.coordinate, to: plan.point.coordinate) { coordinates, metres in
                    self.catchWalk = coordinates
                    self.catchWalkMetres = metres
                }
            }
        } else {
            catchPlan = nil
            catchWalk = []
        }

        // Best place to get off.
        if let destination {
            let boardAlong = onBoard ? busAlong
                : (catchPlan?.point.along ?? busViewModel.boardingPoint(for: bus).map { line.along($0.coordinate) } ?? busAlong)
            let candidates = CatchPlanner.candidates(
                line: line, stopNames: names,
                spots: StatsStore.spotPoints(spots, line: line, nearestStopName: nameFor, forDropOff: true),
                after: boardAlong, near: destination.coordinate)
            let plan = CatchPlanner.bestDrop(destination: destination.coordinate, busAlong: busAlong,
                                             boardAlong: boardAlong, candidates: candidates, timing: timing,
                                             walking: walking, driverWaveRate: waveRate)
            if plan?.point != dropPlan?.point {
                dropWalk = []
            }
            dropPlan = plan
            if let plan {
                fetchWalk(key: "drop", from: plan.point.coordinate, to: destination.coordinate) { coordinates, _ in
                    self.dropWalk = coordinates
                }
            }
        } else {
            dropPlan = nil
            dropWalk = []
        }
    }

    private var catchWalkMetres: Double?

    // Apple Maps walking directions, asked again only when the end point moves.
    private func fetchWalk(key: String, from: CLLocationCoordinate2D, to: CLLocationCoordinate2D,
                           done: @escaping ([CLLocationCoordinate2D], Double) -> Void) {
        if let last = walkFetchedFor[key], CatchPlanner.distance(last, to) < 1 { return }
        walkFetchedFor[key] = to
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .walking
        MKDirections(request: request).calculate { response, _ in
            guard let route = response?.routes.first else { return }
            let points = route.polyline.points()
            let coordinates = (0..<route.polyline.pointCount).map { points[$0].coordinate }
            DispatchQueue.main.async { done(coordinates, route.distance) }
        }
    }

    func clear() {
        catchPlan = nil
        catchWalk = []
        dropPlan = nil
        dropWalk = []
        walkFetchedFor = [:]
    }

    // MARK: Comparing buses

    // Every running bus the rider may take, plus today's trips that haven't started,
    // ranked by when they would get the rider to the destination.
    func compare(destination: Destination, buses: [Bus], busViewModel: BusViewModel, routes: [BusRoute],
                 schedules: [BusSchedule], rider: CLLocation?, now: Date = Date()) {
        var found: [TripOption] = []
        let walking = WalkingSpeed.load()
        for bus in buses {
            guard let line = directedLine(for: bus, busViewModel: busViewModel),
                  let routeStops = busViewModel.routeStops[bus.routeId] else { continue }
            let stops = ordered(routeStops, line)
            if let option = option(title: PlaceNames.display(bus.number), routeId: bus.routeId, driver: bus.driverId,
                                   line: line, stops: stops, busAlong: line.along(bus.coordinate), startsIn: 0,
                                   destination: destination, rider: rider, walking: walking, now: now,
                                   routerBus: bus, busViewModel: busViewModel) {
                found.append(option)
            }
        }
        // Trips later today, on a route whose name has the trip's city spot: leaving KUET
        // at the campus time (the route's own order), or leaving the spot at the spot
        // time (driven back to KUET).
        let nowMinutes = BusSchedule.minutesNow(now)
        for schedule in schedules where schedule.runsToday {
            guard let route = routes.first(where: { $0.name.localizedCaseInsensitiveContains(schedule.spot) }),
                  let routeId = route.id, route.stops.count >= 2 else { continue }
            let forward = lines[routeId] ?? RouteLine(routeId: routeId, path: busViewModel.routePaths[routeId] ?? [],
                                                      stops: route.stops.map(\.coordinate))
            StatsStore.shared.load(route: routeId, driver: nil)
            for (time, line) in [(schedule.campusTime, forward), (schedule.spotTime, forward.flipped())] {
                guard let departure = BusSchedule.minutes(from: time), departure > nowMinutes else { continue }
                let startsIn = Double(departure - nowMinutes) * 60
                if let option = option(title: schedule.displayTitle + " · " + BusSchedule.display(time),
                                       routeId: routeId, driver: nil, line: line,
                                       stops: ordered(route.stops, line), busAlong: 0, startsIn: startsIn,
                                       destination: destination, rider: rider, walking: walking, now: now,
                                       routerBus: nil, busViewModel: busViewModel) {
                    found.append(option)
                }
            }
        }
        options = TripOption.ranked(found)
    }

    private func option(title: String, routeId: String, driver: String?, line: RouteLine, stops: [Stop],
                        busAlong: Double, startsIn: Double, destination: Destination, rider: CLLocation?,
                        walking: WalkingSpeed, now: Date, routerBus: Bus?, busViewModel: BusViewModel) -> TripOption? {
        let stats = StatsStore.shared.routes[routeId]?.profile ?? SegmentProfile(stats: [:])
        // Same calibration as the trip card, so both show the same times.
        let routerSpeed = routerBus.flatMap { $0.id }.flatMap { busViewModel.etaInfo[$0] }
            .map { $0.distance / max($0.duration, 1) }
        let timing = RouteTiming(line: line, profile: stats, bucket: TimeBucket(now.addingTimeInterval(startsIn)),
                                 driver: driver, routerSpeed: routerSpeed)
        let names = stops.map(\.displayName)
        let rate = driver.map { StatsStore.shared.waveRate(driver: $0) } ?? 0.5
        var catchPlan: CatchPlan?
        var boardAlong = busAlong
        if let rider {
            let candidates = CatchPlanner.candidates(line: line, stopNames: names, spots: [], after: busAlong,
                                                     near: rider.coordinate)
            catchPlan = CatchPlanner.bestCatch(rider: rider.coordinate, busAlong: busAlong, candidates: candidates,
                                               timing: timing, walking: walking, driverWaveRate: rate,
                                               startsIn: startsIn)
            // A bus the rider can't reach in time is no option.
            guard let catchPlan else { return nil }
            boardAlong = catchPlan.point.along
        }
        let dropCandidates = CatchPlanner.candidates(line: line, stopNames: names, spots: [], after: boardAlong,
                                                     near: destination.coordinate)
        guard let drop = CatchPlanner.bestDrop(destination: destination.coordinate, busAlong: busAlong,
                                               boardAlong: boardAlong, candidates: dropCandidates, timing: timing,
                                               walking: walking, driverWaveRate: rate) else { return nil }
        return TripOption(title: title, startsIn: startsIn, catchPlan: catchPlan, dropPlan: drop)
    }

    // MARK: Riding, and learning where riders get off

    private var detectors: [String: OnBoardDetector] = [:]
    private var lastOnBoard: CLLocationCoordinate2D?
    private var ridingRouteId: String?

    // Called on every rider position, for every running bus. The rider counts as on
    // a bus after a minute alongside it (OnBoardDetector); leaving it again records
    // one anonymous drop-off where the phone last travelled with the bus.
    func trackRides(buses: [Bus], rider: CLLocation?, busViewModel: BusViewModel, now: Date = Date()) {
        guard let rider else { return }
        let riderSpeed = rider.speed >= 0 ? rider.speed : nil
        for bus in buses where !bus.isStale {
            guard let busId = bus.id else { continue }
            var detector = detectors[busId] ?? OnBoardDetector()
            let onBoard = detector.update(rider: rider.coordinate, riderSpeed: riderSpeed, bus: bus.coordinate,
                                          busHeading: bus.heading, busSpeed: bus.speed,
                                          busUpdatedAt: bus.updatedAt, at: now)
            detectors[busId] = detector
            if onBoard {
                ridingBusId = busId
                ridingRouteId = bus.routeId
                lastOnBoard = rider.coordinate
            } else if ridingBusId == busId {
                if let point = lastOnBoard, let routeId = ridingRouteId {
                    let path = busViewModel.routePaths[routeId] ?? []
                    let onRoute = PathMath.snap(point, to: path)?.point ?? point
                    StatsStore.shared.addDropoff(route: routeId, at: onRoute)
                }
                ridingBusId = nil
                ridingRouteId = nil
                lastOnBoard = nil
            }
        }
        // The bus I was on finished its trip.
        if let riding = ridingBusId, !buses.contains(where: { $0.id == riding }) {
            ridingBusId = nil
        }
    }

    // MARK: "Please stop here"

    func requestStop(bus: Bus, uid: String, busViewModel: BusViewModel) {
        guard let plan = dropPlan, let destination else { return }
        busViewModel.requestDropoff(at: bus, uid: uid, label: destination.name, point: plan.point.coordinate)
        requestedBusId = bus.id
    }

    func cancelStop(uid: String, busViewModel: BusViewModel) {
        guard let busId = requestedBusId else { return }
        busViewModel.cancelDropoff(busId: busId, uid: uid)
        requestedBusId = nil
    }
}

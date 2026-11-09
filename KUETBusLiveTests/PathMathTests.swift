//
//  PathMathTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  Snapping a rider's place onto a route, and telling whether a waiting rider
//  is ahead of the bus or already passed.
//

import XCTest
import CoreLocation
@testable import KUETBusLive

final class PathMathTests: XCTestCase {
    // A straight road going north, about 2.2 km long.
    let road = [
        CLLocationCoordinate2D(latitude: 22.80, longitude: 89.50),
        CLLocationCoordinate2D(latitude: 22.81, longitude: 89.50),
        CLLocationCoordinate2D(latitude: 22.82, longitude: 89.50)
    ]

    func testSnapLandsOnTheRoad() throws {
        // About 100 m east of the middle of the road.
        let place = CLLocationCoordinate2D(latitude: 22.81, longitude: 89.50097)
        let snap = try XCTUnwrap(PathMath.snap(place, to: road))
        XCTAssertEqual(snap.point.longitude, 89.50, accuracy: 0.00001)
        XCTAssertEqual(snap.point.latitude, 22.81, accuracy: 0.00001)
        XCTAssertEqual(snap.distanceFromRoute, 100, accuracy: 5)
        XCTAssertEqual(snap.distanceAlong, 1113, accuracy: 10)
    }

    func testPlaceBeyondTheEndSnapsToTheLastPoint() throws {
        let place = CLLocationCoordinate2D(latitude: 22.83, longitude: 89.50)
        let snap = try XCTUnwrap(PathMath.snap(place, to: road))
        XCTAssertEqual(snap.point.latitude, 22.82, accuracy: 0.00001)
        XCTAssertGreaterThan(snap.distanceFromRoute, PathMath.farFromRouteMetres)
    }

    func testNoSnapWithoutARoad() {
        XCTAssertNil(PathMath.snap(road[0], to: [road[0]]))
        XCTAssertNil(PathMath.snap(road[0], to: []))
    }

    func testRiderAheadAndBehindTheBus() throws {
        let bus = CLLocationCoordinate2D(latitude: 22.805, longitude: 89.50)
        let ahead = CLLocationCoordinate2D(latitude: 22.815, longitude: 89.5002)
        let behind = CLLocationCoordinate2D(latitude: 22.801, longitude: 89.4998)
        XCTAssertEqual(try XCTUnwrap(PathMath.metresAhead(of: bus, rider: ahead, path: road)), 1113, accuracy: 15)
        XCTAssertLessThan(try XCTUnwrap(PathMath.metresAhead(of: bus, rider: behind, path: road)), 0)
    }

    func testProgressTowardsAPlaceBetweenStops() {
        // Stops at both ends and the middle; the rider waits three quarters of the way.
        let target = CLLocationCoordinate2D(latitude: 22.815, longitude: 89.50)
        let bus = CLLocationCoordinate2D(latitude: 22.8075, longitude: 89.50)
        let progress = TripProgress.make(bus: bus, stops: road, target: target)
        XCTAssertEqual(progress.fraction, 0.5, accuracy: 0.02)
        // The middle stop is passed on the way, at two thirds of the track.
        XCTAssertEqual(progress.stopFractions.count, 1)
        XCTAssertEqual(progress.stopFractions[0], 2.0 / 3.0, accuracy: 0.02)
    }

    func testOnlyFiveSlotsForPlaces() {
        XCTAssertEqual(MyPlace.slotIds, ["p1", "p2", "p3", "p4", "p5"])
    }
}

//
//  OnBoardDetectorTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  Riding a bus versus standing next to it, and the "crowded" report fading.
//

import XCTest
import CoreLocation
@testable import KUETBusLive

final class OnBoardDetectorTests: XCTestCase {

    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let base = CLLocationCoordinate2D(latitude: 22.90, longitude: 89.50)

    func north(_ metres: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: base.latitude + metres / 111_320, longitude: base.longitude)
    }

    // Bus and rider both going north at 8 m/s, `gap` metres apart, for `seconds`.
    func ride(gap: Double, riderSpeed: Double = 8, seconds: Int, detector: inout OnBoardDetector) -> Bool {
        var result = false
        for t in stride(from: 0, through: seconds, by: 5) {
            let now = start.addingTimeInterval(Double(t))
            let bus = north(8 * Double(t))
            result = detector.update(rider: north(8 * Double(t) + gap), riderSpeed: riderSpeed, bus: bus,
                                     busHeading: 0, busSpeed: 8, busUpdatedAt: now, at: now)
        }
        return result
    }

    func testRidingForAMinuteCountsAsOnBoard() {
        var short = OnBoardDetector()
        XCTAssertFalse(ride(gap: 5, seconds: 55, detector: &short))
        var long = OnBoardDetector()
        XCTAssertTrue(ride(gap: 5, seconds: 70, detector: &long))
    }

    func testStandingAtTheStopIsNotOnBoard() {
        var detector = OnBoardDetector()
        XCTAssertFalse(ride(gap: 5, riderSpeed: 0, seconds: 120, detector: &detector))
    }

    func testFollowingInACarFarBehindIsNotOnBoard() {
        var detector = OnBoardDetector()
        XCTAssertFalse(ride(gap: 80, seconds: 120, detector: &detector))
    }

    func testOldBusPositionIsMovedAhead() {
        // The bus's position is 5 s old; it has driven 40 m since.
        let now = start.addingTimeInterval(5)
        let projected = OnBoardDetector.projected(bus: north(0), heading: 0, speed: 8, updatedAt: start, now: now)
        XCTAssertEqual((projected.latitude - base.latitude) * 111_320, 40, accuracy: 0.5)
        var detector = OnBoardDetector()
        for t in stride(from: 0, through: 70, by: 5) {
            let at = start.addingTimeInterval(Double(t) + 5)
            detector.update(rider: north(8 * Double(t) + 40), riderSpeed: 8, bus: north(8 * Double(t)),
                            busHeading: 0, busSpeed: 8, busUpdatedAt: start.addingTimeInterval(Double(t)), at: at)
        }
        XCTAssertTrue(detector.isOnBoard)
    }

    func testGettingOffEndsIt() {
        var detector = OnBoardDetector()
        XCTAssertTrue(ride(gap: 5, seconds: 70, detector: &detector))
        let later = start.addingTimeInterval(80)
        XCTAssertFalse(detector.update(rider: north(0), riderSpeed: 1, bus: north(640), busHeading: 0, busSpeed: 8,
                                       busUpdatedAt: later, at: later))
    }

    func testCrowdedReportFadesAfterTenMinutes() {
        var bus = Bus(number: "Normal-1", routeId: "r1", routeName: "Rupsha", driverId: "d", lat: 0, lng: 0,
                      updatedAt: start, crowd: .full)
        XCTAssertFalse(bus.isCrowded(at: start))   // no time: an old-style report
        bus.crowdAt = start
        XCTAssertTrue(bus.isCrowded(at: start.addingTimeInterval(9 * 60)))
        XCTAssertFalse(bus.isCrowded(at: start.addingTimeInterval(11 * 60)))
    }
}

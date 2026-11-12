//
//  BusMotionTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  Headings, turning the short way round, and gliding between GPS points.
//

import XCTest
import CoreLocation
@testable import KUETBusLive

final class BusMotionTests: XCTestCase {

    let kuet = CLLocationCoordinate2D(latitude: 22.9000, longitude: 89.5000)

    func offset(north: Double = 0, east: Double = 0) -> CLLocationCoordinate2D {
        // About 111 km per degree of latitude; longitude degrees shrink with cos(latitude).
        CLLocationCoordinate2D(latitude: kuet.latitude + north / 111_320,
                               longitude: kuet.longitude + east / (111_320 * cos(kuet.latitude * .pi / 180)))
    }

    // MARK: - Bearing

    func testBearingPointsTheFourWays() {
        XCTAssertEqual(BusMotion.bearing(from: kuet, to: offset(north: 100)), 0, accuracy: 0.5)
        XCTAssertEqual(BusMotion.bearing(from: kuet, to: offset(east: 100)), 90, accuracy: 0.5)
        XCTAssertEqual(BusMotion.bearing(from: kuet, to: offset(north: -100)), 180, accuracy: 0.5)
        XCTAssertEqual(BusMotion.bearing(from: kuet, to: offset(east: -100)), 270, accuracy: 0.5)
        XCTAssertEqual(BusMotion.bearing(from: kuet, to: offset(north: 100, east: 100)), 45, accuracy: 0.5)
    }

    func testNormalizedKeepsAnglesInOneTurn() {
        XCTAssertEqual(BusMotion.normalized(370), 10)
        XCTAssertEqual(BusMotion.normalized(-10), 350)
        XCTAssertEqual(BusMotion.normalized(720), 0)
    }

    // MARK: - Turning the short way

    func testTurnAcrossNorthGoesTheShortWay() {
        XCTAssertEqual(BusMotion.shortestRotation(from: 350, to: 10), 370)
        XCTAssertEqual(BusMotion.shortestRotation(from: 10, to: 350), -10)
    }

    func testTurnFromAnUnwrappedAngle() {
        // After a few right turns the icon may be at 730° (= 10°); a turn to 20° adds 10.
        XCTAssertEqual(BusMotion.shortestRotation(from: 730, to: 20), 740)
        XCTAssertEqual(BusMotion.shortestRotation(from: -350, to: 0), -360)
    }

    func testHalfTurnAndNoTurn() {
        XCTAssertEqual(BusMotion.shortestRotation(from: 0, to: 180), 180)
        XCTAssertEqual(BusMotion.shortestRotation(from: 90, to: 90), 90)
    }

    // MARK: - Heading

    func testValidGPSCourseWins() {
        XCTAssertEqual(BusMotion.heading(course: 45, from: kuet, to: offset(north: 100)), 45)
    }

    func testMissingCourseUsesTheLastTwoPoints() {
        XCTAssertEqual(BusMotion.heading(course: -1, from: kuet, to: offset(east: 50))!, 90, accuracy: 0.5)
        XCTAssertEqual(BusMotion.heading(course: nil, from: kuet, to: offset(north: -50))!, 180, accuracy: 0.5)
    }

    func testTinyMovesAndNoHistoryGiveNoHeading() {
        XCTAssertNil(BusMotion.heading(course: nil, from: kuet, to: offset(north: 1)))
        XCTAssertNil(BusMotion.heading(course: nil, from: nil, to: kuet))
    }

    // MARK: - Gliding

    func testGlideDurationFollowsTheUpdateGapWithinLimits() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(BusMotion.glideDuration(previousUpdate: t0, newUpdate: t0 + 3), 3)
        XCTAssertEqual(BusMotion.glideDuration(previousUpdate: t0, newUpdate: t0 + 0.2), BusMotion.minGlide)
        XCTAssertEqual(BusMotion.glideDuration(previousUpdate: t0, newUpdate: t0 + 60), BusMotion.maxGlide)
        XCTAssertEqual(BusMotion.glideDuration(previousUpdate: nil, newUpdate: t0), BusMotion.minGlide)
    }

    func testFractionRunsFromZeroToOne() {
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(BusMotion.fraction(start: start, duration: 4, now: start - 1), 0)
        XCTAssertEqual(BusMotion.fraction(start: start, duration: 4, now: start + 1), 0.25)
        XCTAssertEqual(BusMotion.fraction(start: start, duration: 4, now: start + 10), 1)
        XCTAssertEqual(BusMotion.fraction(start: start, duration: 0, now: start), 1)
    }

    func testInterpolateIsAStraightLine() {
        let end = offset(north: 200, east: 100)
        let middle = BusMotion.interpolate(from: kuet, to: end, fraction: 0.5)
        XCTAssertEqual(middle.latitude, (kuet.latitude + end.latitude) / 2, accuracy: 1e-9)
        XCTAssertEqual(middle.longitude, (kuet.longitude + end.longitude) / 2, accuracy: 1e-9)
        XCTAssertEqual(BusMotion.interpolate(from: kuet, to: end, fraction: 0).latitude, kuet.latitude)
        XCTAssertEqual(BusMotion.interpolate(from: kuet, to: end, fraction: 2).latitude, end.latitude)
    }

    // MARK: - Snapping to the road

    func testSnapsOnlyWhenCloseToTheRoute() {
        let road = [kuet, offset(north: 500)]   // a straight road going north
        let near = BusMotion.snapped(offset(north: 200, east: 10), to: road)
        XCTAssertEqual(near.longitude, kuet.longitude, accuracy: 1e-7)
        let far = offset(north: 200, east: 80)
        XCTAssertEqual(BusMotion.snapped(far, to: road).longitude, far.longitude)
        XCTAssertEqual(BusMotion.snapped(far, to: nil).latitude, far.latitude)
    }
}

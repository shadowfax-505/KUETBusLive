//
//  EtaFallbackTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  The ETA estimate used when the routing server can't be reached (same as Android).
//

import XCTest
@testable import KUETBusLive

final class EtaFallbackTests: XCTestCase {

    func testUsesTheDistanceAlongTheRouteAt18KmPerHour() {
        let info = RouteInfo.estimate(alongRoute: 3_000, straightLine: 2_000)
        XCTAssertEqual(info?.minutes, 10)
        XCTAssertEqual(info?.kilometres ?? 0, 3, accuracy: 0.001)
    }

    func testWithoutARouteTheStraightLineIsMadeLongerForTheRoads() {
        XCTAssertEqual(RouteInfo.estimate(alongRoute: nil, straightLine: 2_000)?.distance ?? 0, 2_700, accuracy: 0.001)
    }

    func testABusThatPassedTheStopHasNoEstimate() {
        XCTAssertNil(RouteInfo.estimate(alongRoute: -50, straightLine: 100))
    }
}

//
//  BusAssignmentTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  Who drives each bus today: the regular driver, a cover driver, or nobody.
//

import XCTest
@testable import KUETBusLive

final class BusAssignmentTests: XCTestCase {

    // A moment given as Dhaka local time.
    func dhaka(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 10, _ minute: Int = 0) -> Date {
        BusAssignment.calendar.date(from: DateComponents(year: year, month: month, day: day,
                                                         hour: hour, minute: minute))!
    }

    func bus(regular: String?, cover: BusCover? = nil) -> FleetBus {
        FleetBus(id: "normal-2", name: "Normal-2", defaultDriverId: regular, cover: cover)
    }

    func cover(_ driver: String, from: Date, until: Date) -> BusCover {
        BusAssignment.makeCover(driverId: driver, from: from, until: until, reason: "Sick", setBy: "admin")!
    }

    func testRegularDriverWithoutCover() {
        XCTAssertEqual(BusAssignment.driver(for: bus(regular: "rahim"), on: dhaka(2026, 11, 10)), "rahim")
    }

    func testActiveCoverWins() {
        let c = cover("karim", from: dhaka(2026, 11, 10), until: dhaka(2026, 11, 12))
        let b = bus(regular: "rahim", cover: c)
        XCTAssertEqual(BusAssignment.driver(for: b, on: dhaka(2026, 11, 10)), "karim")
        XCTAssertEqual(BusAssignment.driver(for: b, on: dhaka(2026, 11, 12, 23, 59)), "karim")   // last day counts
    }

    func testExpiredCoverGivesTheBusBack() {
        let c = cover("karim", from: dhaka(2026, 11, 1), until: dhaka(2026, 11, 3))
        XCTAssertEqual(BusAssignment.driver(for: bus(regular: "rahim", cover: c), on: dhaka(2026, 11, 4)), "rahim")
    }

    func testCoverStartingTomorrowIsNotActiveYet() {
        let c = cover("karim", from: dhaka(2026, 11, 11), until: dhaka(2026, 11, 13))
        XCTAssertEqual(BusAssignment.driver(for: bus(regular: "rahim", cover: c), on: dhaka(2026, 11, 10, 23, 30)), "rahim")
    }

    func testNoRegularDriverAndNoCoverMeansNobody() {
        XCTAssertNil(BusAssignment.driver(for: bus(regular: nil), on: dhaka(2026, 11, 10)))
        // A bus whose driver left can still be covered.
        let c = cover("karim", from: dhaka(2026, 11, 10), until: dhaka(2026, 11, 10))
        XCTAssertEqual(BusAssignment.driver(for: bus(regular: nil, cover: c), on: dhaka(2026, 11, 10)), "karim")
    }

    func testDaysChangeAtMidnightInDhakaNotUTC() {
        let c = cover("karim", from: dhaka(2026, 11, 10), until: dhaka(2026, 11, 10))
        let b = bus(regular: "rahim", cover: c)
        // 00:30 on 11 Nov in Dhaka is still 10 Nov in UTC, but the cover is over.
        XCTAssertEqual(BusAssignment.driver(for: b, on: dhaka(2026, 11, 11, 0, 30)), "rahim")
        // 23:30 on 10 Nov in Dhaka is 17:30 UTC: still covered.
        XCTAssertEqual(BusAssignment.driver(for: b, on: dhaka(2026, 11, 10, 23, 30)), "karim")
    }

    func testCoverTimestampsMatchTheDays() {
        let c = cover("karim", from: dhaka(2026, 11, 10, 15), until: dhaka(2026, 11, 12, 8))
        XCTAssertEqual(c.fromDate, "2026-11-10")
        XCTAssertEqual(c.untilDate, "2026-11-12")
        XCTAssertEqual(c.start, dhaka(2026, 11, 10, 0))
        XCTAssertEqual(c.end, dhaka(2026, 11, 13, 0))
    }

    func testUntilBeforeFromBecomesOneDay() {
        let c = cover("karim", from: dhaka(2026, 11, 12), until: dhaka(2026, 11, 10))
        XCTAssertEqual(c.fromDate, "2026-11-12")
        XCTAssertEqual(c.untilDate, "2026-11-12")
    }

    func testFreeDriversExcludeBusyAndAbsentOnes() {
        func driver(_ id: String, approved: Bool = true, active: Bool = true) -> AppUser {
            AppUser(id: id, name: id, email: "\(id)@test.com", role: .driver, kuetId: "D", isApproved: approved,
                    active: active)
        }
        let fleet = [bus(regular: "rahim"), FleetBus(id: "normal-1", name: "Normal-1", defaultDriverId: "salam")]
        let drivers = [driver("rahim"), driver("salam"), driver("karim"), driver("jamal"),
                       driver("new", approved: false), driver("left", active: false)]
        let free = BusAssignment.freeDrivers(drivers, fleet: fleet, absentIds: ["jamal"], on: dhaka(2026, 11, 10))
        XCTAssertEqual(free.compactMap(\.id), ["karim"])
    }

    func testBusForADriver() {
        let c = cover("karim", from: dhaka(2026, 11, 10), until: dhaka(2026, 11, 10))
        let fleet = [bus(regular: "rahim", cover: c)]
        XCTAssertEqual(BusAssignment.bus(for: "karim", in: fleet, on: dhaka(2026, 11, 10))?.name, "Normal-2")
        XCTAssertNil(BusAssignment.bus(for: "rahim", in: fleet, on: dhaka(2026, 11, 10)))
    }

    func testFleetIds() {
        XCTAssertEqual(BusAssignment.fleetId(for: "Normal-1"), "normal-1")
        XCTAssertEqual(BusAssignment.fleetId(for: "Special-1 (AC)"), "special-1-ac")
    }
}

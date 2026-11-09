//
//  BusScheduleTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  Checks time parsing and formatting, who may ride which bus, and the "next trip" logic.
//  Fixed dates are used so the results don't depend on when the tests run.
//

import XCTest
@testable import KUETBusLive

final class BusScheduleTests: XCTestCase {

    // Builds a date like "Monday 9 November 2026, 07:30" in the phone's calendar.
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        let parts = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return Calendar.current.date(from: parts)!
    }

    private func trip(_ name: String, campus: String, spot: String = "07:10",
                      days: TripDays = .sunToThu) -> BusSchedule {
        BusSchedule(tripName: name, audience: BusAudience.from(tripName: name), days: days,
                    period: .morning, campusTime: campus, spot: "Rupsha", spotTime: spot, remarks: "")
    }

    // MARK: - minutes(from:)

    func testMinutesFromValidTimes() {
        XCTAssertEqual(BusSchedule.minutes(from: "00:00"), 0)
        XCTAssertEqual(BusSchedule.minutes(from: "06:30"), 390)
        XCTAssertEqual(BusSchedule.minutes(from: "13:30"), 810)
        XCTAssertEqual(BusSchedule.minutes(from: "23:59"), 1439)
    }

    func testMinutesFromInvalidTimes() {
        XCTAssertNil(BusSchedule.minutes(from: ""))
        XCTAssertNil(BusSchedule.minutes(from: "24:00"))
        XCTAssertNil(BusSchedule.minutes(from: "12:60"))
        XCTAssertNil(BusSchedule.minutes(from: "7"))
        XCTAssertNil(BusSchedule.minutes(from: "ab:cd"))
        XCTAssertNil(BusSchedule.minutes(from: "1:2:3"))
        XCTAssertFalse(BusSchedule.isValidTime("-1:30"))
        XCTAssertTrue(BusSchedule.isValidTime("7:05"))
    }

    // MARK: - Formatting

    func testDisplayUsesTwelveHourClock() {
        XCTAssertEqual(BusSchedule.display("06:30"), "6:30 AM")
        XCTAssertEqual(BusSchedule.display("13:05"), "1:05 PM")
        XCTAssertEqual(BusSchedule.display("00:15"), "12:15 AM")
        XCTAssertEqual(BusSchedule.display("12:00"), "12:00 PM")
        // Anything that isn't a time is shown as it is.
        XCTAssertEqual(BusSchedule.display("soon"), "soon")
    }

    func testTitle() {
        XCTAssertEqual(trip("Normal-1", campus: "06:30").title, "Normal-1 · Rupsha")
    }

    // MARK: - Who may ride

    func testAudienceComesFromTripName() {
        XCTAssertEqual(BusAudience.from(tripName: "Normal-2"), .student)
        XCTAssertEqual(BusAudience.from(tripName: "Special-1 (AC)"), .teacher)
        XCTAssertEqual(BusAudience.from(tripName: "special-3"), .teacher)
    }

    func testStudentsOnlyRideStudentBuses() {
        XCTAssertTrue(BusAudience.student.canBoard(.student))
        XCTAssertFalse(BusAudience.teacher.canBoard(.student))
    }

    func testTeachersRideAnyBus() {
        XCTAssertTrue(BusAudience.student.canBoard(.teacher))
        XCTAssertTrue(BusAudience.teacher.canBoard(.teacher))
        XCTAssertTrue(BusAudience.teacher.canBoard(.admin))
    }

    // MARK: - Days

    func testTripDays() {
        let monday = date(2026, 11, 9, 8, 0)
        let friday = date(2026, 11, 13, 8, 0)
        let saturday = date(2026, 11, 14, 8, 0)
        XCTAssertTrue(TripDays.sunToThu.includes(monday))
        XCTAssertFalse(TripDays.sunToThu.includes(friday))
        XCTAssertFalse(TripDays.saturday.includes(friday))
        XCTAssertTrue(TripDays.saturday.includes(saturday))
    }

    // MARK: - Next trip

    func testUpcomingUntilTheLastDeparture() {
        let normal = trip("Normal-1", campus: "06:30", spot: "07:10")
        XCTAssertTrue(normal.isUpcoming(at: date(2026, 11, 9, 6, 0)))
        // Left campus already, but still leaves the city spot at 07:10.
        XCTAssertTrue(normal.isUpcoming(at: date(2026, 11, 9, 7, 0)))
        XCTAssertFalse(normal.isUpcoming(at: date(2026, 11, 9, 7, 30)))
        // No buses on Friday.
        XCTAssertFalse(normal.isUpcoming(at: date(2026, 11, 13, 6, 0)))
    }

    func testNextTripPicksEarliestRideableTrip() {
        let trips = [
            trip("Normal-2", campus: "13:30", spot: "14:30"),
            trip("Special-1 (AC)", campus: "07:00", spot: "08:00"),
            trip("Normal-1", campus: "07:30", spot: "08:30")
        ]
        let morning = date(2026, 11, 9, 6, 45)

        // Students skip the teachers' Special bus.
        XCTAssertEqual(BusSchedule.nextTrip(in: trips, for: .student, at: morning)?.tripName, "Normal-1")
        // Teachers get the earliest bus of all.
        XCTAssertEqual(BusSchedule.nextTrip(in: trips, for: .teacher, at: morning)?.tripName, "Special-1 (AC)")

        let afternoon = date(2026, 11, 9, 12, 0)
        XCTAssertEqual(BusSchedule.nextTrip(in: trips, for: .student, at: afternoon)?.tripName, "Normal-2")

        let night = date(2026, 11, 9, 22, 0)
        XCTAssertNil(BusSchedule.nextTrip(in: trips, for: .student, at: night))
    }

    func testBundledTimetableLoads() {
        let trips = TimetableRow.loadBundled()
        XCTAssertFalse(trips.isEmpty)
        // Every time in the official timetable should parse.
        for trip in trips {
            XCTAssertTrue(BusSchedule.isValidTime(trip.campusTime), "\(trip.tripName) campus \(trip.campusTime)")
            XCTAssertTrue(BusSchedule.isValidTime(trip.spotTime), "\(trip.tripName) spot \(trip.spotTime)")
        }
    }
}

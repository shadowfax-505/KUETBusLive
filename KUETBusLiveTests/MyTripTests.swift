//
//  MyTripTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  "My trips": which days a pin may use, when its reminder fires, and when the
//  calendar event starts. Times are in Dhaka, whatever the phone's time zone.
//

import XCTest
@testable import KUETBusLive

final class MyTripTests: XCTestCase {

    private func schedule(days: TripDays = .sunToThu) -> BusSchedule {
        var s = BusSchedule(tripName: "Normal-1", audience: .student, days: days, period: .morning,
                            campusTime: "07:00", spot: "Rupsha", spotTime: "07:40", remarks: "")
        s.id = "s1"
        return s
    }

    func testANewPinUsesEveryDayTheTripRuns() {
        XCTAssertEqual(MyTrip.new(for: schedule()).days, ["sun", "mon", "tue", "wed", "thu"])
        XCTAssertEqual(MyTrip.new(for: schedule(days: .saturday)).days, ["sat"])
        XCTAssertEqual(MyTrip.new(for: schedule()).remindMinutes, 10)
    }

    func testReminderIsMinutesBeforeTheChosenDeparture() {
        let parts = MyTrip.reminder(weekday: 2, time: "07:00", minutesBefore: 15)
        XCTAssertEqual(parts?.weekday, 2)
        XCTAssertEqual(parts?.hour, 6)
        XCTAssertEqual(parts?.minute, 45)
        XCTAssertEqual(parts?.timeZone, BusAssignment.timeZone)
    }

    func testReminderBeforeMidnightMovesToTheDayBefore() {
        let sunday = MyTrip.reminder(weekday: 1, time: "00:10", minutesBefore: 30)
        XCTAssertEqual(sunday?.weekday, 7)
        XCTAssertEqual(sunday?.hour, 23)
        XCTAssertEqual(sunday?.minute, 40)
    }

    func testOneWeeklyReminderPerPinnedDay() {
        var trip = MyTrip.new(for: schedule())
        trip.days = ["sun", "tue"]
        trip.leg = .spot
        let requests = MyTripsViewModel.reminderRequests(trips: [trip], schedules: [schedule()])
        XCTAssertEqual(requests.map(\.identifier), ["mytrip-s1-sun", "mytrip-s1-tue"])
        trip.remindMinutes = 0
        XCTAssertTrue(MyTripsViewModel.reminderRequests(trips: [trip], schedules: [schedule()]).isEmpty)
    }

    func testATripRemovedFromTheTimetableGetsNoReminder() {
        let trip = MyTrip.new(for: schedule())
        XCTAssertTrue(MyTripsViewModel.reminderRequests(trips: [trip], schedules: []).isEmpty)
    }

    func testCalendarEventStartsAtTheNextPickedDay() {
        let calendar = BusAssignment.calendar
        // Monday 16 November 2026, 08:00 in Dhaka: Monday's 07:00 bus has gone.
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 8))!
        let start = TripCalendar.nextStart(time: "07:00", days: ["mon", "wed"], after: now)!
        let parts = calendar.dateComponents([.weekday, .day, .hour, .minute], from: start)
        XCTAssertEqual(parts.weekday, 4)
        XCTAssertEqual(parts.day, 18)
        XCTAssertEqual(parts.hour, 7)
        XCTAssertEqual(parts.minute, 0)
    }
}

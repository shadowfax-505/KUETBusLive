//
//  SmartSuggestionsTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  The "Your usual bus" scorer and the learned delays.
//

import XCTest
@testable import KUETBusLive

final class SmartSuggestionsTests: XCTestCase {
    let calendar = Calendar.current

    // A fixed Monday (a bus day) at 07:50, and helpers to make dates around it.
    var monday: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 7, minute: 50))!
    }

    func daysBefore(_ days: Int, from date: Date) -> Date {
        calendar.date(byAdding: .day, value: -days, to: date)!
    }

    func event(_ trip: String, daysAgo: Int, minute: Int = 490, from date: Date? = nil,
               boarding: String = "place:p1") -> RideEvent {
        let when = daysBefore(daysAgo, from: date ?? monday)
        return RideEvent(kind: .followed, tripTitle: trip, routeId: "r1", boardingKey: boarding,
                         boardingName: "Home", dayType: DayType(when), minuteOfDay: minute, date: when)
    }

    let normal2 = TripCandidate(title: "Normal-2 · Rupsha", departureMinute: 490)   // 08:10
    let normal1 = TripCandidate(title: "Normal-1 · Rupsha", departureMinute: 490)

    func testColdStartSuggestsNothing() {
        XCTAssertNil(SuggestionScorer.suggest(from: [normal2], events: [], now: monday, currentBoardingKey: nil))
    }

    func testUsualTripIsSuggested() {
        // Followed Normal-2 on the last three Mondays.
        let events = [7, 14, 21].map { event("Normal-2 · Rupsha", daysAgo: $0) }
        let suggestion = SuggestionScorer.suggest(from: [normal1, normal2], events: events,
                                                  now: monday, currentBoardingKey: nil)
        XCTAssertEqual(suggestion?.trip, normal2)
        XCTAssertEqual(suggestion?.boardingKey, "place:p1")
        XCTAssertEqual(suggestion?.boardingName, "Home")
    }

    func testSaturdayHabitsDoNotCountOnWeekdays() {
        let saturday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 8))!
        let saturdayEvents = [0, 7, 14].map { event("Normal-2 · Rupsha", daysAgo: $0, from: saturday) }
        XCTAssertEqual(SuggestionScorer.score(normal2, events: saturdayEvents, now: monday, currentBoardingKey: nil), 0)
        XCTAssertNil(SuggestionScorer.suggest(from: [normal2], events: saturdayEvents, now: monday, currentBoardingKey: nil))
    }

    func testOnlyEventsNearTheDepartureTimeCount() {
        let evening = [7, 14].map { event("Normal-2 · Rupsha", daysAgo: $0, minute: 17 * 60) }
        XCTAssertEqual(SuggestionScorer.score(normal2, events: evening, now: monday, currentBoardingKey: nil), 0)
    }

    func testOlderEventsCountLess() {
        XCTAssertEqual(SuggestionScorer.recencyWeight(eventDate: monday, now: monday), 1, accuracy: 0.0001)
        XCTAssertEqual(SuggestionScorer.recencyWeight(eventDate: daysBefore(21, from: monday), now: monday), 0.5, accuracy: 0.0001)
        XCTAssertEqual(SuggestionScorer.recencyWeight(eventDate: daysBefore(42, from: monday), now: monday), 0.25, accuracy: 0.0001)
        // One recent ride beats one old ride.
        let events = [event("Normal-1 · Rupsha", daysAgo: 1), event("Normal-2 · Rupsha", daysAgo: 60)]
        XCTAssertEqual(SuggestionScorer.suggest(from: [normal1, normal2], events: events, now: monday,
                                                currentBoardingKey: nil)?.trip, normal1)
    }

    func testSameBoardingPointAndBeingNearbyAddWeight() {
        let events = [event("Normal-2 · Rupsha", daysAgo: 7)]
        let plain = SuggestionScorer.score(normal2, events: events, now: monday, currentBoardingKey: nil)
        let samePlace = SuggestionScorer.score(normal2, events: events, now: monday, currentBoardingKey: "place:p1")
        let nearby = SuggestionScorer.score(normal2, events: events, now: monday, currentBoardingKey: nil,
                                            nearBoardingKey: "place:p1")
        XCTAssertEqual(samePlace, plain * 1.5, accuracy: 0.0001)
        XCTAssertEqual(nearby, plain + 1, accuracy: 0.0001)
    }

    func testTiesGoToTheEarlierTripThenTheName() {
        let early = TripCandidate(title: "B", departureMinute: 480)
        let late = TripCandidate(title: "A", departureMinute: 500)
        let events = [event("A", daysAgo: 7, minute: 500), event("B", daysAgo: 7, minute: 480)]
        XCTAssertEqual(SuggestionScorer.suggest(from: [late, early], events: events, now: monday,
                                                currentBoardingKey: nil)?.trip, early)
        let sameTime = TripCandidate(title: "C", departureMinute: 480)
        let tied = events + [event("C", daysAgo: 7, minute: 480)]
        XCTAssertEqual(SuggestionScorer.suggest(from: [sameTime, early], events: tied, now: monday,
                                                currentBoardingKey: nil)?.trip, early)
    }

    func testDelayIsARunningAverage() {
        var model = DelayModel()
        model.record(trip: "Normal-2", dayType: .sunToThu, minutesLate: 2)
        XCTAssertNil(model.usualDelay(trip: "Normal-2", dayType: .sunToThu))   // one isn't a habit
        model.record(trip: "Normal-2", dayType: .sunToThu, minutesLate: 4)
        model.record(trip: "Normal-2", dayType: .sunToThu, minutesLate: 3)
        XCTAssertEqual(model.usualDelay(trip: "Normal-2", dayType: .sunToThu), 3)
        XCTAssertNil(model.usualDelay(trip: "Normal-2", dayType: .saturday))
        // A silly reading (bus seen five hours late) is ignored.
        model.record(trip: "Normal-2", dayType: .sunToThu, minutesLate: 300)
        XCTAssertEqual(model.usualDelay(trip: "Normal-2", dayType: .sunToThu), 3)
    }

    func testDayTypes() {
        XCTAssertEqual(DayType(monday), .sunToThu)
        XCTAssertEqual(DayType(daysBefore(2, from: monday)), .saturday)
        XCTAssertEqual(DayType(daysBefore(3, from: monday)), .friday)
    }
}

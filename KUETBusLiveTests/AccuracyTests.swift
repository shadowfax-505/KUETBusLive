//
//  AccuracyTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  The four accuracy steps of the travel model: today's pace (live correction),
//  timetable lateness, special days, and the margin checked against real trips.
//

import XCTest
import CoreLocation
@testable import KUETBusLive

final class AccuracyTests: XCTestCase {

    let base = CLLocationCoordinate2D(latitude: 22.90, longitude: 89.50)
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let bucket = TimeBucket(dayType: .sunToThu, slot: 16)

    func north(_ metres: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: base.latitude + metres / 111_320, longitude: base.longitude)
    }

    var line: RouteLine {
        let stops = [north(0), north(1000), north(2000), north(3000)]
        return RouteLine(routeId: "r1", path: stops, stops: stops)
    }

    func stat(_ values: [Double]) -> RunningStat {
        var s = RunningStat()
        values.forEach { s.add($0) }
        return s
    }

    // Every stretch usually takes 100 s; no stop time.
    var usual: SegmentProfile {
        var stats: [String: RunningStat] = [:]
        for segment in 0..<3 {
            stats[StatKey.travel(route: "r1", segment: segment)] = stat([100, 100, 100])
        }
        for stop in 0..<4 {
            stats[StatKey.dwell(route: "r1", stop: stop)] = stat([0, 0, 0])
        }
        return SegmentProfile(stats: stats)
    }

    // MARK: 1. Today's pace

    func testSlowBusTodayMakesTheRestSlowerToo() {
        var timing = RouteTiming(line: line, profile: usual, bucket: bucket, driver: nil)
        var live = LiveCorrection()
        // The bus took 300 s for 2000 m that usually take 200 s.
        live.add(date: start, along: 0)
        live.add(date: start.addingTimeInterval(150), along: 1000)
        live.add(date: start.addingTimeInterval(300), along: 2000)
        let factor = live.factor(timing: timing)
        XCTAssertEqual(factor, 1.5, accuracy: 0.01)
        timing.liveFactor = factor
        XCTAssertEqual(timing.estimate(from: 2000, to: 3000).seconds, 150, accuracy: 1)
    }

    func testShortStretchesAreOnlyPartlyTrusted() {
        let timing = RouteTiming(line: line, profile: usual, bucket: bucket, driver: nil)
        var live = LiveCorrection()
        live.add(date: start, along: 0)
        live.add(date: start.addingTimeInterval(80), along: 500)   // 1.6 times slower, but only 500 m
        XCTAssertEqual(live.factor(timing: timing), 1.15, accuracy: 0.01)
    }

    func testPaceIgnoresStandingAndKeepsWithinLimits() {
        let timing = RouteTiming(line: line, profile: usual, bucket: bucket, driver: nil)
        var live = LiveCorrection()
        live.add(date: start, along: 0)
        live.add(date: start.addingTimeInterval(30), along: 0)        // standing: not a new point
        XCTAssertEqual(live.points.count, 1)
        live.add(date: start.addingTimeInterval(500), along: 2000)    // two and a half times slower
        XCTAssertEqual(live.factor(timing: timing), LiveCorrection.range.upperBound, accuracy: 0.001)
    }

    // MARK: 2. Timetable lateness

    func testLatenessAgainstTheTimetable() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Dhaka")!
        let leftAt = calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 7, minute: 34))!
        XCTAssertEqual(TripLearner.lateness(departedAt: leftAt, scheduled: "07:30", calendar: calendar), 240)
        // Early counts as on time; three hours off is another trip.
        XCTAssertEqual(TripLearner.lateness(departedAt: leftAt, scheduled: "07:40", calendar: calendar), 0)
        XCTAssertNil(TripLearner.lateness(departedAt: leftAt, scheduled: "10:40", calendar: calendar))
    }

    func testLearnedLatenessNeedsThreeTrips() {
        var profile = SegmentProfile(stats: [StatKey.late(route: "r1", schedule: "ts1"): stat([120, 180])])
        XCTAssertEqual(profile.lateness(route: "r1", schedule: "ts1"), 0)
        profile.stats[StatKey.late(route: "r1", schedule: "ts1")] = stat([120, 180, 240])
        XCTAssertEqual(profile.lateness(route: "r1", schedule: "ts1"), 180, accuracy: 1e-9)
    }

    // MARK: 3. Special days

    func testSpecialDayUsesItsOwnNumbersThenAnOrdinaryDays() {
        let exam = TimeBucket(dayType: .sunToThu, slot: 16, special: "exam")
        XCTAssertEqual(exam.key, "exam-16")
        var stats = [StatKey.travel(route: "r1", segment: 0, bucket: bucket): stat([90, 90, 90])]
        var profile = SegmentProfile(stats: stats)
        XCTAssertEqual(profile.travel(route: "r1", segment: 0, bucket: exam, driver: nil, metres: 1000).seconds, 90)
        stats[StatKey.travel(route: "r1", segment: 0, bucket: exam)] = stat([150, 150, 150])
        profile = SegmentProfile(stats: stats)
        XCTAssertEqual(profile.travel(route: "r1", segment: 0, bucket: exam, driver: nil, metres: 1000).seconds, 150)
    }

    func testSpecialDayLookup() {
        let store = SpecialDays.shared
        let today = SpecialDay.id(for: start)
        store.set([SpecialDay(id: today, kind: "holiday", note: "")])
        XCTAssertEqual(store.kind(on: start), "holiday")
        XCTAssertNil(store.kind(on: start.addingTimeInterval(86_400)))
        store.set([])
    }

    // MARK: 4. Margin checked against real trips

    func testMarginKFromRealErrors() {
        XCTAssertEqual(Margin.k(calibration: nil), Margin.k)
        // Too few trips: keep the textbook value.
        XCTAssertEqual(Margin.k(calibration: stat([0.5, -0.5])), Margin.k)
        // Buses came 0.5 spreads early on average, with spread 1: be there earlier.
        var errors = RunningStat(n: 30, mean: -0.5, variance: 1)
        XCTAssertEqual(Margin.k(calibration: errors), 1.2816 + 0.5, accuracy: 1e-6)
        // Very steady and a little late: a smaller margin, but never below 0.8.
        errors = RunningStat(n: 30, mean: 0.5, variance: 0.04)
        XCTAssertEqual(Margin.k(calibration: errors), 0.8, accuracy: 1e-6)
    }

    func testPredictionErrorsInSpreads() {
        // The bus left A at 0 and reached B 150 s later; the model said 100 s, spread 0.
        let timing = RouteTiming(line: line, profile: SegmentProfile(stats: [:]), bucket: bucket, driver: nil)
        var observations = TripObservations()
        observations.departedAt = start
        let predicted = timing.estimate(from: 20, to: 980)
        observations.arrivals[1] = start.addingTimeInterval(predicted.seconds + sqrt(predicted.totalVariance))
        let errors = TripLearner.predictionErrors(observations, timing: timing)
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual(errors[0], 1, accuracy: 1e-6)
    }
}

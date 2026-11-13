//
//  CatchPointTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  The learned travel model and the two planners: running averages, the
//  fallback chain, the safety margin, the best place to wait and the best
//  place to get off.
//

import XCTest
import CoreLocation
@testable import KUETBusLive

final class CatchPointTests: XCTestCase {

    // A straight road going north, with a stop every kilometre: A, B, C, D.
    let base = CLLocationCoordinate2D(latitude: 22.90, longitude: 89.50)

    func north(_ metres: Double, east: Double = 0) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: base.latitude + metres / 111_320,
                               longitude: base.longitude + east / (111_320 * cos(base.latitude * .pi / 180)))
    }

    var stops: [CLLocationCoordinate2D] { [north(0), north(1000), north(2000), north(3000)] }
    let names = ["A", "B", "C", "D"]
    var line: RouteLine { RouteLine(routeId: "r1", path: stops, stops: stops) }
    let bucket = TimeBucket(dayType: .sunToThu, slot: 16)

    func timing(_ stats: [String: RunningStat] = [:], driver: String? = nil) -> RouteTiming {
        RouteTiming(line: line, profile: SegmentProfile(stats: stats), bucket: bucket, driver: driver)
    }

    func stat(_ values: [Double]) -> RunningStat {
        var s = RunningStat()
        values.forEach { s.add($0) }
        return s
    }

    // MARK: Running average

    func testRunningStatMatchesPlainAverageForFewSamples() {
        let s = stat([100, 200, 300])
        XCTAssertEqual(s.n, 3)
        XCTAssertEqual(s.mean, 200, accuracy: 1e-9)
        // Population variance of 100, 200, 300.
        XCTAssertEqual(s.variance, 20_000 / 3, accuracy: 1e-6)
    }

    func testRunningStatFollowsChangeAfterTenTrips() {
        var s = stat(Array(repeating: 100, count: 30))
        for _ in 0..<10 { s.add(200) }
        // A plain average of all 40 would be 125; the weighted one has moved most of the way.
        XCTAssertGreaterThan(s.mean, 160)
        XCTAssertLessThan(s.mean, 200)
    }

    func testTimeBucketUsesHalfHours() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Dhaka")!
        // Sunday 15 November 2026, 08:20 in Khulna.
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 8, minute: 20))!
        let bucket = TimeBucket(date, calendar: calendar)
        XCTAssertEqual(bucket.key, "sunToThu-16")
    }

    // MARK: Fallback chain

    func testFallbackPrefersDriverThenSlotThenRouteThenRouter() {
        let driverKey = StatKey.travel(route: "r1", segment: 0, bucket: bucket, driver: "d1")
        let slotKey = StatKey.travel(route: "r1", segment: 0, bucket: bucket)
        let routeKey = StatKey.travel(route: "r1", segment: 0)
        var stats = [driverKey: stat([60, 60, 60]), slotKey: stat([90, 90, 90]), routeKey: stat([120, 120, 120])]

        func estimate(_ driver: String?) -> Estimate {
            SegmentProfile(stats: stats).travel(route: "r1", segment: 0, bucket: bucket, driver: driver, metres: 1000)
        }
        XCTAssertEqual(estimate("d1").source, .driverSlot)
        XCTAssertEqual(estimate("d1").seconds, 60, accuracy: 1e-9)
        XCTAssertEqual(estimate("d2").source, .slot)

        stats[slotKey] = stat([90, 90])   // too few trips at this time
        XCTAssertEqual(estimate("d2").source, .route)
        XCTAssertEqual(estimate("d2").seconds, 120, accuracy: 1e-9)

        stats = [:]
        let router = estimate(nil)
        XCTAssertEqual(router.source, .router)
        XCTAssertEqual(router.seconds, 1000 / SegmentProfile.defaultSpeed, accuracy: 1e-6)
        XCTAssertEqual(router.samples, 0)
    }

    func testRouterSpeedIsUsedWhenNoTripsYet() {
        let estimate = SegmentProfile(stats: [:]).travel(route: "r1", segment: 0, bucket: bucket, driver: nil,
                                                          metres: 1000, routerSpeed: 10)
        XCTAssertEqual(estimate.seconds, 100, accuracy: 1e-6)
    }

    // MARK: Timing along the route

    func testTimingAddsStretchesAndStopTimes() {
        var stats: [String: RunningStat] = [:]
        for segment in 0..<3 {
            stats[StatKey.travel(route: "r1", segment: segment)] = stat([100, 100, 100])
        }
        stats[StatKey.dwell(route: "r1", stop: 1)] = stat([30, 30, 30])
        // From halfway A-B to C: half of A-B, all of B-C, and the stop time at B.
        let estimate = timing(stats).estimate(from: 500, to: 2000)
        XCTAssertEqual(estimate.seconds, 50 + 100 + 30, accuracy: 1)
        XCTAssertEqual(estimate.source, .route)
    }

    // MARK: Margin

    func testMarginShrinksWithMoreTrips() {
        let few = Estimate(seconds: 300, variance: 3600, samples: 3, source: .slot)
        let many = Estimate(seconds: 300, variance: 3600, samples: 50, source: .slot)
        XCTAssertGreaterThan(Margin.seconds(for: few), Margin.seconds(for: many))
        // sqrt(3600 + 3600/50) = 60.6 s; 1.28 of it.
        XCTAssertEqual(Margin.seconds(for: many), 1.2816 * sqrt(3600 + 72), accuracy: 0.01)
    }

    func testMarginNeverBelowHalfAMinute() {
        XCTAssertEqual(Margin.seconds(for: Estimate(seconds: 60, variance: 0, samples: 9, source: .slot)), 30)
    }

    func testNinetyPercentMarginGivesNinetyPercentChance() {
        XCTAssertEqual(Margin.probabilityPositive(mean: 1.2816 * 60, sd: 60), 0.9, accuracy: 0.001)
        XCTAssertEqual(Margin.probabilityPositive(mean: 0, sd: 60), 0.5, accuracy: 1e-9)
    }

    // MARK: Best place to wait

    func testCatchPrefersTheNearStopTheRiderCanReach() {
        // Rider stands 150 m east of stop C; the bus is at A.
        let rider = north(2000, east: 150)
        let points = CatchPlanner.candidates(line: line, stopNames: names, spots: [], after: 0, near: rider)
        let plan = CatchPlanner.bestCatch(rider: rider, busAlong: 0, candidates: points, timing: timing(),
                                          walking: WalkingSpeed(), driverWaveRate: 0.5)
        XCTAssertEqual(plan?.point.name, "C")
        XCTAssertEqual(plan?.point.kind, .stop(index: 2))
        XCTAssertGreaterThan(plan?.catchChance ?? 0, 0.9)
        XCTAssertGreaterThan(plan?.leaveInSeconds ?? 0, 0)
    }

    func testCatchSkipsAPointTheBusReachesFirst() {
        // Slow traffic: 10 minutes per kilometre. The bus is 100 m before B and the
        // rider is past B, so B is out of reach: wait at the road beside you instead.
        var stats: [String: RunningStat] = [:]
        for segment in 0..<3 {
            stats[StatKey.travel(route: "r1", segment: segment)] = stat([600, 600, 600])
        }
        let rider = north(1300, east: 100)
        let points = CatchPlanner.candidates(line: line, stopNames: names, spots: [], after: 900, near: rider)
        let plan = CatchPlanner.bestCatch(rider: rider, busAlong: 900, candidates: points, timing: timing(stats),
                                          walking: WalkingSpeed(), driverWaveRate: 0.5)
        XCTAssertEqual(plan?.point.kind, .nearest)
        XCTAssertEqual(plan?.point.along ?? 0, 1300, accuracy: 5)
        XCTAssertEqual(plan?.point.name, "B")   // "near B"
        XCTAssertGreaterThanOrEqual(plan?.catchChance ?? 0, CatchPlanner.minimumChance)
    }

    func testNoPlanWhenTheBusIsTooCloseEverywhere() {
        let rider = north(1000, east: 600)
        let points = CatchPlanner.candidates(line: line, stopNames: names, spots: [], after: 900, near: rider)
        XCTAssertNil(CatchPlanner.bestCatch(rider: rider, busAlong: 900, candidates: points, timing: timing(),
                                            walking: WalkingSpeed(), driverWaveRate: 0.5))
    }

    func testLearnedSpotWhereDriversStopBeatsAFartherStop() {
        // A spot 300 m before C where the bus stopped 9 times out of 10, right next to the rider.
        let spot = RoutePoint(name: "Gate 2", coordinate: north(1700), along: 1700, kind: .spot(stops: 9, asks: 10))
        let rider = north(1700, east: 40)
        let points = CatchPlanner.candidates(line: line, stopNames: names, spots: [spot], after: 0, near: rider)
            .filter { $0.kind != .nearest }
        let plan = CatchPlanner.bestCatch(rider: rider, busAlong: 0, candidates: points, timing: timing(),
                                          walking: WalkingSpeed(), driverWaveRate: 0.5)
        XCTAssertEqual(plan?.point.name, "Gate 2")
    }

    func testLeaveNowWhenThereIsNoSpareTime() {
        let plan = CatchPlan(point: RoutePoint(name: "B", coordinate: north(1000), along: 1000, kind: .stop(index: 1)),
                             busSeconds: 200, walkSeconds: 180, marginSeconds: 60, catchChance: 0.7, samples: 4)
        XCTAssertEqual(plan.leaveInSeconds, 0)
    }

    func testStopChanceFromPastOutcomes() {
        let fresh = RoutePoint(name: "x", coordinate: base, along: 0, kind: .spot(stops: 0, asks: 0))
        XCTAssertEqual(fresh.stopChance(driverWaveRate: 0.9), 0.5)
        let good = RoutePoint(name: "x", coordinate: base, along: 0, kind: .spot(stops: 18, asks: 20))
        XCTAssertEqual(good.stopChance(driverWaveRate: 0), 19.0 / 22.0, accuracy: 1e-9)
    }

    // MARK: Walking speed

    func testWalkingSpeedBlendsTowardsTheRidersOwn() {
        var walking = WalkingSpeed()
        XCTAssertEqual(walking.metresPerSecond, WalkingSpeed.defaultSpeed)
        walking.add(speed: 9)     // riding, ignored
        walking.add(speed: 0.1)   // standing, ignored
        XCTAssertEqual(walking.stat.n, 0)
        for _ in 0..<40 { walking.add(speed: 1.0) }
        XCTAssertEqual(walking.metresPerSecond, 1.0, accuracy: 1e-6)
    }

    // MARK: Best place to get off

    func testDropPicksTheStopClosestToTheDestination() {
        let destination = north(2950, east: 200)   // next to D
        let points = CatchPlanner.candidates(line: line, stopNames: names, spots: [], after: 0, near: destination)
            .filter { $0.kind != .nearest }
        let plan = CatchPlanner.bestDrop(destination: destination, busAlong: 0, boardAlong: 0, candidates: points,
                                         timing: timing(), walking: WalkingSpeed(), driverWaveRate: 0.5)
        XCTAssertEqual(plan?.point.name, "D")
        XCTAssertEqual(plan?.walkMinutes, 4)
    }

    func testDropUsesANearerRoutePointWhenItSavesWalking() {
        // Destination beside the road halfway between B and C; drivers stop where asked.
        let destination = north(1500, east: 50)
        let points = CatchPlanner.candidates(line: line, stopNames: names, spots: [], after: 0, near: destination)
        let plan = CatchPlanner.bestDrop(destination: destination, busAlong: 0, boardAlong: 0, candidates: points,
                                         timing: timing(), walking: WalkingSpeed(), driverWaveRate: 1)
        XCTAssertEqual(plan?.point.kind, .nearest)
        XCTAssertEqual(plan?.point.along ?? 0, 1500, accuracy: 5)
    }

    func testDropNeverBeforeBoarding() {
        let destination = north(500, east: 30)   // behind where the rider gets on
        let points = CatchPlanner.candidates(line: line, stopNames: names, spots: [], after: 0, near: destination)
        let plan = CatchPlanner.bestDrop(destination: destination, busAlong: 0, boardAlong: 1000, candidates: points,
                                         timing: timing(), walking: WalkingSpeed(), driverWaveRate: 1)
        XCTAssertGreaterThan(plan?.point.along ?? 0, 1000)
    }

    func testTripOptionsRankByArrival() {
        let point = RoutePoint(name: "D", coordinate: north(3000), along: 3000, kind: .stop(index: 3))
        let drop = DropPlan(point: point, busSeconds: 600, walkSeconds: 120, arrivalSeconds: 720, samples: 5)
        let running = TripOption(title: "Normal-1", startsIn: 0, catchPlan: nil, dropPlan: drop)
        let later = TripOption(title: "Normal-2", startsIn: 900, catchPlan: nil, dropPlan: drop)
        XCTAssertEqual(TripOption.ranked([later, running]).map(\.title), ["Normal-1", "Normal-2"])
        XCTAssertEqual(later.arrivalSeconds, 1620)
    }
}

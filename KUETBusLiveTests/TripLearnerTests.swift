//
//  TripLearnerTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  Turning a trip's GPS track into stretch times, stop times and wave outcomes.
//

import XCTest
import CoreLocation
@testable import KUETBusLive

final class TripLearnerTests: XCTestCase {

    let base = CLLocationCoordinate2D(latitude: 22.90, longitude: 89.50)
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    func north(_ metres: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: base.latitude + metres / 111_320, longitude: base.longitude)
    }

    var line: RouteLine {
        let stops = [north(0), north(1000), north(2000), north(3000)]
        return RouteLine(routeId: "r1", path: stops, stops: stops)
    }

    // A bus at 10 m/s that stands for 30 s at B (1000 m) and 20 s at 1500 m.
    func track() -> [GPSSample] {
        var samples: [GPSSample] = []
        var t = 0.0
        var position = 0.0
        var paused: [(at: Double, seconds: Double)] = [(1000, 30), (1500, 20)]
        while position <= 3100 {
            samples.append(GPSSample(date: start.addingTimeInterval(t), coordinate: north(position), speed: 10))
            if let pause = paused.first, position >= pause.at {
                for step in stride(from: 2.0, through: pause.seconds, by: 2) {
                    samples.append(GPSSample(date: start.addingTimeInterval(t + step), coordinate: north(position), speed: 0))
                }
                t += pause.seconds
                paused.removeFirst()
            }
            t += 2
            position += 20
        }
        return samples
    }

    func testStretchTimesLeaveOutStopTime() {
        let result = TripLearner.learn(samples: track(), line: line, waves: [])
        XCTAssertEqual(result.stretches.map(\.segment), [0, 1, 2])
        // A to B: from 20 m past A to 20 m before B, 960 m at 10 m/s.
        XCTAssertEqual(result.stretches[0].seconds, 96, accuracy: 1)
        // B to C includes the 20 s pause at 1500 m: traffic is part of the stretch.
        XCTAssertEqual(result.stretches[1].seconds, 116, accuracy: 1)
        XCTAssertEqual(result.stretches[2].seconds, 96, accuracy: 1)
    }

    func testStopTimeAtTheMiddleStops() {
        let result = TripLearner.learn(samples: track(), line: line, waves: [])
        let atB = result.stopTimes.first { $0.stop == 1 }
        // 40 m of driving (4 s) plus 30 s standing.
        XCTAssertEqual(atB?.seconds ?? 0, 34, accuracy: 1)
        XCTAssertFalse(result.stopTimes.contains { $0.stop == 0 || $0.stop == 3 })
    }

    func testWaveOutcomes() {
        let served = SeenWave(coordinate: north(1505), createdAt: start)
        let passed = SeenWave(coordinate: north(2500), createdAt: start)
        let notReached = SeenWave(coordinate: north(5000), createdAt: start)
        let result = TripLearner.learn(samples: track(), line: line, waves: [served, passed, notReached])
        XCTAssertEqual(result.waves.count, 2)
        XCTAssertEqual(result.waves[0].stopped, true)
        XCTAssertEqual(result.waves[0].seconds, 20, accuracy: 0.1)
        XCTAssertEqual(result.waves[1].stopped, false)
    }

    func testBackwardGPSWobbleIsIgnored() {
        var samples = track()
        // One sample jumps 200 m back.
        samples[10].coordinate = north(0)
        let result = TripLearner.learn(samples: samples, line: line, waves: [])
        XCTAssertEqual(result.stretches.count, 3)
    }

    func testTooFewSamplesLearnNothing() {
        XCTAssertEqual(TripLearner.learn(samples: [], line: line, waves: []), TripObservations())
    }

    func testSpotKeysGroupNearbyPoints() {
        let a = SpotKey.id(route: "r1", coordinate: CLLocationCoordinate2D(latitude: 22.88901, longitude: 89.50951))
        let b = SpotKey.id(route: "r1", coordinate: CLLocationCoordinate2D(latitude: 22.88905, longitude: 89.50949))
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.hasPrefix("r1_22.889"))
    }
}

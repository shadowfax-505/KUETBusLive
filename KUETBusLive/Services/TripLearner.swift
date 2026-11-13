//
//  TripLearner.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  At the end of a trip the driver's phone turns its own GPS track into a few
//  numbers for the shared model (no raw track leaves the phone):
//  - how long each stretch between two stops took, from leaving one stop
//    (20 m past it) to reaching the next (20 m before it)
//  - how long the bus stood at each stop (the time between those two moments)
//  - for every wave the driver saw: did the bus stop there (within 20 m and
//    slower than walking pace) or drive past
//  Plain Swift, unit tested in TripLearnerTests.
//

import Foundation
import CoreLocation

struct GPSSample: Equatable {
    var date: Date
    var coordinate: CLLocationCoordinate2D
    var speed: Double?    // metres per second, nil if unknown

    static func == (a: GPSSample, b: GPSSample) -> Bool {
        a.date == b.date && a.coordinate.latitude == b.coordinate.latitude
            && a.coordinate.longitude == b.coordinate.longitude && a.speed == b.speed
    }
}

// A wave the driver saw on this trip, kept until the end of the trip.
struct SeenWave: Equatable {
    var coordinate: CLLocationCoordinate2D
    var createdAt: Date

    static func == (a: SeenWave, b: SeenWave) -> Bool {
        a.createdAt == b.createdAt && a.coordinate.latitude == b.coordinate.latitude
            && a.coordinate.longitude == b.coordinate.longitude
    }
}

struct TripObservations: Equatable {
    struct Stretch: Equatable {
        var segment: Int
        var seconds: Double
        var startedAt: Date
    }

    struct StopTime: Equatable {
        var stop: Int
        var seconds: Double
    }

    struct WaveOutcome: Equatable {
        var coordinate: CLLocationCoordinate2D
        var stopped: Bool
        var seconds: Double     // time stood there, 0 if it drove past

        static func == (a: WaveOutcome, b: WaveOutcome) -> Bool {
            a.stopped == b.stopped && a.seconds == b.seconds
                && a.coordinate.latitude == b.coordinate.latitude && a.coordinate.longitude == b.coordinate.longitude
        }
    }

    var stretches: [Stretch] = []
    var stopTimes: [StopTime] = []
    var waves: [WaveOutcome] = []
}

enum TripLearner {
    // The stop "zone": the bus has reached a stop 20 m before it and left 20 m after it.
    static let stopZone = 20.0
    // Slower than this counts as stopped (a brisk walk).
    static let stoppedSpeed = 1.5
    // A wave counts as served if the bus stopped within this distance of it.
    static let waveRadius = 20.0
    // Values outside these are GPS trouble or a break, not traffic.
    static let stretchSeconds = 5.0...3600.0
    static let stopSeconds = 0.0...900.0

    static func learn(samples: [GPSSample], line: RouteLine, waves: [SeenWave]) -> TripObservations {
        var result = TripObservations()
        guard samples.count >= 2, line.stopAlong.count >= 2 else { return result }

        // Distance along the route for each sample. GPS wobbles, so never let it go backwards.
        var along: [Double] = []
        for sample in samples {
            let value = line.along(sample.coordinate)
            along.append(max(value, along.last ?? value))
        }

        // The moment the bus first got to `target` metres along, between two samples.
        func time(at target: Double) -> Date? {
            for k in 1..<samples.count where along[k - 1] < target && along[k] >= target {
                let fraction = (target - along[k - 1]) / (along[k] - along[k - 1])
                let gap = samples[k].date.timeIntervalSince(samples[k - 1].date)
                return samples[k - 1].date.addingTimeInterval(fraction * gap)
            }
            return nil
        }

        let arrive = line.stopAlong.map { time(at: $0 - stopZone) }
        let leave = line.stopAlong.map { time(at: $0 + stopZone) }

        for segment in 0..<(line.stopAlong.count - 1) {
            guard let from = leave[segment], let to = arrive[segment + 1] else { continue }
            let seconds = to.timeIntervalSince(from)
            if stretchSeconds.contains(seconds) {
                result.stretches.append(.init(segment: segment, seconds: seconds, startedAt: from))
            }
        }
        // Stops in the middle only: the first and last include waiting to start and parking.
        for stop in 1..<max(line.stopAlong.count - 1, 1) {
            guard let from = arrive[stop], let to = leave[stop] else { continue }
            let seconds = to.timeIntervalSince(from)
            if stopSeconds.contains(seconds) {
                result.stopTimes.append(.init(stop: stop, seconds: seconds))
            }
        }

        for wave in waves {
            let waveAlong = line.along(wave.coordinate)
            // Only waves the bus actually went past, so it had the chance to stop.
            guard let lastAlong = along.last, lastAlong > waveAlong + stopZone else { continue }
            var stoodFor = 0.0
            for k in 1..<samples.count {
                let sample = samples[k]
                guard sample.date >= wave.createdAt,
                      CatchPlanner.distance(sample.coordinate, wave.coordinate) <= waveRadius,
                      (sample.speed ?? .infinity) < stoppedSpeed else { continue }
                stoodFor += sample.date.timeIntervalSince(samples[k - 1].date)
            }
            result.waves.append(.init(coordinate: wave.coordinate, stopped: stoodFor > 0, seconds: stoodFor))
        }
        return result
    }
}

// Spots riders use, in ~30 m squares, so nearby waves and drop-offs add up.
enum SpotKey {
    static let gridDegrees = 0.0003

    static func snapped(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: (coordinate.latitude / gridDegrees).rounded() * gridDegrees,
                               longitude: (coordinate.longitude / gridDegrees).rounded() * gridDegrees)
    }

    // "r1_22.8891_89.5095". Platform-neutral: Android builds the same string.
    static func id(route: String, coordinate: CLLocationCoordinate2D) -> String {
        let cell = snapped(coordinate)
        return "\(route)_" + String(format: "%.4f_%.4f", locale: Locale(identifier: "en_US_POSIX"),
                                    cell.latitude, cell.longitude)
    }
}

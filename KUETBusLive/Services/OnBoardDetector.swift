//
//  OnBoardDetector.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Is the rider on this bus? Only then may they report it as overcrowded, and
//  only then does getting off count as a drop-off. Plain Swift, unit tested.
//
//  On board means: for at least a minute, the phone stayed within 30 m of the
//  bus while both were moving at about the same speed. The bus's position is up
//  to a few seconds old, so it is first moved ahead along its heading by its
//  speed x the age of the position. Short stops (signals, stops) don't reset the
//  minute; moving away from the bus does.
//

import Foundation
import CoreLocation

struct OnBoardDetector {
    static let radius = 30.0                // metres between the phone and the bus
    static let duration: TimeInterval = 60  // seconds together before it counts
    static let movingSpeed = 2.0            // m/s: faster than walking, so it's riding
    static let speedTolerance = 2.5         // m/s difference between phone and bus
    static let maxProjection: TimeInterval = 10

    private(set) var since: Date?
    private(set) var isOnBoard = false

    // Where the bus probably is now: its last position moved ahead by speed x age.
    static func projected(bus: CLLocationCoordinate2D, heading: Double?, speed: Double?,
                          updatedAt: Date, now: Date) -> CLLocationCoordinate2D {
        guard let heading, let speed, speed > 0 else { return bus }
        let metres = speed * min(max(now.timeIntervalSince(updatedAt), 0), maxProjection)
        let radians = heading * .pi / 180
        let north = metres * cos(radians), east = metres * sin(radians)
        return CLLocationCoordinate2D(latitude: bus.latitude + north / 111_320,
                                      longitude: bus.longitude + east / (111_320 * cos(bus.latitude * .pi / 180)))
    }

    // Feed one new rider position. Returns whether the rider is on board now.
    @discardableResult
    mutating func update(rider: CLLocationCoordinate2D, riderSpeed: Double?, bus: CLLocationCoordinate2D,
                         busHeading: Double?, busSpeed: Double?, busUpdatedAt: Date, at now: Date) -> Bool {
        let busNow = Self.projected(bus: bus, heading: busHeading, speed: busSpeed, updatedAt: busUpdatedAt, now: now)
        let gap = CLLocation(latitude: rider.latitude, longitude: rider.longitude)
            .distance(from: CLLocation(latitude: busNow.latitude, longitude: busNow.longitude))
        guard gap <= Self.radius else {
            since = nil
            isOnBoard = false
            return false
        }
        let busMoving = (busSpeed ?? 0) >= Self.movingSpeed
        let riderMoving = (riderSpeed ?? 0) >= Self.movingSpeed
        if busMoving && riderMoving && abs((busSpeed ?? 0) - (riderSpeed ?? 0)) <= Self.speedTolerance {
            if since == nil {
                since = now
            }
        }
        if let since, now.timeIntervalSince(since) >= Self.duration {
            isOnBoard = true
        }
        return isOnBoard
    }
}

//
//  BusGlider.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Remembers, for each live bus, where its icon is drawn and where it is heading,
//  so the map can glide it to each new GPS point instead of jumping there.
//  The maths is in BusMotion; this only keeps the state between updates.
//

import Foundation
import CoreLocation

final class BusGlider: ObservableObject {
    struct Glide {
        var from: CLLocationCoordinate2D
        var to: CLLocationCoordinate2D
        var start: Date
        var duration: TimeInterval
        var lastUpdate: Date
        // Degrees, not kept in 0..<360, so the icon always turns the short way.
        var heading: Double?
    }

    private(set) var glides: [String: Glide] = [:]

    // New positions from Firestore. With Reduce Motion on, buses jump to the new point.
    func update(with buses: [Bus], reduceMotion: Bool, now: Date = Date()) {
        var next: [String: Glide] = [:]
        for bus in buses {
            guard let id = bus.id else { continue }
            guard var glide = glides[id] else {
                next[id] = Glide(from: bus.coordinate, to: bus.coordinate, start: now, duration: 0,
                                 lastUpdate: bus.updatedAt,
                                 heading: bus.heading.map(BusMotion.normalized))
                continue
            }
            let moved = glide.to.latitude != bus.lat || glide.to.longitude != bus.lng
            if moved || bus.updatedAt != glide.lastUpdate {
                if let newHeading = BusMotion.heading(course: bus.heading, from: glide.to, to: bus.coordinate) {
                    glide.heading = glide.heading.map { BusMotion.shortestRotation(from: $0, to: newHeading) }
                        ?? newHeading
                }
                // Start from where the icon is now, even if the last glide hasn't finished.
                glide.from = position(of: glide, at: now)
                glide.to = bus.coordinate
                glide.start = now
                glide.duration = reduceMotion ? 0
                    : BusMotion.glideDuration(previousUpdate: glide.lastUpdate, newUpdate: bus.updatedAt)
                glide.lastUpdate = bus.updatedAt
            }
            next[id] = glide
        }
        glides = next
    }

    // Where to draw the bus right now, on the road line when its route is known.
    func position(of bus: Bus, at now: Date, route: [CLLocationCoordinate2D]? = nil) -> CLLocationCoordinate2D {
        guard let id = bus.id, let glide = glides[id] else { return bus.coordinate }
        return BusMotion.snapped(position(of: glide, at: now), to: route)
    }

    func heading(of bus: Bus) -> Double? {
        bus.id.flatMap { glides[$0]?.heading } ?? bus.heading
    }

    // How long the current glide lasts, so the camera can follow at the same pace.
    func duration(of bus: Bus) -> TimeInterval {
        bus.id.flatMap { glides[$0]?.duration } ?? 0
    }

    // True while any bus is still on its way to its latest point. The map redraws
    // every frame only then, and rests otherwise.
    func isGliding(at now: Date) -> Bool {
        glides.values.contains { BusMotion.fraction(start: $0.start, duration: $0.duration, now: now) < 1 }
    }

    private func position(of glide: Glide, at now: Date) -> CLLocationCoordinate2D {
        BusMotion.interpolate(from: glide.from, to: glide.to,
                              fraction: BusMotion.fraction(start: glide.start, duration: glide.duration, now: now))
    }
}

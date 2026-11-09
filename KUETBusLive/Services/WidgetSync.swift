//
//  WidgetSync.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Keeps the home screen widget up to date. The app writes the trips this rider
//  may take and their favourite stop into the shared App Group, then asks
//  WidgetKit to redraw the widget.
//

import Foundation
import WidgetKit

enum WidgetSync {
    static func save(schedules: [BusSchedule], role: UserRole, favoriteStop: String?) {
        // Only the trips this person may ride, in the small form the widget understands.
        let trips = schedules
            .filter { $0.audience.canBoard(role) }
            .map { SharedTrip(tripName: $0.tripName, spot: $0.spot, days: $0.days.rawValue, campusTime: $0.campusTime) }

        // Redrawing widgets costs battery, so skip it when nothing changed.
        guard trips != SharedStore.trips || favoriteStop != SharedStore.favoriteStop else { return }

        SharedStore.trips = trips
        SharedStore.favoriteStop = favoriteStop
        WidgetCenter.shared.reloadAllTimelines()
    }

    // The route that has the rider's stop on it, for the large widget's map.
    static func saveRoute(from routes: [BusRoute], favoriteStop: String?) {
        guard let stopName = favoriteStop else { return }
        for route in routes {
            if let index = route.stops.firstIndex(where: { $0.name == stopName }) {
                let shared = SharedRoute(name: route.name,
                                         stops: route.stops.map { SharedStop(name: $0.name, lat: $0.lat, lng: $0.lng) },
                                         riderStopIndex: index)
                SharedStore.route = shared
                return
            }
        }
    }

    private static var lastLiveReload = Date.distantPast

    // A new ETA for a running bus. Widgets have a daily refresh budget, so they are
    // only asked to redraw at most once a minute.
    static func saveLive(_ snapshot: LiveTripSnapshot) {
        // Keep the bus that will reach the rider first.
        if let current = SharedStore.liveTrip, current.isFresh,
           current.busNumber != snapshot.busNumber, current.etaMinutes < snapshot.etaMinutes {
            return
        }
        SharedStore.liveTrip = snapshot
        if Date().timeIntervalSince(lastLiveReload) >= 60 {
            lastLiveReload = Date()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

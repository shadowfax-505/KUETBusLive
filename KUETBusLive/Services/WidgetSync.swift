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
}

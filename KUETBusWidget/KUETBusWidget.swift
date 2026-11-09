//
//  KUETBusWidget.swift
//  KUETBusWidget
//
//  Created by Muttakin Rahman Shoscho.
//
//  Home screen widget: the next KUET bus the rider can take, when it leaves,
//  and how many minutes are left. Comes in a small and a medium size.
//
//  WidgetKit asks the provider for a "timeline": a list of entries, each with
//  the date it should appear. One entry per departure is enough, because the
//  countdown text (Text with style .relative) updates itself every minute.
//

import WidgetKit
import SwiftUI

// One moment on the widget's timeline.
struct NextBusEntry: TimelineEntry {
    let date: Date
    let trips: [UpcomingTrip]     // the next departures after `date`, soonest first
    let favoriteStop: String?

    // Made-up data for the loading placeholder and the Xcode preview.
    static var sample: NextBusEntry {
        let first = SharedTrip(tripName: "Normal-1", spot: "Rupsha", days: "sunToThu", campusTime: "07:30")
        let second = SharedTrip(tripName: "Normal-2", spot: "Gollamari", days: "sunToThu", campusTime: "08:30")
        return NextBusEntry(date: Date(),
                            trips: [UpcomingTrip(trip: first, leavesAt: Date().addingTimeInterval(25 * 60)),
                                    UpcomingTrip(trip: second, leavesAt: Date().addingTimeInterval(85 * 60))],
                            favoriteStop: "Fulbarigate")
    }
}

struct NextBusProvider: TimelineProvider {

    // Trips saved by the app, or the bundled timetable if the app hasn't saved any yet.
    private func loadTrips() -> [SharedTrip] {
        let saved = SharedStore.trips
        return saved.isEmpty ? SharedStore.bundledTrips() : saved
    }

    private func entry(at date: Date, trips: [SharedTrip]) -> NextBusEntry {
        NextBusEntry(date: date,
                     trips: SharedStore.upcoming(from: trips, after: date),
                     favoriteStop: SharedStore.favoriteStop)
    }

    // Shown while the widget is loading for the first time.
    func placeholder(in context: Context) -> NextBusEntry {
        NextBusEntry.sample
    }

    // Shown in the widget gallery.
    func getSnapshot(in context: Context, completion: @escaping (NextBusEntry) -> Void) {
        completion(entry(at: Date(), trips: loadTrips()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextBusEntry>) -> Void) {
        let trips = loadTrips()
        let now = Date()
        var entries = [entry(at: now, trips: trips)]

        // A new entry the moment each of the next few buses leaves, so the widget
        // moves on to the following bus by itself.
        for upcoming in SharedStore.upcoming(from: trips, after: now, limit: 5) {
            entries.append(entry(at: upcoming.leavesAt.addingTimeInterval(1), trips: trips))
        }

        // Ask again after the last entry. The app also reloads the widget when the timetable changes.
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct KUETBusWidget: Widget {
    let kind = "KUETBusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextBusProvider()) { entry in
            NextBusWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    KUETWidgetStyle.background
                }
        }
        .configurationDisplayName("Next KUET bus")
        .description("The next bus you can take and how long until it leaves.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

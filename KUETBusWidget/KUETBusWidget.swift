//
//  KUETBusWidget.swift
//  KUETBusWidget
//
//  Created by Muttakin Rahman Shoscho.
//
//  Home screen widget: the next KUET bus the rider can take, when it leaves,
//  and how far along the trip is. Comes in small, medium and large sizes.
//
//  WidgetKit asks the provider for a "timeline": a list of entries, each with
//  the date it should appear. One entry per departure is enough, because the
//  countdown text (Text with style .relative) updates itself every minute.
//
//  Two kinds of data, best first:
//  1. A live bus the app saw recently (ETA, distance, crowd, position).
//  2. The timetable, saved by the app or bundled in kuet_schedule.json.
//

import WidgetKit
import SwiftUI
import UIKit

// One moment on the widget's timeline.
struct NextBusEntry: TimelineEntry {
    let date: Date
    let trips: [UpcomingTrip]     // the next departures after `date`, soonest first
    let favoriteStop: String?
    var live: LiveTripSnapshot? = nil
    var route: SharedRoute? = nil
    var runningTrip: UpcomingTrip? = nil   // a timetable trip that has left but not arrived yet
    var mapLight: UIImage? = nil           // route map for the large widget
    var mapDark: UIImage? = nil

    // Progress for the track and ring: live data first, then the timetable.
    var progress: TripProgress {
        if let live = live {
            return live.progress
        }
        var progress = TripProgress(fraction: 0, stopFractions: route.map(Self.stopFractions) ?? [])
        if let running = runningTrip {
            progress.fraction = TripProgress.fromTimetable(departure: running.leavesAt,
                                                           arrival: running.leavesAt.addingTimeInterval(Self.tripMinutes * 60),
                                                           now: date)
        }
        return progress
    }

    // The timetable gives no arrival time at each stop, so assume a typical trip length.
    static let tripMinutes: Double = 40

    // Where the stops between KUET and my stop sit on the track.
    static func stopFractions(_ route: SharedRoute) -> [Double] {
        guard route.riderStopIndex > 0, route.riderStopIndex < route.stops.count else { return [] }
        let totals = TripProgress.cumulative(route.stops[0...route.riderStopIndex].map { $0.coordinate })
        guard let total = totals.last, total > 0 else { return [] }
        return totals.dropFirst().dropLast().map { $0 / total }
    }

    // Made-up data for the loading placeholder and the Xcode preview.
    static var sample: NextBusEntry {
        let first = SharedTrip(tripName: "Normal-1", spot: "Rupsha", days: "sunToThu", campusTime: "07:30")
        let second = SharedTrip(tripName: "Normal-2", spot: "Gollamari", days: "sunToThu", campusTime: "08:30")
        let live = LiveTripSnapshot(busNumber: "Normal-1 · Rupsha", stopName: "Fulbarigate", etaMinutes: 7,
                                    distanceKm: 3.2, crowd: "seats",
                                    progress: TripProgress(fraction: 0.55, stopFractions: [0.3, 0.7]),
                                    busLat: 22.88, busLng: 89.51, updatedAt: Date())
        return NextBusEntry(date: Date(),
                            trips: [UpcomingTrip(trip: first, leavesAt: Date().addingTimeInterval(25 * 60)),
                                    UpcomingTrip(trip: second, leavesAt: Date().addingTimeInterval(85 * 60))],
                            favoriteStop: "Fulbarigate",
                            live: live)
    }
}

struct NextBusProvider: TimelineProvider {

    // Trips saved by the app, or the bundled timetable if the app hasn't saved any yet.
    private func loadTrips() -> [SharedTrip] {
        let saved = SharedStore.trips
        return saved.isEmpty ? SharedStore.bundledTrips() : saved
    }

    private func entry(at date: Date, trips: [SharedTrip]) -> NextBusEntry {
        let live = SharedStore.liveTrip
        // A trip that left in the last 40 minutes is probably still on the road.
        let recent = SharedStore.upcoming(from: trips, after: date.addingTimeInterval(-NextBusEntry.tripMinutes * 60), limit: 1)
            .first { $0.leavesAt <= date }
        return NextBusEntry(date: date,
                            trips: SharedStore.upcoming(from: trips, after: date),
                            favoriteStop: SharedStore.favoriteStop,
                            live: (live?.isFresh ?? false) ? live : nil,
                            route: SharedStore.route,
                            runningTrip: recent)
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

        // With a live bus, ask again in 15 minutes (the app also reloads when a new ETA arrives).
        let policy: TimelineReloadPolicy = entries[0].live != nil
            ? .after(now.addingTimeInterval(15 * 60))
            : .atEnd

        // Only the large widget shows a map, and drawing it takes a moment.
        guard context.family == .systemLarge, let route = SharedStore.route else {
            completion(Timeline(entries: entries, policy: policy))
            return
        }
        let live = entries[0].live
        RouteMapRenderer.render(route: route, live: live, size: CGSize(width: 330, height: 170)) { light, dark in
            let withMaps = entries.map { entry -> NextBusEntry in
                var copy = entry
                copy.mapLight = light
                copy.mapDark = dark
                return copy
            }
            completion(Timeline(entries: withMaps, policy: policy))
        }
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
        .description("The next bus you can take, how long until it leaves, and how far along it is.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

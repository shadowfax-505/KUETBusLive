//
//  NextBusWidgetView.swift
//  KUETBusWidget
//
//  Created by Muttakin Rahman Shoscho.
//
//  The look of the home screen widget in its small, medium and large sizes.
//  - small: a ring showing how far along the trip is, with minutes left inside
//  - medium: the next bus plus the trip track from KUET to my stop
//  - large: a route map, the track, and the bus name, ETA and crowd
//  Colours and type come from WidgetTheme.
//

import WidgetKit
import SwiftUI

struct NextBusWidgetView: View {
    let entry: NextBusEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    var stopName: String {
        PlaceNames.display(entry.live?.stopName ?? entry.favoriteStop ?? String(localized: "My stop"))
    }

    var body: some View {
        Group {
            switch family {
            case .systemLarge:
                large
            case .systemMedium:
                medium
            default:
                small
            }
        }
        .foregroundStyle(WidgetTheme.primary)
    }

    // "ARRIVING IN" while a bus is on its way, otherwise "NEXT BUS".
    private var headline: String {
        entry.live != nil ? String(localized: "Arriving in") : String(localized: "Next bus")
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "bus.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(WidgetTheme.accent)
                .widgetAccentable()
            Text(headline)
                .widgetLabel()
        }
        .font(.caption2)
        .accessibilityHidden(true)
    }

    // Minutes until the next bus leaves, or the live ETA.
    private var minutesLeft: String {
        if let live = entry.live {
            return "\(live.etaMinutes)"
        }
        guard let next = entry.trips.first else { return "--" }
        let minutes = Int(next.leavesAt.timeIntervalSince(entry.date) / 60)
        return minutes < 100 ? "\(max(minutes, 0))" : "\(minutes / 60)"
    }

    // Under 100 minutes the ring counts minutes, after that whole hours.
    private var minutesCaption: String {
        guard entry.live == nil, let next = entry.trips.first,
              next.leavesAt.timeIntervalSince(entry.date) >= 100 * 60 else {
            return String(localized: "min")
        }
        return String(localized: "hours")
    }

    private var track: some View {
        TripProgressView(progress: entry.progress, endLabel: stopName,
                         tint: WidgetTheme.accent, trackColor: WidgetTheme.track,
                         refined: true, stopColor: WidgetTheme.stopRing,
                         busGlyphColor: WidgetTheme.busGlyph, labelColor: WidgetTheme.secondary)
    }

    private var hairline: some View {
        Rectangle()
            .fill(WidgetTheme.hairline)
            .frame(height: 1)
    }

    // MARK: - Small

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 4)
            HStack {
                Spacer(minLength: 0)
                TripProgressRing(fraction: entry.progress.fraction, centerText: minutesLeft,
                                 caption: minutesCaption, tint: WidgetTheme.accent, lineWidth: 6,
                                 trackColor: WidgetTheme.track, refined: true, numberSize: 24)
                    .frame(width: 66, height: 66)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 4)
            Group {
                if let live = entry.live {
                    Text(PlaceNames.display(live.busNumber))
                        .font(.widgetSerif(.footnote))
                    Text(PlaceNames.display(live.stopName))
                        .widgetLabel()
                        .padding(.top, 1)
                } else if let next = entry.trips.first {
                    Text(next.trip.tripName)
                        .font(.widgetSerif(.footnote))
                    Text(next.leavesAt, style: .time)
                        .widgetLabel()
                        .padding(.top, 1)
                } else {
                    Text("No buses this week")
                        .font(.widgetSerif(.footnote))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Medium

    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            busSummary
            Spacer(minLength: 0)
            track
        }
        .accessibilityElement(children: .combine)
    }

    // The main line: the live bus and its ETA, or the next timetable bus.
    @ViewBuilder
    private var busSummary: some View {
        if let live = entry.live {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(PlaceNames.display(live.busNumber))
                        .font(.widgetSerif(.title3))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    // Only when riders on board said it is crowded.
                    if live.crowd == "full" {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(WidgetTheme.crowdColor(live.crowd))
                                .frame(width: 6, height: 6)
                            Text(live.crowdText)
                                .font(.caption2)
                                .foregroundStyle(WidgetTheme.secondary)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(live.etaMinutes)")
                            .font(.widgetSerif(size: 34))
                            .monospacedDigit()
                        Text("min")
                            .widgetLabel()
                    }
                    Text(String(format: "%.1f km", live.distanceKm))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.secondary)
                }
            }
        } else if let next = entry.trips.first {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(PlaceNames.display(next.trip.title))
                        .font(.widgetSerif(.title3))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    countdown(next)
                        .font(.caption2)
                        .foregroundStyle(WidgetTheme.secondary)
                }
                Spacer()
                Text(next.leavesAt, style: .time)
                    .font(.widgetSerif(size: 26))
                    .monospacedDigit()
            }
        } else {
            Text("No more buses this week")
                .font(.widgetSerif(.title3))
        }
    }

    // "in 25 min" while it's today, otherwise the day name.
    private func countdown(_ trip: UpcomingTrip) -> some View {
        Group {
            if Calendar.current.isDateInToday(trip.leavesAt) {
                Text(trip.leavesAt, style: .relative)
            } else {
                Text(trip.leavesAt, format: .dateTime.weekday(.wide))
            }
        }
    }

    // MARK: - Large

    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                header
                Spacer()
                if let route = entry.route {
                    Text(route.displayName)
                        .widgetLabel()
                        .lineLimit(1)
                }
            }

            // The route map, matching light or dark mode. Without one, just the ring.
            if let map = colorScheme == .dark ? (entry.mapDark ?? entry.mapLight) : (entry.mapLight ?? entry.mapDark) {
                Image(uiImage: map)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 160)
                    .clipped()
                    // A soft fade from the map into the background below it.
                    .mask(
                        LinearGradient(stops: [.init(color: .black, location: 0),
                                               .init(color: .black, location: 0.7),
                                               .init(color: .clear, location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
                    .accessibilityLabel("Map of the route to \(stopName)")
            } else {
                HStack {
                    Spacer()
                    TripProgressRing(fraction: entry.progress.fraction, centerText: minutesLeft,
                                     caption: minutesCaption, tint: WidgetTheme.accent, lineWidth: 6,
                                     trackColor: WidgetTheme.track, refined: true, numberSize: 40)
                        .frame(width: 120, height: 120)
                    Spacer()
                }
                .frame(maxHeight: 160)
            }

            busSummary
            track

            // The next two buses from the timetable.
            if entry.live == nil {
                let later = Array(entry.trips.dropFirst().prefix(2))
                if !later.isEmpty {
                    hairline
                    ForEach(later, id: \.self) { trip in
                        HStack {
                            Text(PlaceNames.display(trip.trip.title))
                                .lineLimit(1)
                            Spacer()
                            Text(trip.leavesAt, style: .time)
                                .monospacedDigit()
                        }
                        .font(.caption)
                        .foregroundStyle(WidgetTheme.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview(as: .systemMedium) {
    KUETBusWidget()
} timeline: {
    NextBusEntry.sample
}

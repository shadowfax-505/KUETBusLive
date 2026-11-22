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
    // The route map in the large widget runs edge to edge across the top, and
    // the bus details sit on a frosted panel over its lower part. It is drawn at this size so it isn't cropped.
    static let mapSize = CGSize(width: 364, height: 330)

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
            KUETMark()
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
                         labelColor: WidgetTheme.secondary,
                         labelFont: WidgetFont.current.label(),
                         stopEmphasis: WidgetTheme.primary)
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
            // Room under the header so the ring doesn't crowd it.
            Spacer(minLength: 10)
            HStack {
                Spacer(minLength: 0)
                TripProgressRing(fraction: entry.progress.fraction, centerText: minutesLeft,
                                 caption: minutesCaption, tint: WidgetTheme.accent, lineWidth: 6,
                                 trackColor: WidgetTheme.track, refined: true, numberSize: 24,
                                 numberFont: .widgetNumber(size: 24))
                    .frame(width: 62, height: 62)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 4)
            Group {
                if let live = entry.live {
                    Text(PlaceNames.display(live.busNumber))
                        .widgetTitle(.footnote)
                    Text(PlaceNames.display(live.stopName))
                        .widgetLabel()
                        .padding(.top, 1)
                } else if let next = entry.trips.first {
                    Text(next.trip.tripName)
                        .widgetTitle(.footnote)
                    Text(next.leavesAt, style: .time)
                        .widgetLabel()
                        .padding(.top, 1)
                } else {
                    Text("No buses this week")
                        .widgetTitle(.footnote)
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
            busSummary()
            Spacer(minLength: 0)
            track
        }
        .accessibilityElement(children: .combine)
    }

    // The main line: the live bus and its ETA, or the next timetable bus.
    // showsETA is false when a ring next to it already shows the minutes.
    @ViewBuilder
    private func busSummary(showsETA: Bool = true) -> some View {
        if let live = entry.live {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(PlaceNames.display(live.busNumber))
                        .widgetTitle(.title3)
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
                    if showsETA {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(live.etaMinutes)")
                                .font(.widgetNumber(size: 34))
                                .monospacedDigit()
                            Text("min")
                                .widgetLabel()
                        }
                    }
                    Text(String(format: "%.1f km", live.distanceKm))
                        .font(showsETA ? .caption2 : .widgetNumber(size: 22))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.secondary)
                }
            }
        } else if let next = entry.trips.first {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(PlaceNames.display(next.trip.title))
                        .widgetTitle(.title3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if showsETA {
                        countdown(next)
                            .font(.caption2)
                            .foregroundStyle(WidgetTheme.secondary)
                    }
                }
                Spacer()
                Text(next.leavesAt, style: .time)
                    .font(.widgetNumber(size: 26))
                    .monospacedDigit()
            }
        } else {
            Text("No more buses this week")
                .widgetTitle(.title3)
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
        // Without a map the ring stands in for it and already shows the minutes.
        let map = colorScheme == .dark ? (entry.mapDark ?? entry.mapLight) : (entry.mapLight ?? entry.mapDark)
        // The next two buses after the first one, which is live or shown above.
        let later = Array(entry.trips.dropFirst().prefix(2))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                header
                Spacer()
                if let route = entry.route {
                    Text(route.displayName)
                        .widgetLabel()
                        .lineLimit(1)
                }
            }

            // The route map sits behind this part (see NextBusWidgetBackground).
            // Without one, the ring stands in for it.
            if map != nil {
                Color.clear
                    .frame(maxHeight: .infinity)
                    .accessibilityElement()
                    .accessibilityLabel("Map of the route to \(stopName)")
            } else {
                HStack {
                    Spacer()
                    TripProgressRing(fraction: entry.progress.fraction, centerText: minutesLeft,
                                     caption: minutesCaption, tint: WidgetTheme.accent, lineWidth: 6,
                                     trackColor: WidgetTheme.track, refined: true, numberSize: 40,
                                     numberFont: .widgetNumber(size: 40))
                        .frame(width: 120, height: 120)
                    Spacer()
                }
                .frame(maxHeight: 160)
            }

            if map != nil {
                // Over the map, the details sit on a frosted panel that reaches
                // to 8pt from the widget's edges.
                details(later: later, showsETA: true)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(colors: [WidgetTheme.backgroundTop.opacity(0.62),
                                                          WidgetTheme.backgroundBottom.opacity(0.86)],
                                                 startPoint: .top, endPoint: .bottom))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                            )
                    )
                    .padding(.horizontal, -8)
                    .padding(.bottom, -8)
            } else {
                details(later: later, showsETA: false)
                Spacer(minLength: 0)
            }
        }
    }

    // The bus, its track and the next two buses from the timetable.
    private func details(later: [UpcomingTrip], showsETA: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            busSummary(showsETA: showsETA)
            track
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
    }
}

// The widget's background: the rider's colour, and on the large widget the route
// map running edge to edge across the top. Lower down, where the frosted panel
// sits, a blurred copy of the map shows through, and the map fades into the
// colour at the bottom. A light veil at the very top keeps the header readable.
struct NextBusWidgetBackground: View {
    let entry: NextBusEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            WidgetTheme.background
            if family == .systemLarge,
               let map = usesDarkMap ? (entry.mapDark ?? entry.mapLight) : (entry.mapLight ?? entry.mapDark) {
                ZStack {
                    mapImage(map)
                    // The frosted part: the same map, blurred, below the route.
                    mapImage(map)
                        .blur(radius: 10, opaque: true)
                        .mask(
                            LinearGradient(stops: [.init(color: .clear, location: 0.6),
                                                   .init(color: .black, location: 0.66)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                }
                .frame(height: NextBusWidgetView.mapSize.height)
                .clipped()
                .mask(
                    LinearGradient(stops: [.init(color: .black, location: 0),
                                           .init(color: .black, location: 0.92),
                                           .init(color: .clear, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                )
                LinearGradient(colors: [WidgetTheme.backgroundTop.opacity(0.85), WidgetTheme.backgroundTop.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 56)
            }
        }
        .accessibilityHidden(true)
    }

    private func mapImage(_ map: UIImage) -> some View {
        Image(uiImage: map)
            .resizable()
            .scaledToFill()
            .frame(height: NextBusWidgetView.mapSize.height)
            .frame(maxWidth: .infinity)
            .clipped()
    }

    // Forest and violet are deep colours with light text even in light mode, so
    // they take the dark map: a pale map would fade into them through a muddy band.
    private var usesDarkMap: Bool {
        colorScheme == .dark || WidgetColour.current == .forest || WidgetColour.current == .violet
    }
}

#Preview(as: .systemMedium) {
    KUETBusWidget()
} timeline: {
    NextBusEntry.sample
}

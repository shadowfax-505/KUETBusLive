//
//  NextBusWidgetView.swift
//  KUETBusWidget
//
//  Created by Muttakin Rahman Shoscho.
//
//  The look of the home screen widget in its small and medium sizes.
//  - small: a ring showing how far along the trip is, with minutes left inside
//  - medium: the next bus plus the trip track from KUET to my stop
//

import WidgetKit
import SwiftUI

// KUET colours, matching the app icon: deep blue with a warm yellow accent.
enum KUETWidgetStyle {
    static let blue = Color(red: 0.05, green: 0.20, blue: 0.45)
    static let lightBlue = Color(red: 0.12, green: 0.40, blue: 0.75)
    static let yellow = Color(red: 1.0, green: 0.78, blue: 0.20)

    static var background: some View {
        LinearGradient(colors: [blue, lightBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct NextBusWidgetView: View {
    let entry: NextBusEntry
    @Environment(\.widgetFamily) private var family

    var stopName: String {
        entry.live?.stopName ?? entry.favoriteStop ?? "My stop"
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                medium
            default:
                small
            }
        }
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "bus.fill")
                .foregroundStyle(KUETWidgetStyle.yellow)
            Text("KUET Bus")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.85))
        }
        .accessibilityHidden(true)
    }

    // Minutes until the next bus leaves, or the live ETA.
    private var minutesLeft: String {
        if let live = entry.live {
            return "\(live.etaMinutes)"
        }
        guard let next = entry.trips.first else { return "--" }
        let minutes = Int(next.leavesAt.timeIntervalSince(entry.date) / 60)
        return minutes < 100 ? "\(max(minutes, 0))" : "\(minutes / 60)h"
    }

    private var track: some View {
        TripProgressView(progress: entry.progress, endLabel: stopName,
                         tint: KUETWidgetStyle.yellow, trackColor: .white.opacity(0.3))
            .environment(\.colorScheme, .dark)   // white labels on the blue background
    }

    // MARK: - Small

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            HStack(alignment: .center, spacing: 8) {
                TripProgressRing(fraction: entry.progress.fraction, centerText: minutesLeft,
                                 tint: KUETWidgetStyle.yellow)
                    .frame(width: 64, height: 64)
                Spacer(minLength: 0)
            }
            if let live = entry.live {
                Text(live.busNumber)
                    .font(.caption.bold())
                    .lineLimit(1)
                Text("to \(live.stopName)")
                    .font(.caption2)
                    .opacity(0.8)
                    .lineLimit(1)
            } else if let next = entry.trips.first {
                Text(next.trip.tripName)
                    .font(.caption.bold())
                Text(next.leavesAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(KUETWidgetStyle.yellow)
            } else {
                Text("No buses this week")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Medium

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                header
                Spacer()
                Label(stopName, systemImage: "star.fill")
                    .font(.caption.bold())
                    .foregroundStyle(KUETWidgetStyle.yellow)
                    .lineLimit(1)
            }
            busSummary
            track
        }
        .accessibilityElement(children: .combine)
    }

    // The main line: the live bus and its ETA, or the next timetable bus.
    @ViewBuilder
    private var busSummary: some View {
        if let live = entry.live {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(live.busNumber)
                        .font(.headline)
                        .lineLimit(1)
                    Label(live.crowdText, systemImage: "person.3.fill")
                        .font(.caption2)
                        .opacity(0.85)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(live.etaMinutes) min")
                        .font(.title2.bold())
                        .foregroundStyle(KUETWidgetStyle.yellow)
                    Text(String(format: "%.1f km", live.distanceKm))
                        .font(.caption2)
                        .opacity(0.8)
                }
            }
        } else if let next = entry.trips.first {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(next.trip.title)
                        .font(.headline)
                        .lineLimit(1)
                    countdown(next)
                        .font(.caption2)
                        .opacity(0.85)
                }
                Spacer()
                Text(next.leavesAt, style: .time)
                    .font(.title3.bold())
                    .foregroundStyle(KUETWidgetStyle.yellow)
            }
        } else {
            Text("No more buses this week")
                .font(.headline)
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
}

#Preview(as: .systemMedium) {
    KUETBusWidget()
} timeline: {
    NextBusEntry.sample
}

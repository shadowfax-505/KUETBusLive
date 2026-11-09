//
//  NextBusWidgetView.swift
//  KUETBusWidget
//
//  Created by Muttakin Rahman Shoscho.
//
//  The look of the home screen widget in its small and medium sizes.
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

    var body: some View {
        if let next = entry.trips.first {
            switch family {
            case .systemMedium:
                medium(next)
            default:
                small(next)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                header
                Spacer()
                Text("No more buses this week")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "bus.fill")
                .foregroundStyle(KUETWidgetStyle.yellow)
            Text("KUET Bus")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.85))
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

    private func small(_ next: UpcomingTrip) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Spacer(minLength: 0)
            Text(next.trip.tripName)
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(next.trip.spot)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            Text(next.leavesAt, style: .time)
                .font(.headline)
                .foregroundStyle(KUETWidgetStyle.yellow)
            countdown(next)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func medium(_ next: UpcomingTrip) -> some View {
        HStack(alignment: .top, spacing: 12) {
            small(next)

            // The two buses after that.
            VStack(alignment: .leading, spacing: 6) {
                if let stop = entry.favoriteStop {
                    Label(stop, systemImage: "star.fill")
                        .font(.caption.bold())
                        .foregroundStyle(KUETWidgetStyle.yellow)
                        .lineLimit(1)
                }
                Text("Then")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                ForEach(entry.trips.dropFirst().prefix(2), id: \.self) { later in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(later.trip.title)
                            .font(.caption.bold())
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(later.leavesAt, style: .time)
                            // A bus on another day says which day, e.g. "Tue".
                            if !Calendar.current.isDateInToday(later.leavesAt) {
                                Text(later.leavesAt, format: .dateTime.weekday(.abbreviated))
                            }
                        }
                        .font(.caption2)
                    }
                    .foregroundStyle(.white)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview(as: .systemMedium) {
    KUETBusWidget()
} timeline: {
    NextBusEntry.sample
}

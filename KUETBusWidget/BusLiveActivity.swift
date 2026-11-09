//
//  BusLiveActivity.swift
//  KUETBusWidget
//
//  Created by Muttakin Rahman Shoscho.
//
//  How the Live Activity looks on the Lock Screen and in the Dynamic Island.
//  The Dynamic Island has three layouts:
//  - compact: a small piece on each side of the camera (bus icon, ETA)
//  - minimal: a single dot when another app's activity is also running
//  - expanded: the big view shown when the rider long-presses the island
//

import ActivityKit
import WidgetKit
import SwiftUI

struct BusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusTripAttributes.self) { context in
            // Lock Screen and notification banner
            LockScreenTripView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(KUETWidgetStyle.blue)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bus.fill")
                        .font(.title2)
                        .foregroundStyle(KUETWidgetStyle.yellow)
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.etaText)
                        .font(.title3.bold())
                        .foregroundStyle(KUETWidgetStyle.yellow)
                        .contentTransition(.numericText())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.busNumber)
                            .font(.headline)
                        Text("To \(context.attributes.stopName) · \(context.state.distanceText)")
                            .font(.subheadline)
                        // A thin version of the trip track.
                        TripProgressView(progress: context.state.progress,
                                         endLabel: context.attributes.stopName,
                                         tint: KUETWidgetStyle.yellow,
                                         trackColor: .white.opacity(0.25),
                                         showLabels: false,
                                         thin: true)
                        HStack {
                            Label(context.state.crowdText, systemImage: "person.3.fill")
                            Spacer()
                            if context.state.isStale {
                                Label("No signal", systemImage: "wifi.exclamationmark")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "bus.fill")
                    .foregroundStyle(KUETWidgetStyle.yellow)
            } compactTrailing: {
                Text(context.state.etaText)
                    .font(.caption.bold())
                    .foregroundStyle(context.state.isStale ? .orange : .white)
            } minimal: {
                Image(systemName: "bus.fill")
                    .foregroundStyle(KUETWidgetStyle.yellow)
            }
            .keylineTint(KUETWidgetStyle.yellow)
        }
    }
}

struct LockScreenTripView: View {
    let attributes: BusTripAttributes
    let state: BusTripAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {
        HStack(spacing: 14) {
            Image(systemName: "bus.fill")
                .font(.title)
                .foregroundStyle(KUETWidgetStyle.yellow)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(attributes.busNumber)
                    .font(.headline)
                Text("To \(attributes.stopName) · \(state.distanceText)")
                    .font(.subheadline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 10) {
                    Label(state.crowdText, systemImage: "person.3.fill")
                    if state.isStale {
                        Label("No signal", systemImage: "wifi.exclamationmark")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            Text(state.etaText)
                .font(.title.bold())
                .foregroundStyle(KUETWidgetStyle.yellow)
                .contentTransition(.numericText())
        }

        // KUET to my stop, like a parcel tracker.
        TripProgressView(progress: state.progress,
                         endLabel: attributes.stopName,
                         tint: KUETWidgetStyle.yellow,
                         trackColor: .white.opacity(0.3))
            .environment(\.colorScheme, .dark)
        }
        .foregroundStyle(.white)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

#Preview("Lock Screen", as: .content, using: BusTripAttributes(busNumber: "Normal-2 · Rupsha", stopName: "Fulbarigate")) {
    BusLiveActivity()
} contentStates: {
    BusTripAttributes.ContentState(etaMinutes: 7, distanceKm: 3.2, crowd: "seats", isStale: false,
                                   progress: TripProgress(fraction: 0.45, stopFractions: [0.3, 0.6]))
    BusTripAttributes.ContentState(etaMinutes: 2, distanceKm: 0.6, crowd: "full", isStale: true,
                                   progress: TripProgress(fraction: 0.9, stopFractions: [0.3, 0.6]))
}

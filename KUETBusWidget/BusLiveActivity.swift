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
    private typealias Night = WidgetTheme.Night

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusTripAttributes.self) { context in
            // Lock Screen and notification banner
            LockScreenTripView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Night.background.opacity(0.92))
                .activitySystemActionForegroundColor(Night.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bus.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Night.accent)
                        .padding(.leading, 4)
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MinutesText(state: context.state, size: 26)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.busNumber)
                                .font(.widgetSerif(.headline))
                                .foregroundStyle(Night.primary)
                            Text("To \(context.attributes.stopName) · \(context.state.distanceText)")
                                .font(.caption)
                                .foregroundStyle(Night.secondary)
                        }
                        // A thin version of the trip track.
                        TripProgressView(progress: context.state.progress,
                                         endLabel: context.attributes.stopName,
                                         tint: Night.accent,
                                         trackColor: Night.track,
                                         showLabels: false,
                                         thin: true,
                                         refined: true,
                                         stopColor: Night.stopRing,
                                         busGlyphColor: WidgetTheme.busGlyph)
                        StatusLine(state: context.state)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "bus.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Night.accent)
            } compactTrailing: {
                Text(context.state.etaText)
                    .font(.system(.footnote, design: .serif).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(context.state.isStale ? WidgetTheme.terracotta : Night.primary)
                    .contentTransition(.numericText())
            } minimal: {
                Image(systemName: "bus.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Night.accent)
            }
            .keylineTint(Night.accent)
        }
    }
}

// Minutes left in serif with a small "MIN" beside it, or "Here" once the bus arrives.
private struct MinutesText: View {
    let state: BusTripAttributes.ContentState
    var size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            if state.hasArrived {
                Text("Here")
                    .font(.widgetSerif(size: size))
            } else {
                Text("\(state.etaMinutes)")
                    .font(.widgetSerif(size: size))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("min")
                    .widgetLabel(WidgetTheme.Night.secondary)
            }
        }
        .foregroundStyle(WidgetTheme.Night.primary)
    }
}

// Crowd with a small status dot, and a warning when the bus stops sending GPS.
private struct StatusLine: View {
    let state: BusTripAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(crowdColor)
                .frame(width: 6, height: 6)
            Text(state.crowdText)
            Spacer()
            if state.isStale {
                Label("No signal", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(WidgetTheme.terracotta)
            }
        }
        .font(.caption2)
        .foregroundStyle(WidgetTheme.Night.secondary)
    }

    private var crowdColor: Color {
        switch state.crowd {
        case "seats": return WidgetTheme.sage
        case "full": return WidgetTheme.terracotta
        default: return WidgetTheme.Night.secondary
        }
    }
}

struct LockScreenTripView: View {
    let attributes: BusTripAttributes
    let state: BusTripAttributes.ContentState
    private typealias Night = WidgetTheme.Night

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: "bus.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Night.accent)
                        Text(state.hasArrived ? "At your stop" : "Arriving in")
                            .widgetLabel(Night.secondary)
                    }
                    .font(.caption2)
                    .accessibilityHidden(true)
                    Text(attributes.busNumber)
                        .font(.widgetSerif(.title3))
                        .foregroundStyle(Night.primary)
                        .lineLimit(1)
                    Text("To \(attributes.stopName) · \(state.distanceText)")
                        .font(.footnote)
                        .foregroundStyle(Night.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                MinutesText(state: state, size: 40)
            }

            // KUET to my stop, like a parcel tracker.
            TripProgressView(progress: state.progress,
                             endLabel: attributes.stopName,
                             tint: Night.accent,
                             trackColor: Night.track,
                             refined: true,
                             stopColor: Night.stopRing,
                             busGlyphColor: WidgetTheme.busGlyph,
                             labelColor: Night.secondary)

            StatusLine(state: state)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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

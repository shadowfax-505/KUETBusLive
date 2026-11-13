//
//  TripProgressView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The trip progress drawings, shared by the app's trip card, the home screen
//  widget and the Live Activity:
//  - TripProgressView: a track from KUET to my stop, like a parcel tracker,
//    with dots for the stops, a filled part, and a bus at its current spot.
//  - TripProgressRing: the same progress as a ring, with minutes left inside.
//
//  Both come in two looks. The app's trip card uses the classic one, coloured
//  by the bus allocation. The widgets and the Live Activity use the refined
//  one: a thin track with a soft glow, stops as small rings, and serif numbers.
//

import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

struct TripProgressView: View {
    let progress: TripProgress
    var startLabel: String = "KUET"
    var endLabel: String
    var tint: Color = .blue
    var trackColor: Color = .gray.opacity(0.3)
    var showLabels = true
    var thin = false
    var refined = false
    var stopColor: Color = .white      // refined: the rings for the stops in between
    var busGlyphColor: Color = .white  // refined: the bus symbol inside the circle
    var labelColor: Color? = nil

    var body: some View {
        Group {
            if refined {
                refinedBody
            } else {
                classicBody
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trip progress")
        .accessibilityValue("\(Int(progress.fraction * 100)) percent of the way from \(startLabel) to \(endLabel)")
    }

    // MARK: Refined

    private var refinedBody: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let busSize: CGFloat = thin ? 16 : 20
                let busX = width * progress.fraction
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(trackColor)
                        .frame(height: 4)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(busX, 4), height: 4)
                        .shadow(color: tint.opacity(0.4), radius: 4)
                        .widgetAccentableIfAvailable()
                    ForEach(progress.stopFractions, id: \.self) { fraction in
                        Circle()
                            .strokeBorder(fraction <= progress.fraction ? tint : stopColor, lineWidth: 1.5)
                            .frame(width: 7, height: 7)
                            .offset(x: width * fraction - 3.5)
                    }
                    // My stop: a filled dot at the end.
                    Circle()
                        .fill(tint)
                        .frame(width: 9, height: 9)
                        .offset(x: width - 9)
                        .widgetAccentableIfAvailable()
                    // The bus
                    Image(systemName: "bus.fill")
                        .font(.system(size: thin ? 8 : 10, weight: .semibold))
                        .foregroundStyle(busGlyphColor)
                        .frame(width: busSize, height: busSize)
                        .background(Circle().fill(tint).shadow(color: tint.opacity(0.4), radius: 4))
                        .offset(x: min(max(busX - busSize / 2, 0), width - busSize))
                        .widgetAccentableIfAvailable()
                }
                .frame(height: busSize)
                .frame(maxHeight: .infinity)
            }
            .frame(height: thin ? 16 : 20)

            if showLabels {
                HStack {
                    Text(startLabel)
                    Spacer()
                    Text(endLabel)
                        .lineLimit(1)
                }
                .font(.caption2.weight(.semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(labelColor ?? .secondary)
            }
        }
    }

    // MARK: Classic

    private var classicBody: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = thin ? 4.0 : 6.0
                let busX = width * progress.fraction
                ZStack(alignment: .leading) {
                    // Whole track
                    Capsule()
                        .fill(trackColor)
                        .frame(height: height)
                    // The part the bus has already covered
                    Capsule()
                        .fill(tint)
                        .frame(width: max(busX, height), height: height)
                    // Stops in between
                    ForEach(progress.stopFractions, id: \.self) { fraction in
                        Circle()
                            .fill(fraction <= progress.fraction ? tint : Color.white)
                            .overlay(Circle().stroke(tint, lineWidth: 1.5))
                            .frame(width: height + 4, height: height + 4)
                            .offset(x: width * fraction - (height + 4) / 2)
                    }
                    // My stop at the end of the track
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: thin ? 10 : 14))
                        .foregroundStyle(.orange, .white)
                        .offset(x: width - (thin ? 10 : 14))
                    // The bus
                    Image(systemName: "bus.fill")
                        .font(.system(size: thin ? 9 : 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(thin ? 3 : 4)
                        .background(Circle().fill(tint))
                        .offset(x: min(max(busX - (thin ? 7.5 : 10), 0), width - (thin ? 15 : 20)))
                }
                .frame(height: thin ? 15 : 20)
                .frame(maxHeight: .infinity)
            }
            .frame(height: thin ? 15 : 20)

            if showLabels {
                HStack {
                    Text(startLabel)
                    Spacer()
                    Text(endLabel)
                        .lineLimit(1)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct TripProgressRing: View {
    let fraction: Double
    let centerText: String
    var caption: String = "min"
    var tint: Color = .yellow
    var lineWidth: CGFloat = 7
    var trackColor: Color? = nil
    var refined = false
    var numberSize: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor ?? tint.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: refined ? tint.opacity(0.4) : .clear, radius: 4)
                .widgetAccentableIfAvailable()
            if refined {
                VStack(spacing: 0) {
                    Text(centerText)
                        .font(.system(size: numberSize, weight: .semibold, design: .serif))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(caption)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .opacity(0.6)
                }
                .padding(lineWidth + 2)
            } else {
                VStack(spacing: 0) {
                    Text(centerText)
                        .font(.title3.bold())
                        .minimumScaleFactor(0.6)
                    Text(caption)
                        .font(.caption2)
                        .opacity(0.8)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(centerText) \(caption), \(Int(fraction * 100)) percent of the trip done")
    }
}

extension View {
    // Marks the accent parts so they take the tint colour when the home screen
    // is tinted. Does nothing in the app, where there is no widget rendering mode.
    @ViewBuilder
    func widgetAccentableIfAvailable() -> some View {
        #if canImport(WidgetKit)
        self.widgetAccentable()
        #else
        self
        #endif
    }
}

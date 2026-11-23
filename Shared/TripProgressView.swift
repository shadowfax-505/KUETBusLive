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
//    The refined look draws the bus from BusArt.swift, from above or from the
//    side as picked in Settings > Appearance.
//  - TripProgressRing: the same progress as a ring, with minutes left inside.
//
//  Both come in two looks. The app's trip card uses the classic one, coloured
//  by the bus allocation. The widgets and the Live Activity use the refined
//  one: a thin track with a soft glow, small dots for the stops, a ring for my
//  stop, and serif numbers.
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
    var stopColor: Color = .white      // refined: the dots for the stops in between
    var busStyle: BusStyle = .current  // refined: how the bus on the track is drawn
    var labelColor: Color? = nil
    var labelFont: Font? = nil         // refined: the font of the two end labels
    var stopEmphasis: Color? = nil     // refined: my stop in this colour, bolder, with a pin

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
            refinedTrack
            if showLabels {
                HStack {
                    Text(startLabel)
                    Spacer()
                    if let stopEmphasis {
                        // My stop is what the rider reads, so it stands out from KUET.
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .imageScale(.small)
                            Text(endLabel)
                                .lineLimit(1)
                        }
                        .fontWeight(.bold)
                        .scaleEffect(1.15, anchor: .trailing)
                        .foregroundStyle(stopEmphasis)
                    } else {
                        Text(endLabel)
                            .lineLimit(1)
                    }
                }
                .font(labelFont ?? .caption2.weight(.semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(labelColor ?? .secondary)
            }
        }
    }

    // The bus drawing's size on the track. From above, the bus sits on the line;
    // from the side, its wheels rest on it.
    private var busSize: CGSize {
        switch busStyle {
        case .above:
            let length: CGFloat = thin ? 32 : 38
            return CGSize(width: length, height: length * BusFromAbove.width / BusFromAbove.length)
        case .side:
            let length: CGFloat = thin ? 34 : 42
            return CGSize(width: length, height: length * BusFromSide.size.height / BusFromSide.size.width)
        }
    }

    // Where the line runs, measured from the top of the bus drawing.
    private var lineY: CGFloat {
        busStyle == .side ? busSize.height * BusFromSide.roadLine : busSize.height / 2
    }

    // How much of the drawing, front to back, is the bus itself.
    private var bodyLength: CGFloat {
        switch busStyle {
        case .above: return busSize.width * BusFromAbove.bodyShare
        case .side: return busSize.width * (BusFromSide.bodyEnd - BusFromSide.bodyStart)
        }
    }

    private var refinedTrack: some View {
        let ring: CGFloat = thin ? 9 : 11
        let line: CGFloat = 4
        let rowHeight = busSize.height
        return GeometryReader { geometry in
            let width = geometry.size.width
            // The middle of the bus, kept on the track at either end.
            let busX = min(max(width * progress.fraction, bodyLength / 2), width - bodyLength / 2)
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(trackColor)
                    .frame(width: max(width - ring / 2, 0), height: line)
                    .offset(y: lineY - line / 2)
                // The covered part ends under the bus.
                Capsule()
                    .fill(tint)
                    .frame(width: max(busX, line), height: line)
                    .shadow(color: tint.opacity(0.4), radius: 4)
                    .offset(y: lineY - line / 2)
                    .widgetAccentableIfAvailable()
                ForEach(progress.stopFractions, id: \.self) { fraction in
                    Circle()
                        .fill(fraction <= progress.fraction ? tint : stopColor)
                        .frame(width: 5, height: 5)
                        .offset(x: width * fraction - 2.5, y: lineY - 2.5)
                }
                // My stop: a ring at the end of the track.
                Circle()
                    .strokeBorder(tint, lineWidth: 2.2)
                    .frame(width: ring, height: ring)
                    .offset(x: width - ring, y: lineY - ring / 2)
                    .widgetAccentableIfAvailable()
                // The bus, nose to the right.
                bus
                    .frame(width: busSize.width, height: busSize.height)
                    .offset(x: busX - busSize.width / 2)
            }
            .animation(.smooth(duration: 1.2), value: progress.fraction)
        }
        .frame(height: rowHeight)
    }

    @ViewBuilder
    private var bus: some View {
        switch busStyle {
        case .above: BusFromAbove()
        case .side: BusFromSide()
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
    var numberFont: Font? = nil   // refined: the widget passes the rider's widget font

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
                        .font(numberFont ?? .system(size: numberSize, weight: .semibold, design: .serif))
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

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

import SwiftUI

struct TripProgressView: View {
    let progress: TripProgress
    var startLabel: String = "KUET"
    var endLabel: String
    var tint: Color = .blue
    var trackColor: Color = .gray.opacity(0.3)
    var showLabels = true
    var thin = false

    var body: some View {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trip progress")
        .accessibilityValue("\(Int(progress.fraction * 100)) percent of the way from \(startLabel) to \(endLabel)")
    }
}

struct TripProgressRing: View {
    let fraction: Double
    let centerText: String
    var caption: String = "min"
    var tint: Color = .yellow
    var lineWidth: CGFloat = 7

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(centerText)
                    .font(.title3.bold())
                    .minimumScaleFactor(0.6)
                Text(caption)
                    .font(.caption2)
                    .opacity(0.8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(centerText) \(caption), \(Int(fraction * 100)) percent of the trip done")
    }
}

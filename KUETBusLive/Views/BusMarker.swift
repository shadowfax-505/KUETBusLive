//
//  BusMarker.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The bus on the live map: a small bus seen from above that points the way it
//  drives. The soft halo shows who may ride it (blue for students, purple for
//  teachers), the dot on its roof shows the crowd, and a faded bus has sent no
//  position for over a minute.
//

import SwiftUI

struct BusMarker: View {
    let bus: Bus
    let heading: Double?
    let isSelected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Who may ride: a soft disc, and a ring that keeps spreading out while the bus is live.
            Circle()
                .fill(bus.allocation.color.opacity(isSelected ? 0.28 : 0.18))
                .frame(width: 46, height: 46)
            if !bus.isStale && !reduceMotion {
                Circle()
                    .stroke(bus.allocation.color.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 46, height: 46)
                    .scaleEffect(pulse ? 1.7 : 1)
                    .opacity(pulse ? 0 : 0.8)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                            pulse = true
                        }
                    }
            }

            TopDownBus(crowd: MapTheme.crowd(bus.crowd))
                .frame(width: 20, height: 40)
                // No heading yet (the bus hasn't moved): it stands facing north.
                .rotationEffect(.degrees(heading ?? 0))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: heading)
                .shadow(color: .black.opacity(0.35), radius: isSelected ? 6 : 3, y: isSelected ? 3 : 1.5)
                .opacity(bus.isStale ? 0.45 : 1)
        }
        .frame(width: 56, height: 56)
        .scaleEffect(isSelected ? 1.25 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.65), value: isSelected)
    }
}

// An original bus outline from above, nose up: body, windscreen, roof stripe,
// rear window and mirrors. Drawn with shapes, so it stays sharp at any size.
struct TopDownBus: View {
    let crowd: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Mirrors, just behind the front corners.
                HStack(spacing: w * 0.9) {
                    Capsule().fill(MapTheme.busOutline).frame(width: w * 0.16, height: h * 0.07)
                    Capsule().fill(MapTheme.busOutline).frame(width: w * 0.16, height: h * 0.07)
                }
                .position(x: w / 2, y: h * 0.17)

                // Body
                RoundedRectangle(cornerRadius: w * 0.32, style: .continuous)
                    .fill(MapTheme.busBody)
                    .overlay(
                        RoundedRectangle(cornerRadius: w * 0.32, style: .continuous)
                            .stroke(MapTheme.busOutline, lineWidth: 1.2)
                    )

                // Windscreen at the front
                UnevenRoundedRectangle(topLeadingRadius: w * 0.26, bottomLeadingRadius: w * 0.08,
                                       bottomTrailingRadius: w * 0.08, topTrailingRadius: w * 0.26,
                                       style: .continuous)
                    .fill(MapTheme.busGlass)
                    .frame(width: w * 0.78, height: h * 0.17)
                    .position(x: w / 2, y: h * 0.13)

                // Brass roof stripe, with the crowd dot on it
                Capsule()
                    .fill(MapTheme.accent)
                    .frame(width: w * 0.22, height: h * 0.46)
                    .position(x: w / 2, y: h * 0.53)
                Circle()
                    .fill(crowd)
                    .overlay(Circle().stroke(MapTheme.busBody, lineWidth: 1))
                    .frame(width: w * 0.42, height: w * 0.42)
                    .position(x: w / 2, y: h * 0.53)

                // Rear window
                RoundedRectangle(cornerRadius: w * 0.06, style: .continuous)
                    .fill(MapTheme.busGlass.opacity(0.8))
                    .frame(width: w * 0.62, height: h * 0.06)
                    .position(x: w / 2, y: h * 0.9)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 30) {
        TopDownBus(crowd: MapTheme.sage).frame(width: 40, height: 80)
        TopDownBus(crowd: MapTheme.terracotta).frame(width: 40, height: 80).rotationEffect(.degrees(60))
    }
    .padding()
}

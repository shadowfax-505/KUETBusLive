//
//  BusMarker.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The bus on the live map: a small glossy white bus seen from above that points
//  the way it drives. The soft halo shows who may ride it (blue for students, purple for
//  teachers), a soft red glow (and a red roof dot) means riders on board said it
//  is crowded, and a faded bus has sent no position for over a minute.
//

import SwiftUI

struct BusMarker: View {
    let bus: Bus
    let heading: Double?
    let isSelected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var glow = false

    var body: some View {
        ZStack {
            // Who may ride: a soft disc, and a ring that keeps spreading out while the bus is live.
            Circle()
                .fill(bus.allocation.color.opacity(isSelected ? 0.18 : 0.1))
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

            // Crowded (riders on board said so in the last ten minutes): a soft red glow
            // that breathes slowly. Nothing at all when it isn't crowded.
            if bus.isCrowded() {
                Circle()
                    .fill(RadialGradient(colors: [MapTheme.terracotta.opacity(0.45), MapTheme.terracotta.opacity(0)],
                                         center: .center, startRadius: 6, endRadius: 30))
                    .frame(width: 60, height: 60)
                    .scaleEffect(glow ? 1.12 : 0.92)
                    .opacity(glow ? 1 : 0.7)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                            glow = true
                        }
                    }
                    .accessibilityHidden(true)
            }

            TopDownBus(crowd: bus.isCrowded() ? MapTheme.terracotta : MapTheme.sage)
                .frame(width: 20, height: 40)
                // No heading yet (the bus hasn't moved): it stands facing north.
                .rotationEffect(.degrees(heading ?? 0))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: heading)
                .shadow(color: .black.opacity(0.3), radius: isSelected ? 7 : 4, y: isSelected ? 4 : 2)
                .opacity(bus.isStale ? 0.45 : 1)
        }
        .frame(width: 56, height: 56)
        .scaleEffect(isSelected ? 1.25 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.65), value: isSelected)
    }
}

// An original glossy white bus from above, nose up: body with a soft sheen,
// windscreen, roof panels, rear window, mirrors and red tail-lights.
// Drawn with shapes, so it stays sharp at any size.
struct TopDownBus: View {
    let crowd: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Mirrors, just behind the front corners.
                HStack(spacing: w * 0.9) {
                    Capsule().fill(MapTheme.busGlass).frame(width: w * 0.16, height: h * 0.07)
                    Capsule().fill(MapTheme.busGlass).frame(width: w * 0.16, height: h * 0.07)
                }
                .position(x: w / 2, y: h * 0.17)

                // Body: white with a light sheen across it.
                RoundedRectangle(cornerRadius: w * 0.3, style: .continuous)
                    .fill(LinearGradient(colors: [MapTheme.busShine, MapTheme.busBody, MapTheme.busBody, MapTheme.busShine],
                                         startPoint: .leading, endPoint: .trailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: w * 0.3, style: .continuous)
                            .stroke(MapTheme.busOutline, lineWidth: 0.8)
                    )

                // Windscreen at the front
                UnevenRoundedRectangle(topLeadingRadius: w * 0.26, bottomLeadingRadius: w * 0.08,
                                       bottomTrailingRadius: w * 0.08, topTrailingRadius: w * 0.26,
                                       style: .continuous)
                    .fill(MapTheme.busGlass)
                    .frame(width: w * 0.78, height: h * 0.15)
                    .position(x: w / 2, y: h * 0.12)

                // Roof panels, with the crowd dot between them
                VStack(spacing: h * 0.2) {
                    RoundedRectangle(cornerRadius: w * 0.06).fill(MapTheme.busShine).frame(width: w * 0.5, height: h * 0.1)
                    RoundedRectangle(cornerRadius: w * 0.06).fill(MapTheme.busShine).frame(width: w * 0.5, height: h * 0.1)
                }
                .position(x: w / 2, y: h * 0.53)
                Circle()
                    .fill(crowd)
                    .overlay(Circle().stroke(MapTheme.busBody, lineWidth: 1))
                    .frame(width: w * 0.32, height: w * 0.32)
                    .position(x: w / 2, y: h * 0.53)

                // Rear window
                RoundedRectangle(cornerRadius: w * 0.06, style: .continuous)
                    .fill(MapTheme.busGlass.opacity(0.85))
                    .frame(width: w * 0.62, height: h * 0.05)
                    .position(x: w / 2, y: h * 0.88)

                // Tail-lights at the back corners
                HStack(spacing: w * 0.42) {
                    Capsule().fill(MapTheme.tailLight).frame(width: w * 0.18, height: h * 0.035)
                    Capsule().fill(MapTheme.tailLight).frame(width: w * 0.18, height: h * 0.035)
                }
                .shadow(color: MapTheme.tailLight.opacity(0.6), radius: 1.5)
                .position(x: w / 2, y: h * 0.955)
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

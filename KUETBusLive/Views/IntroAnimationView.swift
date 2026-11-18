//
//  IntroAnimationView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The launch intro. The bus from the app icon drives in from the left along a
//  dotted road, the location pin drops onto its corner, "KUET" lights up on the
//  sign and the app name appears. Then the logo zooms towards the viewer and
//  fades away to show the app. Everything is drawn in the icon's 108 x 108 grid
//  so it lines up with the icon exactly.
//

import SwiftUI

struct IntroAnimationView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var running = false
    @State private var clock = IntroClock()

    /// The whole intro, in milliseconds.
    private static let duration = 1550.0
    /// With Reduce Motion the still logo only fades away.
    private static let stillDuration = 1200.0
    /// On screen the icon's 108 units are 300 points wide.
    private static let size: CGFloat = 300

    var body: some View {
        TimelineView(.animation) { timeline in
            let ms = running ? clock.tick(timeline.date) : 0
            let total = reduceMotion ? Self.stillDuration : Self.duration
            let frame = reduceMotion ? IntroFrame.still(at: ms) : IntroFrame(at: ms)

            ZStack {
                Color.black.ignoresSafeArea()

                ZStack {
                    IntroLogo(frame: frame)
                        .frame(width: Self.size, height: Self.size)

                    Text("KUET Bus Live")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(frame.title)
                        .offset(y: Self.size * 44 / 108 + frame.titleRise)
                }
                .scaleEffect(frame.zoom)
                .opacity(frame.fade)
            }
            .onChange(of: ms >= total) { _, done in
                if done { onFinished() }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("KUET Bus Live")
        // .task (not .onAppear) waits until the app has finished launching,
        // so the intro is actually seen and not played behind a busy start.
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            running = true
        }
    }
}

/// Counts the intro's time frame by frame. A frame that comes late (the app is
/// still busy starting up) only moves the intro on by one frame's worth, so no
/// part of it is skipped.
private final class IntroClock {
    private var last: Date?
    private var elapsed = 0.0

    func tick(_ now: Date) -> Double {
        if let last {
            elapsed += min(max(now.timeIntervalSince(last), 0), 1.0 / 30) * 1000
        }
        last = now
        return elapsed
    }
}

/// Where every moving part is at one moment of the intro.
private struct IntroFrame {
    var busX = 0.0          // units
    var busY = 0.0          // units
    var busOpacity = 1.0
    var roadX = 0.0         // units
    var roadOpacity = 0.35
    var pinScale = 1.0
    var pinY = 0.0          // units
    var pinOpacity = 1.0
    var letters = 1.0
    var title = 1.0
    var titleRise: CGFloat = 0  // points
    var zoom: CGFloat = 1
    var fade = 1.0

    init(at t: Double) {
        // The bus (with its sign) slides in from the left and fades in quickly.
        let drive = progress(t, 0, 620)
        busX = -90 * (1 - easeOutQuint(drive))
        busOpacity = progress(t, 0, 120)
        // A small bounce as it stops.
        let bounce = progress(t, 520, 760)
        busY = bounce > 0 && bounce < 1 ? -sin(bounce * .pi) * 0.8 : 0

        // The road comes in from the right with the bus, then fades out.
        roadX = 40 * (1 - easeOutQuint(drive))
        roadOpacity = 0.35 * (1 - progress(t, 700, 1000))

        // The pin drops in, overshoots a little, and lands on its tip.
        let drop = progress(t, 450, 800)
        pinScale = 0.2 + 0.8 * easeOutBack(drop)
        pinY = -14 * (1 - easeOutCubic(drop))
        pinOpacity = progress(t, 450, 560)

        letters = progress(t, 600, 820)

        let name = progress(t, 650, 900)
        title = name
        titleRise = 10 * (1 - easeOutCubic(name))

        // The logo rushes towards the viewer and fades, showing the app.
        zoom = 1 + 7 * easeInCubic(progress(t, 1150, 1550))
        fade = 1 - easeOutCubic(progress(t, 1250, 1550))
    }

    private init() {}

    /// The finished logo standing still, fading out at the end.
    static func still(at t: Double) -> IntroFrame {
        var frame = IntroFrame()
        frame.roadOpacity = 0
        frame.fade = 1 - progress(t, 800, 1200)
        return frame
    }
}

/// The app icon's bus and pin, drawn in its 108-unit grid.
private struct IntroLogo: View {
    let frame: IntroFrame

    var body: some View {
        Canvas { context, size in
            let s = size.width / 108

            func rect(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> CGRect {
                CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
            }
            func fill(_ path: Path, _ color: Color, _ move: CGAffineTransform, in context: GraphicsContext) {
                context.fill(path.applying(move.concatenating(CGAffineTransform(scaleX: s, y: s))),
                             with: .color(color))
            }

            // The dotted road.
            var road = context
            road.opacity = frame.roadOpacity
            let roadMove = CGAffineTransform(translationX: frame.roadX, y: 0)
            var dots = Path()
            for x in stride(from: 4.0, through: 104, by: 5) {
                dots.addEllipse(in: rect(x - 1.1, 86 - 1.1, x + 1.1, 86 + 1.1))
            }
            fill(dots, .white, roadMove, in: road)

            // The bus.
            var bus = context
            bus.opacity = frame.busOpacity
            let busMove = CGAffineTransform(translationX: frame.busX, y: frame.busY)

            let wheelRadii = RectangleCornerRadii(bottomLeading: 2, bottomTrailing: 2)
            fill(Path(roundedRect: rect(38, 70, 45, 80), cornerRadii: wheelRadii), .hex(0x1A1A1A), busMove, in: bus)
            fill(Path(roundedRect: rect(63, 70, 70, 80), cornerRadii: wheelRadii), .hex(0x1A1A1A), busMove, in: bus)
            fill(Path(rect(32, 44, 35, 52)), .hex(0xF2F5F9), busMove, in: bus)
            fill(Path(rect(73, 44, 76, 52)), .hex(0xF2F5F9), busMove, in: bus)

            let bodyRadii = RectangleCornerRadii(topLeading: 8, bottomLeading: 5, bottomTrailing: 5, topTrailing: 8)
            fill(Path(roundedRect: rect(34, 34, 74, 73), cornerRadii: bodyRadii), .white, busMove, in: bus)

            fill(Path(roundedRect: rect(42.5, 35.8, 65.5, 43.2), cornerRadius: 2), .hex(0x1A1A1A), busMove, in: bus)

            fill(Path(roundedRect: rect(39, 45, 69, 58), cornerRadius: 2), .hex(0x141414), busMove, in: bus)
            var glare = Path()
            glare.addLines([CGPoint(x: 43, y: 46), CGPoint(x: 48, y: 46),
                            CGPoint(x: 44, y: 57), CGPoint(x: 42, y: 57)])
            glare.closeSubpath()
            fill(glare, .white.opacity(0.2), busMove, in: bus)

            fill(Path(rect(34, 60, 74, 63)), .hex(0xE6E6E6), busMove, in: bus)
            fill(Path(ellipseIn: rect(39, 64.5, 45, 70.5)), .hex(0xE6E6E6), busMove, in: bus)
            fill(Path(ellipseIn: rect(63, 64.5, 69, 70.5)), .hex(0xE6E6E6), busMove, in: bus)
            fill(Path(rect(49, 66, 59, 69)), .hex(0xD5DCE6), busMove, in: bus)

            // "KUET" on the sign plate.
            var sign = bus
            sign.opacity = frame.busOpacity * frame.letters
            let label = Text("KUET")
                .font(.system(size: 7.2 * s, weight: .bold))
                .tracking(0.7 * s)
                .foregroundColor(.white)
            sign.draw(label, at: CGPoint(x: (54 + frame.busX) * s, y: (39.5 + frame.busY) * s), anchor: .center)

            // The location pin, scaled about its tip.
            var pin = context
            pin.opacity = frame.pinOpacity
            let tip = CGPoint(x: 72, y: 43)
            let pinMove = CGAffineTransform(translationX: -tip.x, y: -tip.y)
                .concatenating(CGAffineTransform(scaleX: frame.pinScale, y: frame.pinScale))
                .concatenating(CGAffineTransform(translationX: tip.x, y: tip.y + frame.pinY))
            fill(teardrop(head: CGPoint(x: 72, y: 30), radius: 8, tip: tip), .white, pinMove, in: pin)
            fill(Path(ellipseIn: rect(72 - 2.8, 30 - 2.8, 72 + 2.8, 30 + 2.8)), .black, pinMove, in: pin)
        }
    }

    /// A map pin: a round head with straight sides meeting at the tip.
    private func teardrop(head: CGPoint, radius: Double, tip: CGPoint) -> Path {
        let distance = hypot(tip.x - head.x, tip.y - head.y)
        let down = atan2(tip.y - head.y, tip.x - head.x)
        let side = acos(radius / distance)
        var path = Path()
        path.move(to: tip)
        // Round the head from one side's tangent point over the top to the other.
        let from = down - side
        let to = down + side - 2 * .pi
        let steps = 64
        for i in 0...steps {
            let angle = from + (to - from) * Double(i) / Double(steps)
            path.addLine(to: CGPoint(x: head.x + radius * cos(angle), y: head.y + radius * sin(angle)))
        }
        path.closeSubpath()
        return path
    }
}

private extension Color {
    static func hex(_ value: UInt32) -> Color {
        Color(red: Double((value >> 16) & 0xFF) / 255,
              green: Double((value >> 8) & 0xFF) / 255,
              blue: Double(value & 0xFF) / 255)
    }
}

private func progress(_ t: Double, _ from: Double, _ to: Double) -> Double {
    min(max((t - from) / (to - from), 0), 1)
}

private func easeOutQuint(_ x: Double) -> Double { 1 - pow(1 - x, 5) }
private func easeOutCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
private func easeInCubic(_ x: Double) -> Double { x * x * x }
private func easeOutBack(_ x: Double) -> Double {
    let c1 = 1.70158
    let c3 = c1 + 1
    return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
}

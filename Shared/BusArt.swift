//
//  BusArt.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The bus that rides along the trip track, drawn in code so it stays sharp at
//  every size. It matches the bus on the Android map: a glossy white bus seen
//  from above with a soft shadow, dark side mirrors and windscreen at the front,
//  thin side windows, a light roof with two hatches and an air-con unit (dark for
//  teacher buses), a dark rear window, red tail lights and cream headlights.
//
//  The drawing works in the map icon's units: a 22 x 52 body with a 6.5 corner
//  radius and 9 points of room around it for the shadow, nose pointing up. The
//  view turns it so the nose points right, the way the bus moves on the track.
//

import SwiftUI

struct BusFromAbove: View {
    var teacher = false

    // The drawing with its shadow room: 70 long, 40 wide once turned nose right.
    static let length: CGFloat = 70
    static let width: CGFloat = 40
    // How much of the drawing is the bus itself, along its length.
    static let bodyShare: CGFloat = 52 / 70

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / Self.length, size.height / Self.width)
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: .degrees(90))
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -Self.width / 2, y: -Self.length / 2)
            Self.draw(in: &context, teacher: teacher)
        }
        .aspectRatio(Self.length / Self.width, contentMode: .fit)
        .accessibilityHidden(true)
    }

    // Nose up, in map icon units.
    private static func draw(in context: inout GraphicsContext, teacher: Bool) {
        let body = CGRect(x: 9, y: 9, width: 22, height: 52)
        let radius: CGFloat = 6.5
        let bodyPath = Path(roundedRect: body, cornerRadius: radius)

        // Soft shadow under the bus. The drawing is turned a quarter turn, so
        // "down the screen" is along +x here.
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.42), radius: 4, x: 2.5, y: 0))
            layer.fill(bodyPath, with: .color(.black.opacity(0.22)))
        }

        // Side mirrors at the front.
        let mirror = Color(white: 40 / 255)
        context.fill(Path(roundedRect: CGRect(x: body.minX - 3, y: body.minY + 7, width: 4, height: 3.5), cornerRadius: 1),
                     with: .color(mirror))
        context.fill(Path(roundedRect: CGRect(x: body.maxX - 1, y: body.minY + 7, width: 4, height: 3.5), cornerRadius: 1),
                     with: .color(mirror))

        // White body with a glossy sheen across it.
        let sheen = Gradient(stops: [
            .init(color: Color(white: 214 / 255), location: 0),
            .init(color: .white, location: 0.38),
            .init(color: Color(white: 246 / 255), location: 0.62),
            .init(color: Color(white: 208 / 255), location: 1),
        ])
        context.fill(bodyPath, with: .linearGradient(sheen, startPoint: CGPoint(x: body.minX, y: 0),
                                                     endPoint: CGPoint(x: body.maxX, y: 0)))
        context.stroke(bodyPath, with: .color(.black.opacity(0.27)), lineWidth: 0.8)

        // Dark tinted windscreen with a curved top.
        var windscreen = Path()
        windscreen.move(to: CGPoint(x: body.minX + 2.5, y: body.minY + 6))
        windscreen.addQuadCurve(to: CGPoint(x: body.maxX - 2.5, y: body.minY + 6),
                                control: CGPoint(x: body.midX, y: body.minY + 2.2))
        windscreen.addLine(to: CGPoint(x: body.maxX - 3, y: body.minY + 11.5))
        windscreen.addQuadCurve(to: CGPoint(x: body.minX + 3, y: body.minY + 11.5),
                                control: CGPoint(x: body.midX, y: body.minY + 10))
        windscreen.closeSubpath()
        context.fill(windscreen, with: .linearGradient(
            Gradient(colors: [Color(red: 70 / 255, green: 70 / 255, blue: 74 / 255),
                              Color(red: 18 / 255, green: 18 / 255, blue: 20 / 255)]),
            startPoint: CGPoint(x: 0, y: body.minY), endPoint: CGPoint(x: 0, y: body.minY + 12)))

        // Side windows as thin dark strips.
        let sideGlass = Color(red: 30 / 255, green: 30 / 255, blue: 32 / 255).opacity(0.59)
        let sideHeight = body.height - 14 - 8
        context.fill(Path(roundedRect: CGRect(x: body.minX + 1.2, y: body.minY + 14, width: 1.4, height: sideHeight), cornerRadius: 0.7),
                     with: .color(sideGlass))
        context.fill(Path(roundedRect: CGRect(x: body.maxX - 2.6, y: body.minY + 14, width: 1.4, height: sideHeight), cornerRadius: 0.7),
                     with: .color(sideGlass))

        // Roof panel with two hatches and an air-con unit in the middle.
        let roof = CGRect(x: body.minX + 4, y: body.minY + 14, width: body.width - 8, height: body.height - 14 - 7)
        context.fill(Path(roundedRect: roof, cornerRadius: 3.5),
                     with: .color(teacher ? Color(red: 48 / 255, green: 48 / 255, blue: 50 / 255) : Color(white: 236 / 255)))
        let detail = teacher ? Color.white.opacity(0.35) : Color.black.opacity(0.18)
        let hatchWidth = roof.width * 0.6
        let hatchX = roof.midX - hatchWidth / 2
        context.fill(Path(roundedRect: CGRect(x: hatchX, y: roof.minY + 4.5, width: hatchWidth, height: 5.5), cornerRadius: 1.5),
                     with: .color(detail))
        context.fill(Path(roundedRect: CGRect(x: hatchX, y: roof.maxY - 10, width: hatchWidth, height: 5.5), cornerRadius: 1.5),
                     with: .color(detail))
        context.fill(Path(roundedRect: CGRect(x: hatchX, y: roof.midY - 3.5, width: hatchWidth, height: 7), cornerRadius: 2),
                     with: .color(detail))

        // Rear window and tail lights.
        context.fill(Path(roundedRect: CGRect(x: body.minX + 5, y: body.maxY - 5, width: body.width - 10, height: 2.4), cornerRadius: 1),
                     with: .color(Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)))
        let tail = Color(red: 214 / 255, green: 48 / 255, blue: 49 / 255)
        context.fill(Path(roundedRect: CGRect(x: body.minX + 1.5, y: body.maxY - 3, width: 2.5, height: 1.8), cornerRadius: 0.8),
                     with: .color(tail))
        context.fill(Path(roundedRect: CGRect(x: body.maxX - 4, y: body.maxY - 3, width: 2.5, height: 1.8), cornerRadius: 0.8),
                     with: .color(tail))

        // Headlights.
        for x in [body.minX + 4, body.maxX - 4] {
            let lamp = Path(ellipseIn: CGRect(x: x - 1.4, y: body.minY + 1, width: 2.8, height: 2.8))
            context.fill(lamp, with: .color(Color(red: 250 / 255, green: 250 / 255, blue: 240 / 255)))
            context.stroke(lamp, with: .color(.black.opacity(0.35)), lineWidth: 0.6)
        }
    }
}

// The same bus seen from the side, nose to the right, with its wheels on the
// road. A straight copy of bus_side.xml from the Android app (120 x 56). The
// road line, under the wheels, sits at roadLine of the drawing's height.
struct BusFromSide: View {
    static let size = CGSize(width: 120, height: 56)
    static let roadLine: CGFloat = 49 / 56
    static let bodyStart: CGFloat = 8 / 120
    static let bodyEnd: CGFloat = 115 / 120

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / Self.size.width, size.height / Self.size.height)
            context.translateBy(x: (size.width - Self.size.width * scale) / 2,
                                y: (size.height - Self.size.height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            Self.draw(in: &context)
        }
        .aspectRatio(Self.size.width / Self.size.height, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private static func gray(_ hex: UInt32, _ alpha: Double = 1) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255).opacity(alpha)
    }

    private static func draw(in context: inout GraphicsContext) {
        // Ground shadow: a round shadow squashed flat.
        var ground = context
        ground.translateBy(x: 0, y: 50)
        ground.scaleBy(x: 1, y: 0.0926)
        ground.translateBy(x: 0, y: -50)
        ground.fill(Path(ellipseIn: CGRect(x: 6, y: -4, width: 108, height: 108)),
                    with: .radialGradient(Gradient(colors: [.black.opacity(0.349), .black.opacity(0)]),
                                          center: CGPoint(x: 60, y: 50), startRadius: 0, endRadius: 54))

        // Body: flat back, rounded roof, slightly raked nose.
        var body = Path()
        body.move(to: CGPoint(x: 8, y: 10))
        body.addQuadCurve(to: CGPoint(x: 12, y: 6), control: CGPoint(x: 8, y: 6))
        body.addLine(to: CGPoint(x: 100, y: 6))
        body.addQuadCurve(to: CGPoint(x: 110, y: 12), control: CGPoint(x: 108, y: 6))
        body.addLine(to: CGPoint(x: 114, y: 34))
        body.addQuadCurve(to: CGPoint(x: 108, y: 42), control: CGPoint(x: 115, y: 42))
        body.addLine(to: CGPoint(x: 12, y: 42))
        body.addQuadCurve(to: CGPoint(x: 8, y: 38), control: CGPoint(x: 8, y: 42))
        body.closeSubpath()
        context.fill(body, with: .linearGradient(
            Gradient(stops: [.init(color: .white, location: 0),
                             .init(color: gray(0xF2F2F2), location: 0.55),
                             .init(color: gray(0xC9C9C9), location: 1)]),
            startPoint: CGPoint(x: 0, y: 6), endPoint: CGPoint(x: 0, y: 42)))
        context.stroke(body, with: .color(.black.opacity(0.278)), lineWidth: 0.8)

        var highlight = Path()
        highlight.move(to: CGPoint(x: 14, y: 8))
        highlight.addLine(to: CGPoint(x: 99, y: 8))
        highlight.addQuadCurve(to: CGPoint(x: 105.5, y: 11), control: CGPoint(x: 104, y: 8))
        highlight.addLine(to: CGPoint(x: 14, y: 11))
        highlight.closeSubpath()
        context.fill(highlight, with: .color(.white.opacity(0.902)))

        // Windows, door and windscreen in dark tinted glass.
        var glass = Path()
        glass.addRect(CGRect(x: 12, y: 13, width: 84, height: 13))
        glass.addRect(CGRect(x: 84, y: 13, width: 10, height: 27))
        glass.move(to: CGPoint(x: 99, y: 13))
        glass.addLine(to: CGPoint(x: 105, y: 13))
        glass.addQuadCurve(to: CGPoint(x: 107.6, y: 15.5), control: CGPoint(x: 107, y: 13))
        glass.addLine(to: CGPoint(x: 110, y: 28))
        glass.addLine(to: CGPoint(x: 99, y: 28))
        glass.closeSubpath()
        context.fill(glass, with: .linearGradient(Gradient(colors: [gray(0x4A4A50), gray(0x121214)]),
                                                  startPoint: CGPoint(x: 0, y: 13), endPoint: CGPoint(x: 0, y: 28)))
        for x in [30, 50, 70] as [CGFloat] {
            context.fill(Path(CGRect(x: x, y: 13, width: 2.2, height: 13)), with: .color(gray(0xF4F4F4)))
        }
        var door = Path()
        door.move(to: CGPoint(x: 89, y: 14))
        door.addLine(to: CGPoint(x: 89, y: 39))
        context.stroke(door, with: .color(gray(0x666666)), lineWidth: 0.6)
        context.fill(Path { p in
            p.addLines([CGPoint(x: 14, y: 14.5), CGPoint(x: 28, y: 14.5), CGPoint(x: 24, y: 19), CGPoint(x: 14, y: 19)])
            p.closeSubpath()
        }, with: .color(.white.opacity(0.18)))
        context.fill(Path { p in
            p.addLines([CGPoint(x: 100, y: 14.5), CGPoint(x: 104, y: 14.5), CGPoint(x: 101.5, y: 20), CGPoint(x: 100, y: 20)])
            p.closeSubpath()
        }, with: .color(.white.opacity(0.25)))

        // Black skirt and the belt line along the side.
        var skirt = Path()
        skirt.move(to: CGPoint(x: 8, y: 36))
        skirt.addLine(to: CGPoint(x: 114.6, y: 36))
        skirt.addQuadCurve(to: CGPoint(x: 108, y: 42), control: CGPoint(x: 114.8, y: 42))
        skirt.addLine(to: CGPoint(x: 12, y: 42))
        skirt.addQuadCurve(to: CGPoint(x: 8, y: 38), control: CGPoint(x: 8, y: 42))
        skirt.closeSubpath()
        context.fill(skirt, with: .color(gray(0x1A1A1A)))
        context.fill(Path(CGRect(x: 8, y: 30, width: 76, height: 1.6)), with: .color(gray(0x1A1A1A, 0.851)))

        // Tail light and headlight.
        context.fill(Path(roundedRect: CGRect(x: 8.2, y: 29, width: 2.6, height: 5), cornerRadius: 0.8),
                     with: .color(gray(0xD63031)))
        let headlight = Path { p in
            p.addLines([CGPoint(x: 110.6, y: 30), CGPoint(x: 113.6, y: 30), CGPoint(x: 114, y: 34), CGPoint(x: 111, y: 34)])
            p.closeSubpath()
        }
        context.fill(headlight, with: .color(gray(0xFFF7DC)))
        context.stroke(headlight, with: .color(.black.opacity(0.302)), lineWidth: 0.5)

        // Wheels.
        for x in [27, 94] as [CGFloat] {
            context.fill(Path(ellipseIn: CGRect(x: x - 7, y: 35, width: 14, height: 14)),
                         with: .linearGradient(Gradient(colors: [gray(0x3A3A3A), gray(0x0E0E0E)]),
                                               startPoint: CGPoint(x: 0, y: 35), endPoint: CGPoint(x: 0, y: 49)))
            context.fill(Path(ellipseIn: CGRect(x: x - 3.2, y: 38.8, width: 6.4, height: 6.4)), with: .color(gray(0xBDBDBD)))
            context.fill(Path(ellipseIn: CGRect(x: x - 1.2, y: 40.8, width: 2.4, height: 2.4)), with: .color(gray(0x555555)))
        }
    }
}

// How the bus looks on the trip bar, picked in Settings > Appearance. Kept in
// the App Group so the widgets and the Live Activity draw the same bus.
enum BusStyle: String, CaseIterable, Identifiable {
    case above
    case side

    static let storageKey = "busStyle"

    var id: String { rawValue }

    static var current: BusStyle {
        BusStyle(rawValue: SharedStore.defaults.string(forKey: storageKey) ?? "") ?? .above
    }

    var title: String {
        switch self {
        case .above: return String(localized: "From above")
        case .side: return String(localized: "From the side")
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        BusFromAbove().frame(width: 140)
        BusFromAbove(teacher: true).frame(width: 140)
        BusFromAbove().frame(width: 36)
        BusFromSide().frame(width: 120)
        BusFromSide().frame(width: 40)
    }
    .padding()
}

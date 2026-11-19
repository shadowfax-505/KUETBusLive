//
//  WidgetTheme.swift
//  KUETBusWidget
//
//  Created by Muttakin Rahman Shoscho.
//
//  The colours and type of the widgets and the Live Activity, in one place.
//  The font itself is the rider's pick (Shared/WidgetFont.swift).
//  Classic is black and white, like the app: white with near-black text in light
//  mode, #1C1C1E with white text in dark mode. The rider can pick a colour instead
//  (Shared/WidgetColour.swift). Colour is kept for status only
//  (green for seats and on time, amber filling up, red full or late).
//

import SwiftUI
import UIKit

enum WidgetTheme {

    // MARK: Raw colours

    static let nearBlack = UIColor(hex: 0x111111)
    static let darkSurface = UIColor(hex: 0x1C1C1E)
    static let darkRaised = UIColor(hex: 0x2C2C2E)
    static let lightRaised = UIColor(hex: 0xF2F2F7)

    // MARK: Colours that follow light and dark mode, in the rider's widget colour

    private static var colour: WidgetColour { WidgetColour.current }
    private static var classic: Bool { colour == .classic }

    static var backgroundTop: Color { colour.top }
    static var backgroundBottom: Color { colour.bottom }
    static var primary: Color { colour.primary }
    static var secondary: Color { colour.secondary }
    // Emphasis is the text colour: there is no separate accent colour.
    static var accent: Color { primary }
    static var track: Color {
        classic ? Color(light: nearBlack.withAlphaComponent(0.10), dark: UIColor.white.withAlphaComponent(0.14))
                : primary.opacity(0.28)
    }
    static var hairline: Color {
        classic ? Color(light: nearBlack.withAlphaComponent(0.08), dark: UIColor.white.withAlphaComponent(0.08))
                : primary.opacity(0.2)
    }
    // Small dots for the stops along the track.
    static var stopRing: Color {
        classic ? Color(light: nearBlack.withAlphaComponent(0.45), dark: .white) : primary
    }

    // MARK: Status

    static let sage = Color(UIColor(hex: 0x30A46C))         // on time, seats free
    static let amber = Color(UIColor(hex: 0xF5A524))        // filling up
    static let terracotta = Color(UIColor(hex: 0xE5484D))   // full, late, no signal

    static func crowdColor(_ crowd: String) -> Color {
        switch crowd {
        case "seats": return sage
        case "full": return terracotta
        default: return secondary
        }
    }

    // MARK: Backgrounds

    static var background: some View {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
    }

    // The Live Activity is always dark, whatever the phone's appearance.
    enum Night {
        static let background = Color(nearBlack)
        static let primary = Color.white
        static let secondary = Color.white.opacity(0.6)
        static let accent = Color.white
        static let track = Color.white.opacity(0.14)
        static let stopRing = Color.white
    }
}

// MARK: - Logo

// The KUET bus and pin from the app icon, in one colour, so it takes the tint and
// the accented and vibrant widget modes like an SF Symbol does.
struct KUETMark: View {
    var height: CGFloat = 13

    var body: some View {
        Image("LogoMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: height)
    }
}

// MARK: - Type
// The font comes from the rider's pick in Settings > Appearance (WidgetFont).

extension View {
    // Small uppercase labels such as "NEXT BUS" and "ARRIVING IN".
    func widgetLabel(_ color: Color = WidgetTheme.secondary) -> some View {
        let font = WidgetFont.current
        return self.font(font.label())
            .tracking(font.labelTracking)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    // Bus and trip names.
    func widgetTitle(_ style: Font.TextStyle) -> some View {
        let font = WidgetFont.current
        return self.font(font.title(style))
            .textCase(font.titleCase)
    }
}

extension Font {
    // Big numbers: minutes, times and distances.
    static func widgetNumber(size: CGFloat) -> Font {
        WidgetFont.current.number(size: size)
    }
}

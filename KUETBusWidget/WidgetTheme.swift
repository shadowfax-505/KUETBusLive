//
//  WidgetTheme.swift
//  KUETBusWidget
//
//  Created by Muttakin Rahman Shoscho.
//
//  The colours and type of the widgets and the Live Activity, in one place.
//  The font itself is the rider's pick (Shared/WidgetFont.swift).
//  Black and white, like the app: white with near-black text in light mode,
//  #1C1C1E with white text in dark mode. Colour is kept for status only
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

    // MARK: Colours that follow light and dark mode

    static let backgroundTop = Color(light: .white, dark: darkSurface)
    static let backgroundBottom = Color(light: lightRaised, dark: darkSurface)
    static let primary = Color(light: nearBlack, dark: .white)
    static let secondary = Color(light: nearBlack.withAlphaComponent(0.55), dark: UIColor.white.withAlphaComponent(0.6))
    // Emphasis is black (white in dark mode): there is no separate accent colour.
    static let accent = primary
    static let track = Color(light: nearBlack.withAlphaComponent(0.10), dark: UIColor.white.withAlphaComponent(0.14))
    static let hairline = Color(light: nearBlack.withAlphaComponent(0.08), dark: UIColor.white.withAlphaComponent(0.08))
    // Small dots for the stops along the track.
    static let stopRing = Color(light: nearBlack.withAlphaComponent(0.45), dark: .white)

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

// MARK: - Helpers

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    // A colour that picks its light or dark version from the view's appearance.
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

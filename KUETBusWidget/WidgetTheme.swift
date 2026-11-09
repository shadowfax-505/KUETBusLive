//
//  WidgetTheme.swift
//  KUETBusWidget
//
//  Created by Muttakin Rahman Shoscho.
//
//  The colours and type of the widgets and the Live Activity, in one place.
//  Dark: deep ink navy with ivory text and a brushed brass accent.
//  Light: warm ivory paper with ink text and a deeper brass.
//  Status colours are muted on purpose (sage, amber, terracotta) so they
//  sit quietly next to the brass instead of shouting like traffic lights.
//

import SwiftUI
import UIKit

enum WidgetTheme {

    // MARK: Raw colours

    static let inkNavy = UIColor(hex: 0x0B1622)
    static let inkNavyLight = UIColor(hex: 0x13263A)
    static let ivory = UIColor(hex: 0xF3EEE4)
    static let paper = UIColor(hex: 0xF6F1E7)
    static let paperDeep = UIColor(hex: 0xEFE7D8)
    static let ink = UIColor(hex: 0x14202C)
    static let brass = UIColor(hex: 0xC8A45D)
    static let brassDeep = UIColor(hex: 0xA8823A)

    // MARK: Colours that follow light and dark mode

    static let backgroundTop = Color(light: paper, dark: inkNavy)
    static let backgroundBottom = Color(light: paperDeep, dark: inkNavyLight)
    static let primary = Color(light: ink, dark: ivory)
    static let secondary = Color(light: ink.withAlphaComponent(0.55), dark: ivory.withAlphaComponent(0.6))
    static let accent = Color(light: brassDeep, dark: brass)
    static let track = Color(light: ink.withAlphaComponent(0.10), dark: UIColor.white.withAlphaComponent(0.12))
    static let hairline = Color(light: ink.withAlphaComponent(0.08), dark: UIColor.white.withAlphaComponent(0.08))
    // Small rings for the stops along the track: ivory on ink, soft ink on paper.
    static let stopRing = Color(light: ink.withAlphaComponent(0.45), dark: ivory)
    // The bus symbol inside the brass circle.
    static let busGlyph = Color(inkNavy)

    // MARK: Status

    static let sage = Color(UIColor(hex: 0x7FA88A))         // on time, seats free
    static let amber = Color(UIColor(hex: 0xD9A55B))        // filling up
    static let terracotta = Color(UIColor(hex: 0xC46A5A))   // full, late, no signal

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

    // The Live Activity is always ink, whatever the phone's appearance.
    enum Night {
        static let background = Color(inkNavy)
        static let primary = Color(ivory)
        static let secondary = Color(ivory.withAlphaComponent(0.6))
        static let accent = Color(brass)
        static let track = Color.white.opacity(0.12)
        static let stopRing = Color(ivory)
    }
}

// MARK: - Type

extension View {
    // Small uppercase labels such as "NEXT BUS" and "ARRIVING IN".
    func widgetLabel(_ color: Color = WidgetTheme.secondary) -> some View {
        self.font(.caption2.weight(.semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

extension Font {
    // Bus names and big numbers, in New York.
    static func widgetSerif(_ style: Font.TextStyle) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }

    static func widgetSerif(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
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

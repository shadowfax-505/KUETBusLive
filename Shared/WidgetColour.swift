//
//  WidgetColour.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The colour of the home screen widget, picked in Settings > Appearance and kept
//  in the App Group so the widget reads the same choice. Classic is black and white
//  like the app. The others fill the widget with one colour running top to bottom,
//  a little lighter at the top, as Apple's own widgets do. Each has a light and a
//  dark version that follow the phone.
//

import SwiftUI
import UIKit

enum WidgetColour: String, CaseIterable, Identifiable {
    case classic
    case forest
    case violet
    case butter

    static let storageKey = "widgetColour"

    var id: String { rawValue }

    static var current: WidgetColour {
        WidgetColour(rawValue: SharedStore.defaults.string(forKey: storageKey) ?? "") ?? .classic
    }

    var title: String {
        switch self {
        case .classic: return String(localized: "Classic")
        case .forest: return String(localized: "Forest green")
        case .violet: return String(localized: "Violet")
        case .butter: return String(localized: "Butter cream")
        }
    }

    // MARK: Colours (light, dark)

    var top: Color {
        switch self {
        case .classic: return Color(light: .white, dark: UIColor(hex: 0x1C1C1E))
        case .forest: return Color(light: UIColor(hex: 0x347F45), dark: UIColor(hex: 0x22542E))
        case .violet: return Color(light: UIColor(hex: 0x715CDB), dark: UIColor(hex: 0x37239D))
        case .butter: return Color(light: UIColor(hex: 0xFEF2DC), dark: UIColor(hex: 0x6A4C29))
        }
    }

    var bottom: Color {
        switch self {
        case .classic: return Color(light: UIColor(hex: 0xF2F2F7), dark: UIColor(hex: 0x1C1C1E))
        case .forest: return Color(light: UIColor(hex: 0x295B3C), dark: UIColor(hex: 0x173221))
        case .violet: return Color(light: UIColor(hex: 0x673BCE), dark: UIColor(hex: 0x371D75))
        case .butter: return Color(light: UIColor(hex: 0xFCEAB1), dark: UIColor(hex: 0x473A1F))
        }
    }

    // Text, the minutes, the ring and the track.
    var primary: Color {
        switch self {
        case .classic: return Color(light: UIColor(hex: 0x111111), dark: .white)
        case .forest: return Color(light: UIColor(hex: 0xFFF6DA), dark: UIColor(hex: 0xFFF6DA))
        case .violet: return Color(light: .white, dark: .white)
        case .butter: return Color(light: UIColor(hex: 0x3A2E0A), dark: UIColor(hex: 0xFFF6DA))
        }
    }

    // Labels and notes.
    var secondary: Color {
        switch self {
        case .classic:
            return Color(light: UIColor(hex: 0x111111, alpha: 0.55), dark: UIColor.white.withAlphaComponent(0.6))
        case .butter:
            return Color(light: UIColor(hex: 0x3A2E0A, alpha: 0.62), dark: UIColor.white.withAlphaComponent(0.7))
        case .forest, .violet:
            return Color(light: UIColor.white.withAlphaComponent(0.78), dark: UIColor.white.withAlphaComponent(0.7))
        }
    }

    var background: LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
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

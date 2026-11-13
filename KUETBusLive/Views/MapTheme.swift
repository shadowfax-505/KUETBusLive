//
//  MapTheme.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The app's colours: black and white, like a ride-hailing app.
//  Light: white surfaces, near-black text, lines and buttons.
//  Dark: #1C1C1E surfaces, white text and lines, light grey buttons.
//  Colour is kept for meaning only: crowd, signal, who may ride, tail-lights.
//

import SwiftUI
import UIKit

enum MapTheme {
    static let nearBlack = rgb(0x111111)
    static let darkSurface = rgb(0x1C1C1E)
    static let darkRaised = rgb(0x2C2C2E)
    static let lightGrey = rgb(0xE5E5EA)

    // Text and lines that sit on the map or on a card.
    static let primary = adaptive(light: nearBlack, dark: .white)
    // There is no separate accent colour any more: emphasis is black (white in dark mode).
    static let accent = primary
    // Cards, pills and the bottom sheet.
    static let surface = adaptive(light: .white, dark: darkSurface)
    static let raised = adaptive(light: rgb(0xF2F2F7), dark: darkRaised)

    // The main button: solid near-black with white text, or light grey with black text in dark mode.
    static let buttonFill = adaptive(light: nearBlack, dark: lightGrey)
    static let buttonText = adaptive(light: .white, dark: nearBlack)
    static let inkButton = buttonFill

    // The bus: glossy white in both modes, with a soft shadow and red tail-lights.
    static let busBody = Color.white
    static let busShine = Color(rgb(0xDADDE2))
    static let busOutline = Color(rgb(0xC7CBD1))
    static let busGlass = Color(rgb(0x2B2F36))
    static let tailLight = Color(rgb(0xE5484D))

    // The route: one solid line, black on a light map and white on a dark one.
    static let routeLine = primary
    // The rest of the route, behind the bus: the same line, faded.
    static let route = adaptive(light: nearBlack.withAlphaComponent(0.28), dark: UIColor.white.withAlphaComponent(0.3))
    static let stopFill = surface

    static let sage = Color(rgb(0x30A46C))
    static let terracotta = Color(rgb(0xE5484D))

    static func crowd(_ level: CrowdLevel) -> Color {
        switch level {
        case .seats: return sage
        case .full: return terracotta
        case .unknown: return .gray
        }
    }

    private static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

// The solid full-width main button of a sheet or card.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(MapTheme.buttonText)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(MapTheme.buttonFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// A round white button that floats on the map (back, recenter).
struct MapRoundButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(MapTheme.primary)
            .frame(width: 44, height: 44)
            .background(MapTheme.surface, in: Circle())
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

extension View {
    // A white capsule on the map (dark in dark mode) with a soft shadow.
    func mapPill() -> some View {
        self.padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(MapTheme.surface, in: Capsule())
            .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
    }
}

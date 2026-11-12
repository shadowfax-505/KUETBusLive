//
//  MapTheme.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The live map's colours: the same ink navy, ivory and brass as the widgets,
//  with muted status colours. Each colour has a light and a dark version.
//

import SwiftUI
import UIKit

enum MapTheme {
    static let inkNavy = rgb(0x0B1622)
    static let inkNavyLight = rgb(0x13263A)
    static let ivory = rgb(0xF3EEE4)
    static let ink = rgb(0x14202C)
    static let brass = rgb(0xC8A45D)
    static let brassDeep = rgb(0xA8823A)

    // Text and lines that sit on the map.
    static let primary = adaptive(light: ink, dark: ivory)
    static let accent = adaptive(light: brassDeep, dark: brass)
    // The bus body: ivory on a light map, deep navy on a dark one.
    static let busBody = adaptive(light: ivory, dark: inkNavyLight)
    static let busOutline = adaptive(light: ink, dark: ivory.withAlphaComponent(0.85))
    static let busGlass = adaptive(light: inkNavy, dark: ivory.withAlphaComponent(0.25))
    // The faint full route and the stops on it.
    static let route = adaptive(light: ink.withAlphaComponent(0.35), dark: ivory.withAlphaComponent(0.35))
    static let stopFill = adaptive(light: ivory, dark: inkNavy)

    static let sage = Color(rgb(0x7FA88A))
    static let terracotta = Color(rgb(0xC46A5A))

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

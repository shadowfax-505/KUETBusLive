//
//  AppIconChoice.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The home screen icons a rider can pick in Settings > Appearance. Black is
//  the main icon; the others are alternate icons listed in the build settings
//  (ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES). The same four exist on Android.
//

import UIKit

enum AppIconChoice: String, CaseIterable, Identifiable {
    case black, white, colour, pin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .black: return String(localized: "Black")
        case .white: return String(localized: "White")
        case .colour: return String(localized: "Colour")
        case .pin: return String(localized: "Pin")
        }
    }

    // Name of the alternate icon set, or nil for the main icon.
    var iconName: String? {
        switch self {
        case .black: return nil
        case .white: return "AppIcon-White"
        case .colour: return "AppIcon-Colour"
        case .pin: return "AppIcon-Pin"
        }
    }

    // Small copy of the icon to show in the picker.
    var previewImage: String {
        switch self {
        case .black: return "AppIconPreview-Black"
        case .white: return "AppIconPreview-White"
        case .colour: return "AppIconPreview-Colour"
        case .pin: return "AppIconPreview-Pin"
        }
    }

    @MainActor
    static var current: AppIconChoice {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.iconName == name } ?? .black
    }

    @MainActor
    func apply() async throws {
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != iconName else { return }
        try await UIApplication.shared.setAlternateIconName(iconName)
    }
}

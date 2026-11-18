//
//  WidgetFont.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The type on the home screen widget and the Live Activity, picked in
//  Settings > Appearance. Kept in the App Group so the widget reads the same choice.
//  The font files are in Shared/Fonts (trimmed to Latin; Bangla falls back to the
//  system font) and are registered at launch by both the app and the widget.
//

import SwiftUI
import CoreText

enum WidgetFont: String, CaseIterable, Identifiable {
    case board        // condensed capitals like a station departure board
    case grotesk      // a modern geometric sans
    case timetable    // a serif name with monospaced numbers, like a printed timetable

    static let storageKey = "widgetFont"

    var id: String { rawValue }

    static var current: WidgetFont {
        WidgetFont(rawValue: SharedStore.defaults.string(forKey: storageKey) ?? "") ?? .board
    }

    var title: String {
        switch self {
        case .board: return String(localized: "Departure board")
        case .grotesk: return String(localized: "Grotesk")
        case .timetable: return String(localized: "Timetable")
        }
    }

    // MARK: Faces (PostScript names of the files in Shared/Fonts)

    private var labelFace: String {
        switch self {
        case .board: return "BarlowCondensed-Medium"
        case .grotesk: return "SpaceGroteskLight-Medium"
        case .timetable: return "JetBrainsMono-Medium"
        }
    }

    private var titleFace: String {
        switch self {
        case .board: return "BarlowCondensed-Bold"
        case .grotesk: return "SpaceGroteskLight-Bold"
        case .timetable: return "Fraunces-SemiBold"
        }
    }

    private var numberFace: String {
        switch self {
        case .board: return "BarlowCondensed-Bold"
        case .grotesk: return "SpaceGroteskLight-Bold"
        case .timetable: return "JetBrainsMono-Bold"
        }
    }

    // The condensed board face runs small, so it is set a little larger.
    private var scale: CGFloat {
        switch self {
        case .board: return 1.2
        case .grotesk: return 1
        case .timetable: return 0.95
        }
    }

    // Board titles are in capitals, like a station board.
    var titleCase: Text.Case? { self == .board ? .uppercase : nil }

    var labelTracking: CGFloat {
        switch self {
        case .board: return 1.8
        case .grotesk: return 1.1
        case .timetable: return 0.3
        }
    }

    // MARK: Fonts

    func label(size: CGFloat = 11) -> Font {
        .custom(labelFace, size: size * (self == .board ? 1.15 : 1), relativeTo: .caption2)
    }

    func title(_ style: Font.TextStyle) -> Font {
        .custom(titleFace, size: Self.pointSize(style) * scale, relativeTo: style)
    }

    func number(size: CGFloat) -> Font {
        .custom(numberFace, size: size * scale, relativeTo: .title)
    }

    private static func pointSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline, .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        default: return 11
        }
    }

    // MARK: Registering

    // Makes the bundled fonts usable by name in this process. Safe to call more than once.
    static func registerFonts() {
        _ = registerOnce
    }

    private static let registerOnce: Void = {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()
}

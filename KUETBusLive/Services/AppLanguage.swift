//
//  AppLanguage.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The app's own language setting: English, Bangla, or the phone's language.
//  It changes the app at once, without leaving it:
//    1. Bundle.main is switched to a subclass that looks text up in the chosen
//       language's folder (en.lproj or bn.lproj) instead of the phone's language.
//       Everything that reads text from the bundle then gets the chosen language.
//    2. The root view gets the chosen locale and is rebuilt, so every screen
//       draws again in the new language.
//    3. The choice is also saved as the app's AppleLanguages, so iOS starts the
//       app (and its system screens such as the photo picker) in it next time.
//

import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", bangla = "bn"

    static let storageKey = "appLanguage"

    var id: String { rawValue }

    // Each name is written in its own language, so anyone can find theirs.
    var title: String {
        switch self {
        case .system: return String(localized: "Same as iPhone")
        case .english: return "English"
        case .bangla: return "বাংলা"
        }
    }

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    // The language code text is shown in right now: the setting, or the phone's choice.
    var resolvedCode: String {
        switch self {
        case .system:
            let phone = Bundle.preferredLocalizations(from: Bundle.main.localizations
                                                      .filter { $0 != "Base" }).first ?? "en"
            return phone.hasPrefix("bn") ? "bn" : "en"
        default:
            return rawValue
        }
    }

    var locale: Locale {
        self == .system ? .autoupdatingCurrent : Locale(identifier: rawValue)
    }

    // Called at launch and whenever the setting changes.
    func apply() {
        LanguageBundle.use(self == .system ? nil : rawValue)
        if self == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
    }
}

// Bundle.main, but with text taken from one language's folder when one is chosen.
final class LanguageBundle: Bundle, @unchecked Sendable {
    private static var chosen: Bundle?

    static func use(_ code: String?) {
        if object_getClass(Bundle.main) != LanguageBundle.self {
            object_setClass(Bundle.main, LanguageBundle.self)
        }
        chosen = code.flatMap { Bundle.main.path(forResource: $0, ofType: "lproj") }.flatMap(Bundle.init(path:))
    }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let chosen = Self.chosen {
            return chosen.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }

    // String(localized:) asks with the phone's language list; answer from the chosen folder.
    @available(iOS 18.4, *)
    override func __localizedString(forKey key: String, value: String?, table tableName: String?,
                                    localizations: [String]) -> String {
        if let chosen = Self.chosen {
            return chosen.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.__localizedString(forKey: key, value: value, table: tableName, localizations: localizations)
    }

    // Newer iOS versions look strings up through these two selectors instead, so
    // String(localized:) would keep the old language until a restart without them.
    @objc(_localizedStringForKey:value:table:localizations:)
    func chosenString(forKey key: String, value: String?, table tableName: String?,
                      localizations: [String]?) -> String {
        if let chosen = Self.chosen {
            return chosen.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }

    @objc(localizedStringForKey:value:table:localization:)
    func chosenString(forKey key: String, value: String?, table tableName: String?,
                      localization: String?) -> String {
        if let chosen = Self.chosen {
            return chosen.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }

    override var preferredLocalizations: [String] {
        if let code = Self.chosen?.bundleURL.deletingPathExtension().lastPathComponent {
            return [code]
        }
        return super.preferredLocalizations
    }
}

// Light, dark, or following the phone.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appAppearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return String(localized: "Same as iPhone")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

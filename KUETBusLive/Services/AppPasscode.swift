//
//  AppPasscode.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The optional 4-digit app passcode. Only a SHA-256 hash of it is kept, and
//  it lives in the iOS Keychain (not UserDefaults), so it never sits on the
//  phone as plain text.
//

import Foundation
import Security
import CryptoKit

struct AppPasscode {
    static let length = 4
    private static let account = "KUETBusLive.appPasscode"

    static var isSet: Bool {
        readHash() != nil
    }

    // "1234" -> "03ac67...". The same code always gives the same hash.
    static func hash(_ code: String) -> String {
        SHA256.hash(data: Data(code.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func check(_ code: String) -> Bool {
        readHash() == hash(code)
    }

    @discardableResult
    static func save(_ code: String) -> Bool {
        remove()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(hash(code).utf8),
            // Only readable on this phone, and only while it's unlocked.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func remove() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func readHash() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

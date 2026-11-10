//
//  AccountDeletion.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The rules for Profile > Delete account, kept apart from Firebase so they can be unit tested.
//  The deleting itself is done by AuthViewModel.deleteAccount(password:).
//

import Foundation

enum AccountDeletion {

    // Returns a message when this account may not be deleted, otherwise nil.
    // The transport office must always have at least one admin to approve people.
    static func blockReason(role: UserRole, adminCount: Int) -> String? {
        guard role == .admin, adminCount <= 1 else { return nil }
        return String(localized: "You are the only transport admin. Make another account an admin in the Firebase console before deleting this one.")
    }

    // What the confirmation alert tells the person before they type their password.
    static func explanation(role: UserRole, isOnTrip: Bool) -> String {
        var text = String(localized: "This permanently deletes your profile (name, email, KUET ID and favourite stop), your places, your complaints, your push token and your login, and clears the app's settings on this phone. It cannot be undone.")
        if role == .driver {
            text += " " + (isOnTrip
                ? String(localized: "Your running trip will be ended first.")
                : String(localized: "Any bus you left on the map is removed too."))
        }
        text += "\n\n" + String(localized: "Enter your password to confirm.")
        return text
    }

    // Keys this app keeps in UserDefaults.standard: lock switches, alert settings,
    // read announcements and the push topic.
    static let localSettingKeys = [
        "faceIDOn",
        "passcodeOn",
        "arrivalAlertOn",
        NotificationManager.alertMinutesKey,
        AnnouncementViewModel.lastSeenKey,
        AnnouncementViewModel.showNewsKey,
        PushManager.topicKey,
        PlacesViewModel.boardingPlaceKey,
        BusViewModel.wavingAtKey,
        BusViewModel.wavingUntilKey,
        RideHistory.suggestionsOnKey,
        RideHistory.backupOnKey
    ]

    // Forgets everything this phone saved for the account. Works on any UserDefaults,
    // so a test can pass in its own.
    static func clearLocalSettings(in defaults: UserDefaults) {
        for key in localSettingKeys {
            defaults.removeObject(forKey: key)
        }
    }
}

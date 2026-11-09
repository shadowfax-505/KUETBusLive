//
//  NotificationManager.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Local notifications. As the UNUserNotificationCenterDelegate it can show the
//  alert as a banner even while the app is open.
//

import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    // Each rider picks how early they want the alert (Profile > Notifications).
    static let alertMinutesKey = "arrivalAlertMinutes"
    static let defaultAlertMinutes = 5
    static let alertMinutesRange = 1...30

    static var alertMinutes: Int {
        let saved = UserDefaults.standard.integer(forKey: alertMinutesKey)
        return alertMinutesRange.contains(saved) ? saved : defaultAlertMinutes
    }

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
            print("Notifications allowed: \(granted)")
        }
    }

    func sendArrivalAlert(busNumber: String, stopName: String, minutes: Int) {
        let content = UNMutableNotificationContent()
        // Place names in Bangla when the app is in Bangla, e.g. "Normal-2 · রূপসা".
        let bus = PlaceNames.display(busNumber)
        let stop = PlaceNames.display(stopName)
        content.title = String(localized: "\(bus) is almost here")
        content.body = String(localized: "About \(minutes) min to \(stop).")
        content.sound = .default

        // trigger nil means show it right away.
        let request = UNNotificationRequest(identifier: "arrival-\(busNumber)",
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

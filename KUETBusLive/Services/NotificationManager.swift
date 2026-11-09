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
    static let alertMinutes = 5

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
        content.title = "\(busNumber) is almost here"
        content.body = "About \(minutes) min to \(stopName)."
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

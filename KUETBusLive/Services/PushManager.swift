//
//  PushManager.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Server push with Firebase Cloud Messaging (FCM).
//  1. iOS gives the app an APNs device token; it is handed to Firebase.
//  2. Firebase turns it into an FCM token, which is saved on the user's profile.
//  3. Each rider subscribes to a "topic" for their route, e.g. "route-AbC123".
//  4. When a driver starts a trip, a Cloud Function (functions/index.js) sends
//     "Normal-2 just left campus" to that route's topic, so every rider on the
//     route gets it, even with the app closed.
//
//  This only works once the Cloud Function is deployed and an APNs key is
//  uploaded to Firebase (see "Server push" in the README).
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

class PushManager: NSObject, MessagingDelegate {
    static let shared = PushManager()

    static let topicKey = "pushRouteTopic"
    private(set) var fcmToken: String?

    private override init() {
        super.init()
    }

    // Called once at launch from the app delegate.
    func start() {
        Messaging.messaging().delegate = self
        // Asks iOS for an APNs token. This shows no pop-up; the alert permission
        // is asked separately (Profile > Alert me before my bus arrives).
        UIApplication.shared.registerForRemoteNotifications()
    }

    // The topic name for a route. Topic names may only use letters, digits and - _ . ~ %
    static func topic(forRouteId routeId: String) -> String {
        "route-\(routeId)"
    }

    // Teachers' buses are announced on their own topic, which only teachers join,
    // because students may not ride them (see functions/index.js).
    static func topics(forRouteId routeId: String, role: UserRole) -> [String] {
        let topic = topic(forRouteId: routeId)
        return role == .teacher ? [topic, topic + "-teachers"] : [topic]
    }

    // Moves the rider to their route's topics, leaving the old ones. They are saved
    // as one string, "route-r1" or "route-r1,route-r1-teachers".
    func subscribe(toRouteId routeId: String?, role: UserRole = .student) {
        let old = UserDefaults.standard.string(forKey: Self.topicKey)
        let newTopics = routeId.map { Self.topics(forRouteId: $0, role: role) } ?? []
        let new = newTopics.isEmpty ? nil : newTopics.joined(separator: ",")
        guard old != new else { return }

        for topic in Self.split(old) {
            Messaging.messaging().unsubscribe(fromTopic: topic)
        }
        for topic in newTopics {
            Messaging.messaging().subscribe(toTopic: topic) { error in
                if let error = error {
                    print("Could not subscribe to \(topic): \(error)")
                }
            }
        }
        UserDefaults.standard.set(new, forKey: Self.topicKey)
    }

    private static func split(_ saved: String?) -> [String] {
        saved?.split(separator: ",").map(String.init) ?? []
    }

    // Update: saves the FCM token on the signed-in user's profile, so the
    // server could also message one person directly.
    func saveTokenForCurrentUser() {
        guard let token = fcmToken, let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid).updateData(["fcmToken": token]) { error in
            if let error = error {
                print("Could not save FCM token: \(error)")
            }
        }
    }

    // Before signing out: leave the route topic and take the token off the profile.
    // The write goes first, while the account is still signed in; if the phone is
    // offline it waits in Firestore's queue and is sent next time this account signs in.
    func leaveAccount() {
        for topic in Self.split(UserDefaults.standard.string(forKey: Self.topicKey)) {
            Messaging.messaging().unsubscribe(fromTopic: topic)
        }
        UserDefaults.standard.removeObject(forKey: Self.topicKey)
        guard let uid = Auth.auth().currentUser?.uid, fcmToken != nil else { return }
        Firestore.firestore().collection("users").document(uid)
            .updateData(["fcmToken": FieldValue.delete()])
    }

    // After the account is deleted: leave the route topic and throw the push token away,
    // so this phone gets no more notifications for that account.
    func forgetDevice() {
        for topic in Self.split(UserDefaults.standard.string(forKey: Self.topicKey)) {
            Messaging.messaging().unsubscribe(fromTopic: topic)
        }
        UserDefaults.standard.removeObject(forKey: Self.topicKey)
        fcmToken = nil
        Messaging.messaging().deleteToken { error in
            if let error = error {
                print("Could not delete FCM token: \(error)")
            }
        }
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        self.fcmToken = fcmToken
        saveTokenForCurrentUser()
    }
}

// SwiftUI apps have no AppDelegate by default. This small one receives the APNs
// device token from iOS and passes it on to Firebase.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        PushManager.shared.start()
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Expected in the simulator or without the Push Notifications capability.
        print("Push registration failed: \(error.localizedDescription)")
    }
}

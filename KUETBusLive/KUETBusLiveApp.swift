//
//  KUETBusLiveApp.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import SwiftUI
import FirebaseCore

@main
struct KUETBusLiveApp: App {
    // StateObject is created lazily, so FirebaseApp.configure() in init runs first.
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        FirebaseApp.configure()
        // Creating the shared manager makes it the notification delegate from launch.
        _ = NotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}

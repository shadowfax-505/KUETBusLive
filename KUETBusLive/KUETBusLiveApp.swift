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
    @State private var showSplash = true

    init() {
        FirebaseApp.configure()
        // Creating the shared manager makes it the notification delegate from launch.
        _ = NotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(authViewModel)

                if showSplash {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.4)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }
}

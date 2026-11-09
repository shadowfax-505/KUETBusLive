//
//  KUETBusLiveApp.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@main
struct KUETBusLiveApp: App {
    // Receives the push notification token from iOS (see PushManager).
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // StateObject is created lazily, so FirebaseApp.configure() in init runs first.
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showSplash = true

    init() {
        FirebaseApp.configure()
        Self.useLocalEmulatorsIfAsked()
        // Creating the shared manager makes it the notification delegate from launch.
        _ = NotificationManager.shared
    }

    // Debug builds only: launched with USE_FIREBASE_EMULATORS=1, the app talks to the
    // Auth and Firestore emulators on this Mac (firebase emulators:start) instead of
    // the real project, so sign-up and account deletion can be tried without touching real data.
    private static func useLocalEmulatorsIfAsked() {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["USE_FIREBASE_EMULATORS"] == "1" else { return }
        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
        let settings = Firestore.firestore().settings
        settings.host = "127.0.0.1:8080"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
        print("Using the local Firebase emulators")
        #endif
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

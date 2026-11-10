//
//  ContentView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Root of the app: chooses which screen to show based on sign-in state,
//  verification, approval and role. If Face ID or an app passcode is on,
//  the app locks every time it goes to the background.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    // Shared by every signed-in screen: the announcements list, its unread badge and the banner.
    @StateObject private var announcementViewModel = AnnouncementViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("faceIDOn") private var faceIDOn = false
    @AppStorage("passcodeOn") private var passcodeOn = false
    @State private var isUnlocked = false

    // A name for the current screen, so changes between screens can animate.
    var screenName: String {
        guard authViewModel.isSignedIn else { return "login" }
        guard let profile = authViewModel.profile else { return "loading" }
        if authViewModel.mustVerifyEmail { return "verify" }
        if !profile.isActive { return "inactive" }
        if profile.needsApproval && !profile.approved { return "waiting" }
        return profile.role.rawValue
    }

    var isLocked: Bool {
        (faceIDOn || passcodeOn) && authViewModel.isSignedIn && !isUnlocked
    }

    var body: some View {
        ZStack {
            screen
                .environmentObject(announcementViewModel)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .id(screenName)

            if isLocked {
                AppLockView {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isUnlocked = true
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: screenName)
        // Turning a lock on in Profile shouldn't lock the screen you're looking at.
        .onChange(of: faceIDOn || passcodeOn) { _, lockOn in
            if lockOn && scenePhase == .active {
                isUnlocked = true
            }
        }
        // Listen to announcements only while someone is signed in (the rules require it).
        .onAppear {
            if authViewModel.isSignedIn {
                announcementViewModel.startListening()
            }
        }
        .onChange(of: authViewModel.isSignedIn) { _, signedIn in
            if signedIn {
                announcementViewModel.startListening()
            } else {
                announcementViewModel.stopListening()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Lock again whenever the app leaves the screen.
            if newPhase == .background {
                isUnlocked = false
            }
        }
    }

    @ViewBuilder
    var screen: some View {
        if !authViewModel.isSignedIn {
            LoginView()
        } else if let profile = authViewModel.profile {
            if !profile.isActive {
                // A driver who left the job: the admin turned the account off.
                ContentUnavailableView {
                    Label("Your account is no longer active", systemImage: "person.crop.circle.badge.xmark")
                } description: {
                    Text("Contact the KUET transport office if you think this is a mistake.")
                } actions: {
                    Button("Sign Out") {
                        authViewModel.signOut()
                    }
                }
            } else if authViewModel.mustVerifyEmail {
                VerifyEmailView()
            } else if profile.needsApproval && !profile.approved {
                PendingApprovalView()
            } else {
                switch profile.role {
                case .student, .teacher:
                    StudentTabView()
                case .driver:
                    DriverHomeView()
                case .admin:
                    AdminTabView()
                }
            }
        } else {
            VStack(spacing: 16) {
                ProgressView("Loading profile...")
                Button("Sign Out") {
                    authViewModel.signOut()
                }
            }
        }
    }
}

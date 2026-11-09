//
//  ContentView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Root of the app: chooses which screen to show based on sign-in state,
//  verification, approval and role.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        if !authViewModel.isSignedIn {
            LoginView()
        } else if let profile = authViewModel.profile {
            if authViewModel.mustVerifyEmail {
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

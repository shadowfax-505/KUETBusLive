//
//  PendingApprovalView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Teachers and drivers wait here until the transport admin checks their KUET ID.
//  The profile listener moves them on as soon as they are approved.
//

import SwiftUI

struct PendingApprovalView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hourglass")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .symbolEffect(.pulse)

            Text("Waiting for approval")
                .font(.title2)
                .fontWeight(.bold)

            if let profile = authViewModel.profile {
                Text("The KUET transport office will check your \(profile.role.idLabel) (\(profile.kuetId ?? "not given")). This screen opens the app as soon as you're approved.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            ProgressView()

            Button("Sign Out", role: .destructive) {
                authViewModel.signOut()
            }
            .padding(.top)
        }
        .padding()
    }
}

//
//  VerifyEmailView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Shown until a student or teacher opens the link sent to their KUET email.
//

import SwiftUI

struct VerifyEmailView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Verify your KUET email")
                .font(.title2)
                .fontWeight(.bold)

            Text("We sent a link to \(authViewModel.profile?.email ?? "your email"). Open it, then come back and tap the button below.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button {
                authViewModel.refreshVerification()
            } label: {
                Text("I've verified my email")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button("Send the link again") {
                authViewModel.resendVerification()
            }

            if !authViewModel.infoMessage.isEmpty {
                Text(authViewModel.infoMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if !authViewModel.errorMessage.isEmpty {
                Text(authViewModel.errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            Button("Sign Out", role: .destructive) {
                authViewModel.signOut()
            }
            .padding(.top)
        }
        .padding()
    }
}

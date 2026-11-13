//
//  AppLockView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Covers the app until the user unlocks it. Each person chooses in Settings > Privacy & security:
//  - Face ID only: the Face ID prompt (falls back to the phone's passcode)
//  - App passcode only: the number pad
//  - Both: Face ID first, and the app passcode if Face ID fails
//

import SwiftUI

struct AppLockView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("faceIDOn") private var faceIDOn = false
    @AppStorage("passcodeOn") private var passcodeOn = false

    let onUnlock: () -> Void
    @State private var message = ""
    @State private var shakes = 0
    @State private var triedFaceID = false

    var body: some View {
        VStack(spacing: 16) {
            Image("AppLogo")
                .resizable()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(radius: 6)
                .padding(.top, 40)

            Text("KUET Bus Live is locked")
                .font(.title3)
                .fontWeight(.bold)

            if passcodeOn {
                PasscodePad(title: String(localized: "Enter app passcode"), message: message, shakes: shakes) { code in
                    if AppPasscode.check(code) {
                        onUnlock()
                    } else {
                        message = String(localized: "Wrong passcode")
                        shakes += 1
                    }
                }
            } else if !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if faceIDOn {
                Button {
                    tryFaceID()
                } label: {
                    Label("Use \(BiometricAuth.biometryName ?? "Face ID")", systemImage: "faceid")
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            // Signing in again with the account password is the way back in.
            Button("Forgot? Sign out", role: .destructive) {
                AppPasscode.remove()
                passcodeOn = false
                faceIDOn = false
                authViewModel.signOut()
            }
            .font(.footnote)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThickMaterial)
        // The lock screen is put up while the app goes to the background, but
        // iOS only shows Face ID to an app on screen. So wait until the app is
        // active again, and try it automatically only once per lock.
        .onAppear {
            autoTryFaceID()
        }
        .onChange(of: scenePhase) { _, _ in
            autoTryFaceID()
        }
    }

    func autoTryFaceID() {
        guard faceIDOn, scenePhase == .active, !triedFaceID else { return }
        triedFaceID = true
        tryFaceID()
    }

    func tryFaceID() {
        // With an app passcode, Face ID falls back to our own pad, not the phone's passcode.
        BiometricAuth.authenticate(reason: "Unlock KUET Bus Live",
                                   allowDevicePasscode: !passcodeOn) { success, error in
            if success {
                onUnlock()
            } else if !passcodeOn {
                message = error ?? String(localized: "Couldn't unlock. Try again.")
            }
        }
    }
}

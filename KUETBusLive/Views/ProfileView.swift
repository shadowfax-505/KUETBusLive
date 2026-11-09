//
//  ProfileView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Shown inside a NavigationStack by its parent.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("arrivalAlertOn") private var arrivalAlertOn = false
    @AppStorage("faceIDOn") private var faceIDOn = false
    @AppStorage("passcodeOn") private var passcodeOn = false
    @State private var showSetPasscode = false

    // Turning the switch on opens the set-up screen. Turning it off deletes the passcode.
    var passcodeBinding: Binding<Bool> {
        Binding(
            get: { passcodeOn },
            set: { newValue in
                if newValue {
                    showSetPasscode = true
                } else {
                    AppPasscode.remove()
                    passcodeOn = false
                }
            }
        )
    }

    // Students and teachers ride buses, so they get a stop and arrival alerts.
    var isRider: Bool {
        authViewModel.profile?.role == .student || authViewModel.profile?.role == .teacher
    }

    var body: some View {
        Form {
            Section(header: Text("Account")) {
                LabeledContent("Name", value: authViewModel.profile?.name ?? "")
                LabeledContent("Email", value: authViewModel.profile?.email ?? "")
                LabeledContent("Role", value: authViewModel.profile?.role.title ?? "")
                if let profile = authViewModel.profile, let kuetId = profile.kuetId {
                    LabeledContent(profile.role.idLabel, value: kuetId)
                }
                if isRider {
                    LabeledContent("Can ride", value: authViewModel.profile?.role == .teacher
                                   ? String(localized: "Any bus") : String(localized: "Student buses only"))
                }
            }

            if isRider {
                Section(header: Text("My stop")) {
                    Text(authViewModel.profile?.favoriteStopName ?? String(localized: "Not set. Pick one in Routes."))
                    ArrivalAlertToggle(isOn: $arrivalAlertOn)
                }
            }

            // Both, either or neither: each lock is its own switch.
            Section(header: Text("App lock"),
                    footer: Text("The app locks when you leave it. With both on, Face ID is tried first and the passcode is the backup.")) {
                if let biometry = BiometricAuth.biometryName {
                    Toggle("Unlock with \(biometry)", isOn: $faceIDOn)
                }
                Toggle("App passcode", isOn: passcodeBinding)
                if passcodeOn {
                    Button("Change passcode") {
                        showSetPasscode = true
                    }
                }
            }

            // The app has English and Bangla text. iOS picks one from the phone's language.
            Section {
                Button {
                    // Opens this app's page in Settings, where its language can be changed.
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    LabeledContent("Language", value: Locale.current.localizedString(
                        forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en") ?? "English")
                }
                .foregroundColor(.primary)
            } header: {
                Text("Language")
            } footer: {
                Text("The app follows your phone's language. To use it in Bangla, set Bangla in Settings > General > Language & Region, or choose it for this app only in Settings > KUET Bus Live > Language.")
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                }
            }
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showSetPasscode) {
            SetPasscodeView { saved in
                if saved {
                    passcodeOn = true
                }
            }
        }
        .onChange(of: faceIDOn) { _, newValue in
            // Make sure the person can actually unlock before turning the lock on.
            guard newValue else { return }
            BiometricAuth.authenticate(reason: "Turn on Face ID unlock") { success, _ in
                if !success {
                    faceIDOn = false
                }
            }
        }
        .onChange(of: arrivalAlertOn) { _, newValue in
            if newValue {
                NotificationManager.shared.requestPermission()
            }
        }
    }
}

// @Binding: the toggle writes straight into the parent's stored setting.
struct ArrivalAlertToggle: View {
    @Binding var isOn: Bool
    @AppStorage(NotificationManager.alertMinutesKey) private var minutes = NotificationManager.defaultAlertMinutes

    var body: some View {
        Toggle("Alert me before my bus arrives", isOn: $isOn.animation())
        if isOn {
            Stepper(value: $minutes, in: NotificationManager.alertMinutesRange) {
                HStack {
                    Text("How early")
                    Spacer()
                    Text("\(minutes) min")
                        .foregroundColor(.secondary)
                        .contentTransition(.numericText())
                        .animation(.default, value: minutes)
                }
            }
        }
    }
}

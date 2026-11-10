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
    @AppStorage(AnnouncementViewModel.showNewsKey) private var showNews = true
    @AppStorage(RideHistory.suggestionsOnKey) private var suggestionsOn = true
    @AppStorage(RideHistory.backupOnKey) private var backupOn = false
    @State private var confirmReset = false
    @State private var showSetPasscode = false

    // Set by the driver screen while a trip runs, so deleting the account can end it first.
    var endActiveTrip: (() -> Void)? = nil

    @State private var showDeleteConfirm = false
    @State private var deletePassword = ""
    @State private var isDeleting = false
    @State private var deleteError: String?

    static let privacyPolicyURL = URL(string: "https://github.com/shadowfax-505/KUETBusLive/blob/main/docs/privacy-policy.md")!

    // "1.0 (1)": the version and build number set in Xcode.
    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

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
                    NavigationLink {
                        MyPlacesView()
                    } label: {
                        Label("My places", systemImage: "mappin.and.ellipse")
                    }
                    Text(authViewModel.profile?.favoriteStopName.map { PlaceNames.display($0) } ?? String(localized: "Not set. Pick one in Routes."))
                    ArrivalAlertToggle(isOn: $arrivalAlertOn)
                }
            }

            // The admin writes the news, so only riders and drivers get this switch.
            if authViewModel.profile?.role != .admin {
                Section(header: Text("News"),
                        footer: Text("Turned off, there is no badge and no banner on the map. You can still open News yourself, and hide single announcements by swiping them.")) {
                    Toggle("Show news and announcements", isOn: $showNews)
                }
            }

            // Smart suggestions learn the rider's usual bus on this phone.
            if isRider {
                Section(header: Text("Smart suggestions"),
                        footer: Text("The app notices which bus you follow, wave at or get on, and suggests it at the same time next week. This stays on this phone unless you keep it in your account.")) {
                    Toggle("Suggest my usual bus", isOn: $suggestionsOn)
                    Toggle("Keep my ride history in my account", isOn: $backupOn)
                        .disabled(!suggestionsOn)
                        .onChange(of: backupOn) { _, on in
                            if on, let uid = authViewModel.user?.uid {
                                RideHistory.shared.restoreFromAccount(uid: uid)
                            }
                        }
                    Button("Reset what the app has learned", role: .destructive) {
                        confirmReset = true
                    }
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

            // Riders and drivers can tell the transport office about a problem.
            if authViewModel.profile?.role != .admin {
                Section(header: Text("Help")) {
                    NavigationLink {
                        ReportProblemView()
                    } label: {
                        Label("Report a problem", systemImage: "exclamationmark.bubble")
                    }
                    NavigationLink {
                        MyComplaintsView()
                    } label: {
                        Label("My complaints", systemImage: "tray.full")
                    }
                }
            }

            // Optional, per phone: only offered where Apple's on-device model can run.
            AssistantSettingsSection()

            Section(header: Text("About")) {
                Link(destination: Self.privacyPolicyURL) {
                    Label("Privacy policy", systemImage: "hand.raised")
                }
                LabeledContent("Version", value: Self.appVersion)
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                }
            }

            Section {
                Button(role: .destructive) {
                    deletePassword = ""
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Text("Delete account")
                        if isDeleting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .foregroundColor(.red)
                .disabled(isDeleting)
            } footer: {
                Text("Removes your profile and login for good.")
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
        .confirmationDialog("Forget your ride history and usual buses?", isPresented: $confirmReset,
                            titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                RideHistory.shared.reset(uid: authViewModel.user?.uid)
            }
        }
        .alert("Delete account?", isPresented: $showDeleteConfirm) {
            SecureField("Password", text: $deletePassword)
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {
                deletePassword = ""
            }
        } message: {
            Text(AccountDeletion.explanation(role: authViewModel.profile?.role ?? .student,
                                             isOnTrip: endActiveTrip != nil))
        }
        .alert("Account not deleted", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
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

extension ProfileView {
    func deleteAccount() {
        let password = deletePassword
        deletePassword = ""
        guard !password.isEmpty else {
            deleteError = String(localized: "Enter your password to delete the account.")
            return
        }
        isDeleting = true
        authViewModel.deleteAccount(password: password, beforeDeleting: endActiveTrip) { problem in
            isDeleting = false
            deleteError = problem
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

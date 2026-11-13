//
//  ProfileView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Shown inside a NavigationStack by its parent. Grouped like the Settings app:
//  who you are, your trips and places, news, language and look, security,
//  help, and finally signing out.
//

import SwiftUI
import PhotosUI

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
    @EnvironmentObject var announcementViewModel: AnnouncementViewModel
    @ObservedObject private var photoStore = ProfilePhotoStore.shared
    @State private var pickedPhoto: PhotosPickerItem?
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system.rawValue
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue

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

    // Switch the bundle first, then store the choice, which rebuilds every screen.
    var languageBinding: Binding<String> {
        Binding(get: { language }, set: { code in
            (AppLanguage(rawValue: code) ?? .system).apply()
            language = code
        })
    }

    var body: some View {
        Form {
            accountHeader

            if isRider {
                Section(header: Text("Trips & alerts")) {
                    ArrivalAlertToggle(isOn: $arrivalAlertOn)
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

                Section(header: Text("Places"),
                        footer: Text("Pick your stop on a route's page. Your places are where you usually wait, like home or a tuition centre.")) {
                    LabeledContent("My stop", value: authViewModel.profile?.favoriteStopName.map { PlaceNames.display($0) }
                                   ?? String(localized: "Not set"))
                    NavigationLink {
                        RoutesList()
                    } label: {
                        Label("Routes and stops", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                    NavigationLink {
                        MyPlacesView()
                    } label: {
                        Label("My places", systemImage: "mappin.and.ellipse")
                    }
                }
            }

            // The admin writes the news, so only riders and drivers read it here.
            if authViewModel.profile?.role != .admin {
                Section(header: Text("News"),
                        footer: Text("Turned off, there is no badge and no banner on the map. You can still open News yourself, and hide single announcements by swiping them.")) {
                    NavigationLink {
                        AnnouncementsView()
                    } label: {
                        Label("News and announcements", systemImage: "megaphone")
                    }
                    .badge(showNews ? announcementViewModel.unreadCount : 0)
                    Toggle("Show news alerts", isOn: $showNews)
                }
            }

            Section {
                Picker(selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                } label: {
                    Label("Language", systemImage: "globe")
                }
                Picker(selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                } label: {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                }
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open iOS Settings", systemImage: "gear")
                }
            } header: {
                Text("Language & appearance")
            } footer: {
                Text("The language changes at once. Same as iPhone follows the phone's own language.")
            }

            // Both, either or neither: each lock is its own switch.
            Section(header: Text("Security"),
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

            // Optional, per phone: only offered where Apple's on-device model can run.
            AssistantSettingsSection()

            Section(header: Text("Help & feedback")) {
                // Riders and drivers can tell the transport office about a problem.
                if authViewModel.profile?.role != .admin {
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
                Link(destination: Self.privacyPolicyURL) {
                    Label("Privacy policy", systemImage: "hand.raised")
                }
                LabeledContent("Version", value: Self.appVersion)
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                }
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
            } header: {
                Text("Account")
            } footer: {
                Text("Deleting removes your profile and login for good.")
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
        .onAppear { photoStore.load(uid: authViewModel.user?.uid) }
        .onChange(of: pickedPhoto) { _, item in
            item?.loadTransferable(type: Data.self) { result in
                if case .success(let data?) = result {
                    DispatchQueue.main.async { photoStore.save(data) }
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
    // Photo, name and role at the top, like a contact card. Tap the photo to change it.
    var accountHeader: some View {
        Section {
            HStack(spacing: 16) {
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    ProfileAvatar(image: photoStore.image, name: authViewModel.profile?.name ?? "", size: 72)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(MapTheme.buttonText, MapTheme.buttonFill)
                                .font(.title3)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(photoStore.image == nil ? "Add a profile photo" : "Change profile photo")
                VStack(alignment: .leading, spacing: 4) {
                    Text(authViewModel.profile?.name ?? "")
                        .font(.title3.weight(.semibold))
                    Text(authViewModel.profile?.role.title ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(authViewModel.profile?.email ?? "")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.vertical, 4)
            if let profile = authViewModel.profile, let kuetId = profile.kuetId {
                LabeledContent(profile.role.idLabel, value: kuetId)
            }
            if isRider {
                LabeledContent("Can ride", value: authViewModel.profile?.role == .teacher
                               ? String(localized: "Any bus") : String(localized: "Student buses only"))
            }
            if photoStore.image != nil {
                Button("Remove photo", role: .destructive) {
                    photoStore.remove()
                }
            }
        } footer: {
            Text("Your photo stays on this iPhone and isn't uploaded.")
        }
    }

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

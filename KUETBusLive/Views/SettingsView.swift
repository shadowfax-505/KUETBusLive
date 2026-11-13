//
//  SettingsView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Settings, opened from Profile. Laid out like a messaging app's settings:
//  one row per page, each with an icon, a title and a grey line saying what
//  is inside, and a search field at the top. Every switch that used to sit on
//  the Profile page lives on one of these pages now.
//

import SwiftUI

// The pages of Settings, in the order they are listed.
enum SettingsPage: String, CaseIterable, Identifiable, Hashable {
    case account, notifications, privacy, appearance, language, assistant, storage, help

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account: return String(localized: "Account")
        case .notifications: return String(localized: "Notifications")
        case .privacy: return String(localized: "Privacy & security")
        case .appearance: return String(localized: "Appearance")
        case .language: return String(localized: "Language")
        case .assistant: return String(localized: "Smart assistant")
        case .storage: return String(localized: "Data & storage")
        case .help: return String(localized: "Help & feedback")
        }
    }

    var subtitle: String {
        switch self {
        case .account: return String(localized: "Name, email, sign out, delete account")
        case .notifications: return String(localized: "Arrival alerts, news")
        case .privacy: return String(localized: "Face ID, app passcode")
        case .appearance: return String(localized: "Light or dark, map style")
        case .language: return "English, বাংলা"
        case .assistant: return String(localized: "Answers on this iPhone")
        case .storage: return String(localized: "Clear cache")
        case .help: return String(localized: "Complaints, privacy policy, version")
        }
    }

    var icon: String {
        switch self {
        case .account: return "person.crop.circle"
        case .notifications: return "bell.badge"
        case .privacy: return "lock.shield"
        case .appearance: return "circle.lefthalf.filled"
        case .language: return "globe"
        case .assistant: return "sparkles"
        case .storage: return "internaldrive"
        case .help: return "questionmark.circle"
        }
    }

    // Extra English words the search also looks at.
    var keywords: [String] {
        switch self {
        case .account: return ["profile", "photo", "logout", "log out", "role", "id"]
        case .notifications: return ["alert", "remind", "announcement", "badge", "banner"]
        case .privacy: return ["face id", "touch id", "passcode", "lock", "security", "biometric"]
        case .appearance: return ["theme", "dark", "light", "map", "satellite"]
        case .language: return ["bangla", "bengali", "english", "বাংলা"]
        case .assistant: return ["ai", "model", "ask", "on-device"]
        case .storage: return ["cache", "storage", "clear", "space"]
        case .help: return ["complaint", "problem", "report", "privacy policy", "about", "version"]
        }
    }

    // Admins don't ride or read the news, so they have nothing to be notified about here.
    static func visible(for role: UserRole) -> [SettingsPage] {
        allCases.filter { page in
            page != .notifications || role != .admin
        }
    }

    static func matching(_ query: String, in pages: [SettingsPage]) -> [SettingsPage] {
        let words = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !words.isEmpty else { return pages }
        return pages.filter { page in
            ([page.title, page.subtitle] + page.keywords).contains { $0.lowercased().contains(words) }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var query = ""

    // Set by the driver screen while a trip runs, so deleting the account can end it first.
    var endActiveTrip: (() -> Void)? = nil

    var pages: [SettingsPage] {
        SettingsPage.matching(query, in: SettingsPage.visible(for: authViewModel.profile?.role ?? .student))
    }

    var body: some View {
        List {
            // Grouped like the reference apps: you, then the app, then help.
            let groups: [[SettingsPage]] = [[.account, .notifications, .privacy],
                                            [.appearance, .language, .assistant, .storage],
                                            [.help]]
            ForEach(groups.indices, id: \.self) { index in
                let shown = groups[index].filter(pages.contains)
                if !shown.isEmpty {
                    Section {
                        ForEach(shown) { page in
                            NavigationLink {
                                destination(for: page)
                            } label: {
                                SettingsRow(icon: page.icon, title: page.title, subtitle: page.subtitle)
                            }
                        }
                    }
                }
            }
            if pages.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle("Settings")
        .searchable(text: $query, prompt: Text("Search settings"))
    }

    // Plain links rather than value-based ones, so this works in any parent navigation stack.
    @ViewBuilder
    func destination(for page: SettingsPage) -> some View {
        switch page {
        case .account: AccountSettingsView(endActiveTrip: endActiveTrip)
        case .notifications: NotificationSettingsView()
        case .privacy: SecuritySettingsView()
        case .appearance: AppearanceSettingsView()
        case .language: LanguageSettingsView()
        case .assistant: Form { AssistantSettingsSection() }.navigationTitle(page.title)
        case .storage: StorageSettingsView()
        case .help: HelpSettingsView()
        }
    }
}

// MARK: - Rows

// A small black (white in dark mode) rounded square with a white glyph.
struct SettingsIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(MapTheme.buttonText)
            .frame(width: 32, height: 32)
            .background(MapTheme.buttonFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

// Icon, title and a grey line under it.
struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(MapTheme.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Account

struct AccountSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var photoStore = ProfilePhotoStore.shared
    var endActiveTrip: (() -> Void)?

    @State private var showDeleteConfirm = false
    @State private var deletePassword = ""
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Name", value: authViewModel.profile?.name ?? "")
                LabeledContent("Email") {
                    Text(authViewModel.profile?.email ?? "")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                LabeledContent("Role", value: authViewModel.profile?.role.title ?? "")
                if let profile = authViewModel.profile, let kuetId = profile.kuetId {
                    LabeledContent(profile.role.idLabel, value: kuetId)
                }
                if let role = authViewModel.profile?.role, role == .student || role == .teacher {
                    LabeledContent("Can ride", value: role == .teacher
                                   ? String(localized: "Any bus") : String(localized: "Student buses only"))
                }
            }

            if photoStore.image != nil {
                Section(footer: Text("Your photo stays on this iPhone and isn't uploaded.")) {
                    Button("Remove photo", role: .destructive) {
                        photoStore.remove()
                    }
                }
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
            } footer: {
                Text("Deleting removes your profile and login for good.")
            }
        }
        .navigationTitle("Account")
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

// MARK: - Notifications

struct NotificationSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("arrivalAlertOn") private var arrivalAlertOn = false
    @AppStorage(AnnouncementViewModel.showNewsKey) private var showNews = true

    var isRider: Bool {
        authViewModel.profile?.role == .student || authViewModel.profile?.role == .teacher
    }

    var body: some View {
        Form {
            if isRider {
                Section(header: Text("Arrival alerts"),
                        footer: Text("A notification when the bus is this many minutes from your stop.")) {
                    ArrivalAlertToggle(isOn: $arrivalAlertOn)
                }
            }
            Section(header: Text("News"),
                    footer: Text("Turned off, there is no badge and no banner on the map. You can still open News yourself, and hide single announcements by swiping them.")) {
                Toggle("Show news alerts", isOn: $showNews)
            }
            Section {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open iOS notification settings", systemImage: "arrow.up.forward.app")
                }
            }
        }
        .navigationTitle("Notifications")
        .onChange(of: arrivalAlertOn) { _, newValue in
            if newValue {
                NotificationManager.shared.requestPermission()
            }
        }
    }
}

// MARK: - Privacy & security

struct SecuritySettingsView: View {
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

    var body: some View {
        Form {
            // Both, either or neither: each lock is its own switch.
            Section(footer: Text("The app locks when you leave it. With both on, Face ID is tried first and the passcode is the backup.")) {
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
            Section {
                Link(destination: ProfileView.privacyPolicyURL) {
                    Label("Privacy policy", systemImage: "hand.raised")
                }
            }
        }
        .navigationTitle("Privacy & security")
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
    }
}

// MARK: - Appearance

struct AppearanceSettingsView: View {
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue
    @AppStorage(MapStyleChoice.storageKey) private var mapStyle = MapStyleChoice.standard.rawValue

    var body: some View {
        Form {
            Section(header: Text("Theme")) {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section(header: Text("Live map"), footer: Text("Satellite shows photos of the roads under the buses.")) {
                Picker("Map style", selection: $mapStyle) {
                    ForEach(MapStyleChoice.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .navigationTitle("Appearance")
    }
}

// MARK: - Language

struct LanguageSettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system.rawValue

    // Switch the bundle first, then store the choice, which rebuilds every screen.
    var languageBinding: Binding<String> {
        Binding(get: { language }, set: { code in
            (AppLanguage(rawValue: code) ?? .system).apply()
            language = code
        })
    }

    var body: some View {
        Form {
            Section(footer: Text("The language changes at once. Same as iPhone follows the phone's own language.")) {
                Picker("Language", selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Language")
    }
}

// MARK: - Data & storage

struct StorageSettingsView: View {
    @State private var size: Int64 = AppCache.currentSize()
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section(footer: Text("Saved road routes and map data. Your places, ride history and settings are kept.")) {
                LabeledContent("Cache", value: AppCache.sizeText(size))
                Button("Clear cache", role: .destructive) {
                    confirmClear = true
                }
                .disabled(size == 0)
            }
        }
        .navigationTitle("Data & storage")
        .confirmationDialog("Clear the cache?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear cache", role: .destructive) {
                AppCache.clear()
                size = AppCache.currentSize()
            }
        }
        .onAppear { size = AppCache.currentSize() }
    }
}

// MARK: - Help & feedback

struct HelpSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Form {
            // Riders and drivers can tell the transport office about a problem.
            if authViewModel.profile?.role != .admin {
                Section {
                    NavigationLink {
                        ReportProblemView()
                    } label: {
                        SettingsRow(icon: "exclamationmark.bubble", title: String(localized: "Report a problem"))
                    }
                    NavigationLink {
                        MyComplaintsView()
                    } label: {
                        SettingsRow(icon: "tray.full", title: String(localized: "My complaints"))
                    }
                }
            }
            Section {
                Link(destination: ProfileView.privacyPolicyURL) {
                    SettingsRow(icon: "hand.raised", title: String(localized: "Privacy policy"))
                }
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    SettingsRow(icon: "gear", title: String(localized: "Open iOS Settings"))
                }
            }
            Section {
                LabeledContent("Version", value: ProfileView.appVersion)
            }
        }
        .navigationTitle("Help & feedback")
    }
}

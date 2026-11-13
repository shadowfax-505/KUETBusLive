//
//  ProfileView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Shown inside a NavigationStack by its parent. Laid out like a messaging
//  app's profile: a large photo with a camera badge, the name and email under
//  it, a few personal rows (my stop, my places, my trips, news), and a
//  Settings row that opens every switch and account action (SettingsView).
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var announcementViewModel: AnnouncementViewModel
    @AppStorage(AnnouncementViewModel.showNewsKey) private var showNews = true
    @ObservedObject private var photoStore = ProfilePhotoStore.shared
    @State private var pickedPhoto: PhotosPickerItem?

    // Set by the driver screen while a trip runs, so deleting the account can end it first.
    var endActiveTrip: (() -> Void)? = nil

    static let privacyPolicyURL = URL(string: "https://github.com/shadowfax-505/KUETBusLive/blob/main/docs/privacy-policy.md")!

    // "1.0 (1)": the version and build number set in Xcode.
    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // Students and teachers ride buses, so they get a stop, places and trips.
    var isRider: Bool {
        authViewModel.profile?.role == .student || authViewModel.profile?.role == .teacher
    }

    var body: some View {
        List {
            header

            if isRider {
                Section {
                    NavigationLink {
                        RoutesList()
                    } label: {
                        SettingsRow(icon: "star", title: String(localized: "My stop"),
                                    subtitle: authViewModel.profile?.favoriteStopName.map { PlaceNames.display($0) }
                                        ?? String(localized: "Not set"))
                    }
                    NavigationLink {
                        MyPlacesView()
                    } label: {
                        SettingsRow(icon: "mappin.and.ellipse", title: String(localized: "My places"),
                                    subtitle: String(localized: "Home, tuition and other places you wait"))
                    }
                    NavigationLink {
                        MyTripsView()
                    } label: {
                        SettingsRow(icon: "clock.arrow.circlepath", title: String(localized: "My trips"),
                                    subtitle: String(localized: "Recent buses and your usual bus"))
                    }
                }
            }

            // The admin writes the news, so only riders and drivers read it here.
            if authViewModel.profile?.role != .admin {
                Section {
                    NavigationLink {
                        AnnouncementsView()
                    } label: {
                        SettingsRow(icon: "megaphone", title: String(localized: "News"),
                                    subtitle: String(localized: "Announcements from the transport office"))
                    }
                    .badge(showNews ? announcementViewModel.unreadCount : 0)
                }
            }

            Section {
                NavigationLink {
                    SettingsView(endActiveTrip: endActiveTrip)
                } label: {
                    SettingsRow(icon: "gearshape", title: String(localized: "Settings"),
                                subtitle: String(localized: "Account, notifications, privacy, appearance"))
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { photoStore.load(uid: authViewModel.user?.uid) }
        .onChange(of: pickedPhoto) { _, item in
            item?.loadTransferable(type: Data.self) { result in
                if case .success(let data?) = result {
                    DispatchQueue.main.async { photoStore.save(data) }
                }
            }
        }
    }

    // A large round photo with a camera badge, then the name, email and role.
    var header: some View {
        Section {
            VStack(spacing: 12) {
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    ProfileAvatar(image: photoStore.image, name: authViewModel.profile?.name ?? "", size: 112)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(MapTheme.buttonText)
                                .frame(width: 36, height: 36)
                                .background(MapTheme.buttonFill, in: Circle())
                                .overlay(Circle().strokeBorder(Color(.systemGroupedBackground), lineWidth: 3))
                                .offset(x: 2, y: 2)
                        }
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(photoStore.image == nil ? "Add a profile photo" : "Change profile photo")

                VStack(spacing: 4) {
                    Text(authViewModel.profile?.name ?? "")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(authViewModel.profile?.email ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let role = authViewModel.profile?.role {
                        Text(role.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(MapTheme.raised, in: Capsule())
                            .padding(.top, 4)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }
}

// My trips: the buses I followed or waited for lately, and the usual-bus settings.
struct MyTripsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var history = RideHistory.shared
    @AppStorage(RideHistory.suggestionsOnKey) private var suggestionsOn = true
    @AppStorage(RideHistory.backupOnKey) private var backupOn = false
    @State private var confirmReset = false

    var recent: [RideEvent] {
        Array(history.events.sorted { $0.date > $1.date }.prefix(30))
    }

    var body: some View {
        List {
            Section(header: Text("Recent")) {
                if recent.isEmpty {
                    Text("Buses you follow or wait for show up here.")
                        .foregroundStyle(.secondary)
                }
                ForEach(recent) { event in
                    HStack(spacing: 14) {
                        SettingsIcon(systemName: icon(for: event.kind))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(PlaceNames.display(event.tripTitle))
                            Text("\(PlaceNames.display(event.boardingName)) · \(event.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Section(header: Text("Usual bus"),
                    footer: Text("The app learns which bus you usually take and suggests it on the map. Everything stays on this iPhone unless you keep it in your account.")) {
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
        .navigationTitle("My trips")
        .confirmationDialog("Forget your ride history and usual buses?", isPresented: $confirmReset,
                            titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                RideHistory.shared.reset(uid: authViewModel.user?.uid)
            }
        }
    }

    func icon(for kind: RideEventKind) -> String {
        switch kind {
        case .followed: return "lock.iphone"
        case .alerted: return "bell"
        case .waved: return "hand.wave"
        case .boarded: return "bus"
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

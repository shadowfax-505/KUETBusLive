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
                                   ? "Any bus" : "Student buses only")
                }
            }

            if isRider {
                Section(header: Text("My stop")) {
                    Text(authViewModel.profile?.favoriteStopName ?? "Not set. Pick one in Routes.")
                    ArrivalAlertToggle(isOn: $arrivalAlertOn)
                }
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                }
            }
        }
        .navigationTitle("Profile")
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

    var body: some View {
        Toggle("Alert me \(NotificationManager.alertMinutes) min before my bus arrives", isOn: $isOn)
    }
}

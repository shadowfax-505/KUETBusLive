//
//  AdminTabView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Transport admin: keeps schedules up to date, approves teachers and drivers,
//  edits routes and their stops, posts announcements and answers complaints.
//

import SwiftUI

struct AdminTabView: View {
    // Kept here so the More tab and its Complaints row can show how many are unread.
    @StateObject private var complaintViewModel = ComplaintViewModel()

    var body: some View {
        TabView {
            SchedulesView()
                .tabItem {
                    Label("Schedules", systemImage: "calendar")
                }

            ApprovalsView()
                .tabItem {
                    Label("Approvals", systemImage: "person.badge.shield.checkmark")
                }

            LiveMapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            RoutesListView()
                .tabItem {
                    Label("Routes", systemImage: "list.bullet")
                }

            // Our own More tab instead of the system one. The system More list wraps each
            // page in a second navigation bar, so the pages showed two back buttons.
            NavigationStack {
                List {
                    NavigationLink {
                        DriversAndBusesView()
                    } label: {
                        Label("Drivers & buses", systemImage: "bus.doubledecker")
                    }
                    NavigationLink {
                        AdminComplaintsView(complaintViewModel: complaintViewModel)
                    } label: {
                        Label("Complaints", systemImage: "exclamationmark.bubble")
                    }
                    .badge(complaintViewModel.unreadCount)
                    NavigationLink {
                        AnnouncementsView()
                    } label: {
                        Label("News", systemImage: "megaphone")
                    }
                    NavigationLink {
                        SpecialDaysView()
                    } label: {
                        Label("Special days", systemImage: "calendar.badge.exclamationmark")
                    }
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Label("Profile", systemImage: "person.circle")
                    }
                }
                .navigationTitle("More")
            }
            .tabItem {
                Label("More", systemImage: "ellipsis")
            }
            // Unread complaints, so they are seen without opening More.
            .badge(complaintViewModel.unreadCount)
        }
        .onAppear { complaintViewModel.listenToAll() }
        .onDisappear { complaintViewModel.stopListening() }
    }
}


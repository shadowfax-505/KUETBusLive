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
    // Kept here so the Complaints item can show how many are unread.
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

            NavigationStack {
                DriversAndBusesView()
            }
            .tabItem {
                Label("Drivers & buses", systemImage: "bus.doubledecker")
            }

            // Under More, after Drivers & buses. The unread count shows next to it there.
            NavigationStack {
                AdminComplaintsView(complaintViewModel: complaintViewModel)
            }
            .tabItem {
                Label("Complaints", systemImage: "exclamationmark.bubble")
            }
            .badge(complaintViewModel.unreadCount)

            NavigationStack {
                AnnouncementsView()
            }
            .tabItem {
                Label("News", systemImage: "megaphone")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
        }
        .onAppear { complaintViewModel.listenToAll() }
        .onDisappear { complaintViewModel.stopListening() }
    }
}


//
//  AdminTabView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Transport admin: keeps schedules up to date, approves teachers and drivers,
//  edits routes and their stops, and posts announcements.
//

import SwiftUI

struct AdminTabView: View {
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
    }
}

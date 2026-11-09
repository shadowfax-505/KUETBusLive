//
//  AdminTabView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Transport admin: keeps schedules up to date, approves teachers and drivers,
//  and manages routes.
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
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
        }
    }
}

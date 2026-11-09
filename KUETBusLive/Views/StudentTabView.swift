//
//  StudentTabView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import SwiftUI

// Used by students and teachers. Each screen filters buses by the signed-in role.
struct StudentTabView: View {
    var body: some View {
        TabView {
            LiveMapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            SchedulesView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
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

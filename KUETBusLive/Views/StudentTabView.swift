//
//  StudentTabView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import SwiftUI

// Used by students and teachers. Each screen filters buses by the signed-in role.
struct StudentTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var announcementViewModel: AnnouncementViewModel
    // Only used to keep the home screen widget's timetable up to date.
    @StateObject private var widgetSchedules = ScheduleViewModel()

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
                AnnouncementsView()
            }
            .tabItem {
                Label("News", systemImage: "megaphone")
            }
            // Red number on the tab: announcements posted since the list was last opened.
            .badge(announcementViewModel.unreadCount)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
        }
        .onAppear {
            widgetSchedules.startListening()
        }
        .onDisappear {
            widgetSchedules.stopListening()
        }
        // New timetable from Firestore, or a new favourite stop: tell the widget.
        .onReceive(widgetSchedules.$schedules) { schedules in
            updateWidget(schedules)
        }
        .onChange(of: authViewModel.profile?.favoriteStopName) {
            updateWidget(widgetSchedules.schedules)
        }
    }

    func updateWidget(_ schedules: [BusSchedule]) {
        // An empty list means Firestore hasn't answered yet; keep what the widget already has.
        guard !schedules.isEmpty, let profile = authViewModel.profile else { return }
        WidgetSync.save(schedules: schedules, role: profile.role,
                        favoriteStop: profile.favoriteStopName)
    }
}

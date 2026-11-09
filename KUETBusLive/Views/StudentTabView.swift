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
    @StateObject private var widgetRoutes = RouteViewModel()

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
            widgetRoutes.startListening()
        }
        .onDisappear {
            widgetSchedules.stopListening()
            widgetRoutes.stopListening()
        }
        // The route with my stop on it, drawn on the large widget's map.
        .onReceive(widgetRoutes.$routes) { routes in
            WidgetSync.saveRoute(from: routes, favoriteStop: authViewModel.profile?.favoriteStopName)
            updatePushTopic(routes)
        }
        // New timetable from Firestore, or a new favourite stop: tell the widget.
        .onReceive(widgetSchedules.$schedules) { schedules in
            updateWidget(schedules)
        }
        .onChange(of: authViewModel.profile?.favoriteStopName) {
            updateWidget(widgetSchedules.schedules)
            WidgetSync.saveRoute(from: widgetRoutes.routes, favoriteStop: authViewModel.profile?.favoriteStopName)
            updatePushTopic(widgetRoutes.routes)
        }
    }

    // Server push: listen to the route that has my stop on it ("Normal-2 just left campus").
    func updatePushTopic(_ routes: [BusRoute]) {
        guard let stopName = authViewModel.profile?.favoriteStopName, !routes.isEmpty else { return }
        let myRoute = routes.first { route in
            route.stops.contains { $0.name == stopName }
        }
        PushManager.shared.subscribe(toRouteId: myRoute?.id)
        PushManager.shared.saveTokenForCurrentUser()
    }

    func updateWidget(_ schedules: [BusSchedule]) {
        // An empty list means Firestore hasn't answered yet; keep what the widget already has.
        guard !schedules.isEmpty, let profile = authViewModel.profile else { return }
        WidgetSync.save(schedules: schedules, role: profile.role,
                        favoriteStop: profile.favoriteStopName)
    }
}

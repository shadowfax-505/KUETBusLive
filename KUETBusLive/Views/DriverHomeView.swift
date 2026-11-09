//
//  DriverHomeView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import SwiftUI
import MapKit

struct DriverHomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var announcementViewModel: AnnouncementViewModel
    @StateObject private var driverViewModel = DriverViewModel()
    @StateObject private var routeViewModel = RouteViewModel()
    @StateObject private var scheduleViewModel = ScheduleViewModel()

    @State private var selectedScheduleId = ""
    @State private var selectedRouteId = ""

    // Today's trips. On a day with no buses (Friday) every trip is listed.
    var tripChoices: [BusSchedule] {
        let today = scheduleViewModel.schedules.filter { $0.runsToday }
        return today.isEmpty ? scheduleViewModel.schedules : today
    }

    var selectedSchedule: BusSchedule? {
        tripChoices.first { $0.id == selectedScheduleId } ?? tripChoices.first
    }

    var selectedRoute: BusRoute? {
        routeViewModel.routes.first { $0.id == selectedRouteId } ?? routeViewModel.routes.first
    }

    var body: some View {
        NavigationStack {
            Form {
                // The route the driver is about to drive, with their own position.
                Section {
                    Map {
                        UserAnnotation()
                        if !driverViewModel.routePath.isEmpty {
                            MapPolyline(coordinates: driverViewModel.routePath)
                                .stroke(.blue, lineWidth: 5)
                        }
                        if let route = selectedRoute {
                            ForEach(route.stops, id: \.self) { stop in
                                Marker(stop.name, systemImage: "mappin", coordinate: stop.coordinate)
                            }
                        }
                    }
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                }

                Section(header: Text("Trip")) {
                    SchedulePicker(schedules: tripChoices,
                                   selectedId: $selectedScheduleId)

                    if let schedule = selectedSchedule {
                        HStack {
                            Text("Allocated to")
                            Spacer()
                            AudienceBadge(audience: schedule.audience)
                        }
                        LabeledContent("Leaves KUET", value: BusSchedule.display(schedule.campusTime))
                        LabeledContent("Leaves \(schedule.spot)", value: BusSchedule.display(schedule.spotTime))
                    }

                    Picker("Route", selection: $selectedRouteId) {
                        ForEach(routeViewModel.routes) { route in
                            Text(route.name).tag(route.id ?? "")
                        }
                    }
                }
                .disabled(driverViewModel.isOnTrip)

                if scheduleViewModel.schedules.isEmpty || routeViewModel.routes.isEmpty {
                    Section {
                        Text("The transport admin hasn't added trips or routes yet.")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button {
                        if driverViewModel.isOnTrip {
                            driverViewModel.endTrip()
                        } else {
                            startTrip()
                        }
                    } label: {
                        Text(driverViewModel.isOnTrip ? "End trip" : "Start trip")
                            .fontWeight(.bold)
                            .foregroundColor(driverViewModel.isOnTrip ? .red : .green)
                    }

                    Text(driverViewModel.statusMessage)
                        .foregroundColor(.secondary)

                    if let lat = driverViewModel.currentLat, let lng = driverViewModel.currentLng {
                        Text(String(format: "%.5f, %.5f", lat, lng))
                            .font(.footnote)
                    }

                    Text("Updates sent: \(driverViewModel.updatesSent)")

                    if driverViewModel.isOnTrip {
                        Label(driverViewModel.permissionText, systemImage: "location.fill")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Live location")
                } footer: {
                    Text("During a trip the bus keeps sharing its position when you lock the phone. The blue pill at the top of the screen shows this. Ending the trip turns it off.")
                }
            }
            .navigationTitle("Driver")
            .toolbar {
                NavigationLink {
                    AnnouncementsView()
                } label: {
                    // A small red dot when there is news the driver hasn't read.
                    Image(systemName: announcementViewModel.unreadCount > 0 ? "megaphone.fill" : "megaphone")
                        .overlay(alignment: .topTrailing) {
                            if announcementViewModel.unreadCount > 0 {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 9, height: 9)
                                    .offset(x: 4, y: -4)
                            }
                        }
                }
                .accessibilityLabel("Announcements")
                .accessibilityValue(announcementViewModel.unreadCount > 0
                                    ? "\(announcementViewModel.unreadCount) unread" : "")

                NavigationLink {
                    ProfileView(endActiveTrip: driverViewModel.isOnTrip ? { driverViewModel.endTrip() } : nil)
                } label: {
                    Image(systemName: "person.circle")
                }
                .accessibilityLabel("Profile")
            }
        }
        .onAppear {
            routeViewModel.startListening()
            scheduleViewModel.startListening()
        }
        .onChange(of: routeViewModel.routes.count) { _, _ in
            // Pick the first route once routes have loaded.
            if selectedRouteId.isEmpty, let firstId = routeViewModel.routes.first?.id {
                selectedRouteId = firstId
            }
            driverViewModel.loadPath(for: selectedRoute)
        }
        .onChange(of: selectedRouteId) { _, _ in
            driverViewModel.loadPath(for: selectedRoute)
        }
        .onChange(of: scheduleViewModel.schedules.count) { _, _ in
            if selectedScheduleId.isEmpty, let firstId = tripChoices.first?.id {
                selectedScheduleId = firstId
            }
        }
        .onDisappear {
            // Leaving this screen (for example signing out) stops GPS and ends the trip.
            routeViewModel.stopListening()
            scheduleViewModel.stopListening()
            if driverViewModel.isOnTrip {
                driverViewModel.endTrip()
            }
        }
    }

    func startTrip() {
        guard let uid = authViewModel.user?.uid else { return }
        guard let schedule = selectedSchedule, let route = selectedRoute else {
            driverViewModel.statusMessage = String(localized: "Pick a bus and a route first")
            return
        }
        driverViewModel.startTrip(schedule: schedule, route: route, driverId: uid)
    }
}

// @Binding: changes the trip chosen in DriverHomeView.
struct SchedulePicker: View {
    let schedules: [BusSchedule]
    @Binding var selectedId: String

    var body: some View {
        Picker("Trip", selection: $selectedId) {
            ForEach(schedules) { schedule in
                Text("\(schedule.title), \(BusSchedule.display(schedule.campusTime))")
                    .tag(schedule.id ?? "")
            }
        }
    }
}

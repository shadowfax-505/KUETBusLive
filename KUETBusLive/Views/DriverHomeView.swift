//
//  DriverHomeView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import SwiftUI

struct DriverHomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
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

                Section(header: Text("Live location")) {
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
                }
            }
            .navigationTitle("Driver")
            .toolbar {
                NavigationLink {
                    ProfileView()
                } label: {
                    Image(systemName: "person.circle")
                }
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
            driverViewModel.statusMessage = "Pick a bus and a route first"
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

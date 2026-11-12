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
    // Which bus the transport office assigned to this driver today.
    @StateObject private var fleetViewModel = FleetViewModel()
    @State private var showAbsence = false
    @AppStorage(AnnouncementViewModel.showNewsKey) private var showNews = true

    @State private var selectedScheduleId = ""
    @State private var selectedRouteId = ""

    // The fleet bus this driver drives today: their own, or one they are covering.
    var myBus: FleetBus? {
        guard let uid = authViewModel.user?.uid else { return nil }
        return BusAssignment.bus(for: uid, in: fleetViewModel.fleet, on: Date())
    }

    // Every trip this driver drives today: those of their own bus, and single trips the
    // office gave them on any bus. Trips of their bus given to someone else are left out.
    var myTrips: [(bus: FleetBus, schedule: BusSchedule)] {
        guard let uid = authViewModel.user?.uid else { return [] }
        return BusAssignment.trips(for: uid, fleet: fleetViewModel.fleet,
                                   schedules: scheduleViewModel.schedules, on: Date())
    }

    // The bus of the trip picked below.
    var selectedBus: FleetBus? {
        myTrips.first { $0.schedule.id == selectedSchedule?.id }?.bus
    }

    // "Your bus today: Normal-2", or "Covering Normal-3 until 12 Nov".
    var myBusText: String {
        guard let bus = myBus else {
            if !myTrips.isEmpty {
                return String(localized: "You drive \(myTrips.count) trips today. Pick one below.")
            }
            return String(localized: "No bus assigned today. Contact the transport office.")
        }
        if BusAssignment.isCoverActive(bus.cover, on: Date()), let cover = bus.cover,
           cover.driverId == authViewModel.user?.uid {
            let until = cover.end.addingTimeInterval(-1).formatted(.dateTime.day().month(.abbreviated))
            return String(localized: "Covering \(bus.name) until \(until)")
        }
        return String(localized: "Your bus today: \(bus.name)")
    }

    // Today's trips this driver drives. On a day with no buses (Friday) the week's are listed.
    var tripChoices: [BusSchedule] {
        myTrips.map(\.schedule)
    }

    var hasWork: Bool {
        myBus != nil || !myTrips.isEmpty
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
                                Marker(stop.displayName, systemImage: "mappin", coordinate: stop.coordinate)
                            }
                        }
                        // Riders waiting along the road ahead.
                        ForEach(driverViewModel.waitingAhead, id: \.wave.uid) { item in
                            Marker(item.wave.label, systemImage: "hand.wave.fill", coordinate: item.wave.coordinate)
                                .tint(.orange)
                        }
                    }
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                }

                // Big and simple, so it can be read at a glance while driving.
                if driverViewModel.isOnTrip && !driverViewModel.waitingAhead.isEmpty {
                    WaitingAheadBanner(waiting: driverViewModel.waitingAhead)
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    Label(myBusText, systemImage: hasWork ? "bus.fill" : "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundColor(hasWork ? .primary : .orange)
                    Button {
                        showAbsence = true
                    } label: {
                        Label("I can't drive", systemImage: "bed.double")
                    }
                    ForEach(fleetViewModel.absences.prefix(3)) { absence in
                        LabeledContent("\(absence.fromDate) – \(absence.untilDate)", value: absence.status.title)
                            .font(.footnote)
                    }
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
                        LabeledContent("Leaves \(schedule.spotDisplayName)", value: BusSchedule.display(schedule.spotTime))
                    }

                    Picker("Route", selection: $selectedRouteId) {
                        ForEach(routeViewModel.routes) { route in
                            Text(route.displayName).tag(route.id ?? "")
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
                            .foregroundColor(driverViewModel.isOnTrip ? .red : (selectedBus == nil ? .secondary : .green))
                    }
                    // Without a trip for today there is nothing to start. A running trip can always end.
                    .disabled(!driverViewModel.isOnTrip && selectedBus == nil)

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
                    Image(systemName: showNews && announcementViewModel.unreadCount > 0 ? "megaphone.fill" : "megaphone")
                        .overlay(alignment: .topTrailing) {
                            if showNews && announcementViewModel.unreadCount > 0 {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 9, height: 9)
                                    .offset(x: 4, y: -4)
                            }
                        }
                }
                .accessibilityLabel("Announcements")
                .accessibilityValue(showNews && announcementViewModel.unreadCount > 0
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
            if let uid = authViewModel.user?.uid {
                fleetViewModel.listenAsDriver(uid: uid)
            }
        }
        .sheet(isPresented: $showAbsence) {
            AbsenceRequestView(fleetViewModel: fleetViewModel)
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
        // The assignment arrived or changed: pick one of this bus's trips.
        .onChange(of: tripChoices.compactMap(\.id)) { _, _ in
            if !tripChoices.contains(where: { $0.id == selectedScheduleId }) {
                selectedScheduleId = tripChoices.first?.id ?? ""
            }
        }
        .onDisappear {
            // Leaving this screen (for example signing out) stops GPS and ends the trip.
            routeViewModel.stopListening()
            scheduleViewModel.stopListening()
            fleetViewModel.stopListening()
            if driverViewModel.isOnTrip {
                driverViewModel.endTrip()
            }
        }
    }

    func startTrip() {
        guard let uid = authViewModel.user?.uid else { return }
        guard let bus = selectedBus else {
            driverViewModel.statusMessage = String(localized: "No bus assigned today. Contact the transport office.")
            return
        }
        guard let schedule = selectedSchedule, let route = selectedRoute else {
            driverViewModel.statusMessage = String(localized: "Pick a bus and a route first")
            return
        }
        driverViewModel.startTrip(schedule: schedule, route: route, fleetBus: bus, driverId: uid)
    }
}

// @Binding: changes the trip chosen in DriverHomeView.
struct SchedulePicker: View {
    let schedules: [BusSchedule]
    @Binding var selectedId: String

    var body: some View {
        Picker("Trip", selection: $selectedId) {
            ForEach(schedules) { schedule in
                Text("\(schedule.displayTitle), \(BusSchedule.display(schedule.campusTime))")
                    .tag(schedule.id ?? "")
            }
        }
    }
}

// "3 waiting ahead · next in 400 m", large enough to read from the driver's seat.
struct WaitingAheadBanner: View {
    let waiting: [(wave: Wave, metres: Double)]

    var nextText: String {
        guard let next = waiting.first else { return "" }
        let metres = Int((next.metres / 50).rounded() * 50)   // to the nearest 50 m
        if metres < 50 {
            return String(localized: "next is here")
        }
        if metres >= 1000 {
            let km = (next.metres / 100).rounded() / 10        // to one decimal, e.g. 8.2
            return String(localized: "next in \(km.formatted()) km")
        }
        return String(localized: "next in \(metres) m")
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 44))
            VStack(alignment: .leading) {
                Text("\(waiting.count) waiting ahead")
                    .font(.largeTitle.bold())
                Text(nextText)
                    .font(.title2)
            }
            Spacer()
        }
        .padding()
        .foregroundColor(.white)
        .background(Color.orange)
        .accessibilityElement(children: .combine)
    }
}


// "I can't drive": the driver picks the days and a reason. The transport office sees
// it in Drivers & buses and arranges a cover driver.
struct AbsenceRequestView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var fleetViewModel: FleetViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var from = Date()
    @State private var until = Date()
    @State private var reason = ""
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("The transport office will arrange another driver for your bus on these days.")) {
                    DatePicker("From", selection: $from, in: Date()..., displayedComponents: .date)
                    DatePicker("Until", selection: $until, in: from..., displayedComponents: .date)
                    TextField("Reason, e.g. fever", text: $reason)
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundColor(.red)
                }
            }
            .navigationTitle("I can't drive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        guard let uid = authViewModel.user?.uid else { return }
                        fleetViewModel.requestAbsence(driverId: uid, driverName: authViewModel.profile?.name ?? "",
                                                      from: from, until: until, reason: reason) { error in
                            if let error = error {
                                errorMessage = error
                            } else {
                                dismiss()
                            }
                        }
                    }
                    .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

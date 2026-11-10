//
//  DriversAndBusesView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Admin > Drivers & buses. Who drives each bus today, regular drivers, cover for
//  drivers who are off, "I can't drive" requests, and turning off drivers who left.
//

import SwiftUI

struct DriversAndBusesView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var fleetViewModel = FleetViewModel()
    @StateObject private var scheduleViewModel = ScheduleViewModel()
    @State private var coverRequest: CoverRequest?
    @State private var draftFor: FleetBus?
    @State private var confirmDeactivate: AppUser?

    // What the cover sheet needs: which bus, and the days from a driver's request.
    struct CoverRequest: Identifiable {
        let id = UUID()
        let bus: FleetBus
        var absence: DriverAbsence?
    }

    var busesWithoutDriver: [FleetBus] {
        fleetViewModel.fleet.filter { BusAssignment.driver(for: $0, on: Date()) == nil }
    }

    var body: some View {
        List {
            if fleetViewModel.fleet.isEmpty {
                Section(footer: Text("Makes one bus for each bus name in the timetable (Normal-1, Normal-2 ...). Then choose a regular driver for each.")) {
                    Button("Create buses from the timetable") {
                        fleetViewModel.createFleet(from: scheduleViewModel.schedules)
                    }
                    .disabled(scheduleViewModel.schedules.isEmpty)
                }
            }

            // Buses nobody can drive today, with a ready-made announcement to edit and post.
            if !busesWithoutDriver.isEmpty {
                Section(header: Text("Needs attention")) {
                    ForEach(busesWithoutDriver) { bus in
                        HStack {
                            Label("\(bus.name): no driver today", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Spacer()
                            Button("Draft notice") { draftFor = bus }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }

            if !fleetViewModel.openAbsences.isEmpty {
                Section(header: Text("Can't drive requests")) {
                    ForEach(fleetViewModel.openAbsences) { absence in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(absence.driverName).font(.headline)
                            Text("\(absence.fromDate) – \(absence.untilDate) · \(absence.reason)")
                                .font(.subheadline)
                            if let bus = fleetViewModel.fleet.first(where: { $0.defaultDriverId == absence.driverId }) {
                                Button("Assign cover for \(bus.name)") {
                                    coverRequest = CoverRequest(bus: bus, absence: absence)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            } else {
                                Text("Not the regular driver of any bus.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            Section(header: Text("Buses today")) {
                ForEach(fleetViewModel.fleet) { bus in
                    NavigationLink {
                        BusAssignmentView(busId: bus.id ?? "", fleetViewModel: fleetViewModel,
                                          onAddCover: { coverRequest = CoverRequest(bus: $0) })
                    } label: {
                        BusTodayRow(bus: bus, fleetViewModel: fleetViewModel)
                    }
                }
            }

            Section(header: Text("Drivers")) {
                ForEach(fleetViewModel.drivers) { driver in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(driver.name)
                            Text(driverStatus(driver))
                                .font(.caption)
                                .foregroundColor(driver.isActive ? .secondary : .red)
                        }
                        Spacer()
                        if driver.isActive {
                            Button("Deactivate", role: .destructive) { confirmDeactivate = driver }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        } else {
                            Button("Reactivate") { fleetViewModel.reactivate(driver) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
        .navigationTitle("Drivers & buses")
        .sheet(item: $coverRequest) { request in
            CoverEditorView(bus: request.bus, absence: request.absence, fleetViewModel: fleetViewModel)
        }
        .sheet(item: $draftFor) { bus in
            ComposeAnnouncementView(
                draftTitle: String(localized: "\(bus.name) may not run today"),
                draftBody: String(localized: "There is no driver for \(bus.name) today. The transport office is arranging one. Please check the map before you leave."))
        }
        .alert("Deactivate \(confirmDeactivate?.name ?? "")?", isPresented: Binding(
            get: { confirmDeactivate != nil }, set: { if !$0 { confirmDeactivate = nil } })) {
            Button("Deactivate", role: .destructive) {
                if let driver = confirmDeactivate { fleetViewModel.deactivate(driver) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use this when a driver leaves the job. They are signed out of driving at once, a running trip ends, and their buses show \"No driver\" until you assign someone. You can reactivate them later.")
        }
        .onAppear {
            fleetViewModel.listenAsAdmin()
            scheduleViewModel.startListening()
        }
        .onDisappear {
            fleetViewModel.stopListening()
            scheduleViewModel.stopListening()
        }
    }

    func driverStatus(_ driver: AppUser) -> String {
        if !driver.isActive { return String(localized: "Deactivated") }
        if let bus = fleetViewModel.regularBus(of: driver.id ?? "") {
            return String(localized: "Regular driver of \(bus.name)")
        }
        return String(localized: "Reserve (no regular bus)")
    }
}

// "Normal-2 · Rahim", with "Covered by Karim until 12 Nov" or a red "No driver today".
struct BusTodayRow: View {
    let bus: FleetBus
    @ObservedObject var fleetViewModel: FleetViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(bus.name).font(.headline)
                Spacer()
                Text(fleetViewModel.driverName(BusAssignment.driver(for: bus, on: Date()))
                     ?? String(localized: "No driver today"))
                    .foregroundColor(BusAssignment.driver(for: bus, on: Date()) == nil ? .red : .secondary)
            }
            if BusAssignment.isCoverActive(bus.cover, on: Date()), let cover = bus.cover {
                Label("Covered by \(fleetViewModel.driverName(cover.driverId) ?? "?") until \(cover.untilDate)",
                      systemImage: "arrow.triangle.swap")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
}

// One bus: change its regular driver (permanent) and see or end its cover (temporary).
struct BusAssignmentView: View {
    let busId: String
    @ObservedObject var fleetViewModel: FleetViewModel
    let onAddCover: (FleetBus) -> Void
    @State private var pendingDriverId: String?
    @State private var askConfirm = false

    var bus: FleetBus? {
        fleetViewModel.fleet.first { $0.id == busId }
    }

    var body: some View {
        if let bus = bus {
            Form {
                Section(header: Text("Regular driver"),
                        footer: Text("A permanent change. A driver can be the regular driver of only one bus; choosing someone who already has a bus swaps the two buses' drivers.")) {
                    Picker("Regular driver", selection: Binding(
                        get: { bus.defaultDriverId ?? "" },
                        set: { pendingDriverId = $0; askConfirm = true })) {
                        Text("Nobody").tag("")
                        ForEach(fleetViewModel.activeDrivers) { driver in
                            Text(driver.name).tag(driver.id ?? "")
                        }
                    }
                }

                Section(header: Text("Cover")) {
                    if let cover = bus.cover {
                        LabeledContent("Driver", value: fleetViewModel.driverName(cover.driverId) ?? "?")
                        LabeledContent("Days", value: "\(cover.fromDate) – \(cover.untilDate)")
                        LabeledContent("Reason", value: cover.reason)
                        Button("End cover now", role: .destructive) {
                            fleetViewModel.endCover(of: bus)
                        }
                    } else {
                        Text("No cover. The regular driver drives.")
                            .foregroundColor(.secondary)
                    }
                    Button(bus.cover == nil ? String(localized: "Add cover") : String(localized: "Change cover")) {
                        onAddCover(bus)
                    }
                }
            }
            .navigationTitle(bus.name)
            .alert(confirmTitle(for: bus), isPresented: $askConfirm) {
                Button("Change") {
                    let id = pendingDriverId ?? ""
                    fleetViewModel.setRegularDriver(id.isEmpty ? nil : id, for: bus)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(confirmMessage(for: bus))
            }
        }
    }

    func confirmTitle(for bus: FleetBus) -> String {
        String(localized: "Change the regular driver of \(bus.name)?")
    }

    func confirmMessage(for bus: FleetBus) -> String {
        guard let id = pendingDriverId, !id.isEmpty else {
            return String(localized: "The bus will have no regular driver.")
        }
        let name = fleetViewModel.driverName(id) ?? ""
        if let other = fleetViewModel.regularBus(of: id), other.id != bus.id {
            return String(localized: "\(name) drives \(other.name) now. The two buses will swap drivers.")
        }
        return String(localized: "\(name) becomes the regular driver from today.")
    }
}

// Pick a free driver and the days they cover.
struct CoverEditorView: View {
    let bus: FleetBus
    let absence: DriverAbsence?
    @ObservedObject var fleetViewModel: FleetViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var driverId = ""
    @State private var from = Date()
    @State private var until = Date()
    @State private var reason = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Days")) {
                    DatePicker("From", selection: $from, displayedComponents: .date)
                    DatePicker("Until", selection: $until, in: from..., displayedComponents: .date)
                }
                Section(header: Text("Cover driver"),
                        footer: Text("Only drivers who aren't driving another bus and aren't off on the first day are listed.")) {
                    Picker("Driver", selection: $driverId) {
                        Text("Choose").tag("")
                        ForEach(fleetViewModel.freeDrivers(on: from)) { driver in
                            Text(driver.name).tag(driver.id ?? "")
                        }
                    }
                    TextField("Reason, e.g. regular driver sick", text: $reason)
                }
            }
            .navigationTitle("Cover for \(bus.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        fleetViewModel.addCover(to: bus, driverId: driverId, from: from, until: until,
                                                reason: reason, adminId: authViewModel.user?.uid ?? "",
                                                absence: absence)
                        dismiss()
                    }
                    .disabled(driverId.isEmpty)
                }
            }
            .onAppear {
                // From a driver's request: the same days and reason.
                if let absence = absence {
                    from = BusAssignment.startOfDay(absence.fromDate) ?? Date()
                    until = BusAssignment.startOfDay(absence.untilDate) ?? from
                    reason = absence.reason
                }
            }
        }
    }
}

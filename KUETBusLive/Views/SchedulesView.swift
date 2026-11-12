//
//  SchedulesView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The KUET bus timetable. Students see only student (Normal) trips.
//  Teachers and the admin see every trip. The admin can also add, edit and delete trips.
//  The chips at the top narrow the list to one route (the place the trip goes to).
//

import SwiftUI

struct SchedulesView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var scheduleViewModel = ScheduleViewModel()
    @State private var days: TripDays = TripDays.saturday.includes(Date()) ? .saturday : .sunToThu
    @State private var editingSchedule: BusSchedule?
    @State private var confirmReload = false
    @State private var showImport = false
    // nil: all routes. Otherwise the trips' place, e.g. "Rupsha".
    @State private var routeFilter: String?
    @EnvironmentObject var assistant: AssistantViewModel

    var role: UserRole {
        authViewModel.profile?.role ?? .student
    }

    var isAdmin: Bool {
        role == .admin
    }

    // Every place this person's trips go to, with its name in the app's language.
    var routeChoices: [(spot: String, name: String)] {
        let mine = scheduleViewModel.schedules.filter { $0.audience.canBoard(role) }
        let names = Dictionary(mine.map { ($0.spot, $0.spotDisplayName) }, uniquingKeysWith: { first, _ in first })
        return names.map { (spot: $0.key, name: $0.value) }.sorted { $0.name < $1.name }
    }

    var nextTrip: BusSchedule? {
        let trips = scheduleViewModel.schedules.filter { routeFilter == nil || $0.spot == routeFilter }
        return BusSchedule.nextTrip(in: trips, for: role)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DaysPicker(days: $days)
                }

                if routeChoices.count > 1 {
                    Section {
                        RouteChips(choices: routeChoices, selected: $routeFilter)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                if let next = nextTrip {
                    Section(header: Text("Next bus you can take today")) {
                        ScheduleRow(schedule: next)
                    }
                }

                ForEach(TripPeriod.allCases, id: \.self) { period in
                    let trips = scheduleViewModel.trips(for: role, days: days, period: period)
                        .filter { routeFilter == nil || $0.spot == routeFilter }
                    if !trips.isEmpty {
                        Section(header: Text(period.title)) {
                            ForEach(trips) { trip in
                                ScheduleRow(schedule: trip)
                                    .swipeActions {
                                        if isAdmin {
                                            Button("Delete", role: .destructive) {
                                                scheduleViewModel.delete(trip)
                                            }
                                            Button("Edit") {
                                                editingSchedule = trip
                                            }
                                            .tint(.orange)
                                        }
                                    }
                            }
                        }
                    }
                }

                Section {
                    if role == .student {
                        Text("Special trips are teacher buses, so they are hidden. Students can only ride Normal trips.")
                    } else if role == .teacher {
                        Text("Teachers can ride any bus, Normal or Special.")
                    }
                    if isAdmin && scheduleViewModel.schedules.isEmpty {
                        Button("Load official KUET timetable") {
                            scheduleViewModel.loadOfficialTimetable()
                        }
                    }
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            .navigationTitle("Bus Schedule")
            .toolbar {
                if isAdmin {
                    Menu {
                        Button("Add a trip") {
                            editingSchedule = BusSchedule.blank
                        }
                        Button("Reload official timetable") {
                            confirmReload = true
                        }
                        if assistant.isReady() {
                            Button("Import from text with assistant") {
                                showImport = true
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add or reload trips")
                }
            }
            .confirmationDialog("Replace every trip with the timetable shipped in the app?",
                                isPresented: $confirmReload, titleVisibility: .visible) {
                Button("Replace", role: .destructive) {
                    scheduleViewModel.loadOfficialTimetable()
                }
            }
            .sheet(isPresented: $showImport) {
                TimetableImportView(scheduleViewModel: scheduleViewModel)
            }
            .sheet(item: $editingSchedule) { schedule in
                ScheduleEditView(schedule: schedule, scheduleViewModel: scheduleViewModel)
            }
        }
        .onAppear {
            scheduleViewModel.startListening()
        }
        .onDisappear {
            scheduleViewModel.stopListening()
        }
    }
}

// "All routes", then one chip per place. @Binding: changes SchedulesView's filter.
struct RouteChips: View {
    let choices: [(spot: String, name: String)]
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(String(localized: "All routes"), isOn: selected == nil) { selected = nil }
                ForEach(choices, id: \.spot) { choice in
                    chip(choice.name, isOn: selected == choice.spot) {
                        selected = selected == choice.spot ? nil : choice.spot
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .animation(.snappy, value: selected)
        .sensoryFeedback(.selection, trigger: selected)
    }

    func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isOn ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundColor(isOn ? .white : .primary)
                .background(isOn ? AnyShapeStyle(MapTheme.accent) : AnyShapeStyle(.thinMaterial), in: Capsule())
                .overlay(Capsule().stroke(.primary.opacity(isOn ? 0 : 0.1)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// @Binding: switches the days shown by SchedulesView.
struct DaysPicker: View {
    @Binding var days: TripDays

    var body: some View {
        Picker("Days", selection: $days) {
            ForEach(TripDays.allCases, id: \.self) { days in
                Text(days.title).tag(days)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct ScheduleRow: View {
    let schedule: BusSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(schedule.tripName)
                    .font(.headline)
                Spacer()
                AudienceBadge(audience: schedule.audience)
            }
            Text("Leaves KUET \(BusSchedule.display(schedule.campusTime))")
                .font(.subheadline)
            Text("Leaves \(schedule.spotDisplayName) \(BusSchedule.display(schedule.spotTime))")
                .font(.subheadline)
            // Learned on this phone from buses seen leaving (smart suggestions).
            if let delay = RideHistory.shared.usualDelay(trip: schedule.title), delay > 0 {
                Label("Usually \(delay) min late", systemImage: "clock.arrow.circlepath")
                    .font(.footnote)
                    .foregroundColor(.orange)
            }
            if !schedule.remarks.isEmpty {
                Text(schedule.remarks)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct AudienceBadge: View {
    let audience: BusAudience

    var body: some View {
        Text(audience.title)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(audience.color.opacity(0.15))
            .foregroundColor(audience.color)
            .clipShape(Capsule())
    }
}

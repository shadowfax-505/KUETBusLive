//
//  SchedulesView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The KUET bus timetable. Students see only student (Normal) trips.
//  Teachers and the admin see every trip. The admin can also add, edit and delete trips.
//

import SwiftUI

struct SchedulesView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var scheduleViewModel = ScheduleViewModel()
    @State private var days: TripDays = TripDays.saturday.includes(Date()) ? .saturday : .sunToThu
    @State private var editingSchedule: BusSchedule?
    @State private var confirmReload = false

    var role: UserRole {
        authViewModel.profile?.role ?? .student
    }

    var isAdmin: Bool {
        role == .admin
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DaysPicker(days: $days)
                }

                if let next = scheduleViewModel.nextTrip(for: role) {
                    Section(header: Text("Next bus you can take today")) {
                        ScheduleRow(schedule: next)
                    }
                }

                ForEach(TripPeriod.allCases, id: \.self) { period in
                    let trips = scheduleViewModel.trips(for: role, days: days, period: period)
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

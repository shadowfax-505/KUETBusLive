//
//  ScheduleEditView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Transport admin: add or edit one trip. Times are typed in 24-hour format, e.g. "17:10".
//

import SwiftUI

struct ScheduleEditView: View {
    @ObservedObject var scheduleViewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BusSchedule

    init(schedule: BusSchedule, scheduleViewModel: ScheduleViewModel) {
        self.scheduleViewModel = scheduleViewModel
        _draft = State(initialValue: schedule)
    }

    var isNew: Bool {
        draft.id == nil
    }

    var canSave: Bool {
        !draft.tripName.isEmpty && !draft.spot.isEmpty
            && BusSchedule.isValidTime(draft.campusTime)
            && BusSchedule.isValidTime(draft.spotTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Trip")) {
                    TextField("Trip name, e.g. Normal-1", text: $draft.tripName)
                    AudiencePicker(audience: $draft.audience)
                    Picker("Days", selection: $draft.days) {
                        ForEach(TripDays.allCases, id: \.self) { days in
                            Text(days.title).tag(days)
                        }
                    }
                    Picker("Part of day", selection: $draft.period) {
                        ForEach(TripPeriod.allCases, id: \.self) { period in
                            Text(period.title).tag(period)
                        }
                    }
                }

                Section(header: Text("Times (24-hour, e.g. 17:10)")) {
                    TextField("Leaves KUET", text: $draft.campusTime)
                    TextField("Starting spot, e.g. Rupsha", text: $draft.spot)
                    TextField("Leaves starting spot", text: $draft.spotTime)
                }

                Section(header: Text("Remarks")) {
                    TextField("Route it takes back", text: $draft.remarks)
                }
            }
            .navigationTitle(isNew ? "New trip" : "Edit trip")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: draft.tripName) { _, newName in
                // "Special" trips are teacher buses, "Normal" trips are student buses.
                draft.audience = BusAudience.from(tripName: newName)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        scheduleViewModel.save(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

// @Binding: changes the audience stored in the parent's draft.
struct AudiencePicker: View {
    @Binding var audience: BusAudience

    var body: some View {
        Picker("Allocated to", selection: $audience) {
            ForEach(BusAudience.allCases, id: \.self) { audience in
                Text(audience.title).tag(audience)
            }
        }
        .pickerStyle(.segmented)
    }
}

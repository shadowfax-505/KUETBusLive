//
//  SpecialDaysView.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Admin: the special-days calendar. Marking exam days, holidays and events
//  lets the travel model learn their traffic separately, so "best place to
//  wait" stays accurate on days that don't look like a normal week.
//

import SwiftUI

struct SpecialDaysView: View {
    @ObservedObject private var store = SpecialDays.shared
    @State private var date = Date()
    @State private var kind = "exam"
    @State private var note = ""

    var upcoming: [SpecialDay] {
        let today = SpecialDay.id(for: Date())
        return store.days.filter { ($0.id ?? "") >= today }
    }

    var body: some View {
        Form {
            Section(header: Text("Add a day"),
                    footer: Text("Bus times on these days are learned on their own. Until there are a few trips, an ordinary day's times are used.")) {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Picker("Kind", selection: $kind) {
                    ForEach(SpecialDay.kinds, id: \.self) { kind in
                        Text(SpecialDay.title(kind)).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                TextField("Note (optional)", text: $note)
                Button("Add") {
                    store.save(date: date, kind: kind, note: note)
                    note = ""
                }
            }

            Section(header: Text("Coming up")) {
                if upcoming.isEmpty {
                    Text("No special days")
                        .foregroundStyle(.secondary)
                }
                ForEach(upcoming) { day in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(day.id ?? "") · \(SpecialDay.title(day.kind))")
                            .font(.body.monospacedDigit())
                        if !day.note.isEmpty {
                            Text(day.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.map { upcoming[$0] }.forEach(store.delete)
                }
            }
        }
        .navigationTitle("Special days")
        .onAppear { store.startListening() }
    }
}

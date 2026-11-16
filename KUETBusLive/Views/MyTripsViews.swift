//
//  MyTripsViews.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  "My trips" on the Schedule screen: the trips a rider pinned, the sheet to pin or
//  change one (days, which departure, reminder), and "Add to Calendar", which opens
//  the system's own event screen, so the app never needs access to the calendar.
//

import SwiftUI
import EventKit
import EventKitUI

struct MyTripRow: View {
    let trip: MyTrip
    let schedule: BusSchedule

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pin.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.displayTitle)
                    .font(.headline)
                Text(trip.leg == .campus
                     ? "Leaves KUET \(BusSchedule.display(schedule.campusTime))"
                     : "Leaves \(schedule.spotDisplayName) \(BusSchedule.display(schedule.spotTime))")
                    .font(.subheadline)
                Text(trip.remindMinutes > 0
                     ? "\(trip.daysText) · reminder \(trip.remindMinutes) min before"
                     : "\(trip.daysText) · no reminder")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct MyTripEditView: View {
    let schedule: BusSchedule
    @ObservedObject var myTrips: MyTripsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var trip: MyTrip
    @State private var showCalendar = false
    private let isPinned: Bool

    init(schedule: BusSchedule, myTrips: MyTripsViewModel) {
        self.schedule = schedule
        self.myTrips = myTrips
        let existing = myTrips.trip(for: schedule)
        isPinned = existing != nil
        _trip = State(initialValue: existing ?? MyTrip.new(for: schedule))
    }

    // Only the days this trip runs can be picked.
    private var runningDays: [String] {
        MyTrip.dayCodes(for: schedule.days)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScheduleRow(schedule: schedule)
                }

                Section("I take it") {
                    Picker("Departure", selection: $trip.leg) {
                        Text("From KUET, \(BusSchedule.display(schedule.campusTime))").tag(MyTrip.Leg.campus)
                        Text("From \(schedule.spotDisplayName), \(BusSchedule.display(schedule.spotTime))").tag(MyTrip.Leg.spot)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if runningDays.count > 1 {
                    Section("On these days") {
                        ForEach(runningDays, id: \.self) { code in
                            Toggle(dayName(code), isOn: dayBinding(code))
                        }
                    }
                }

                Section {
                    Picker("Remind me", selection: $trip.remindMinutes) {
                        ForEach(MyTrip.reminderChoices, id: \.self) { minutes in
                            Text(minutes == 0 ? String(localized: "Off") : String(localized: "\(minutes) min before"))
                                .tag(minutes)
                        }
                    }
                } footer: {
                    Text("Reminders come from this phone, every week on the days you picked.")
                }

                Section {
                    Button {
                        showCalendar = true
                    } label: {
                        Label("Add to Calendar", systemImage: "calendar.badge.plus")
                    }
                    if isPinned {
                        Button("Remove from My trips", role: .destructive) {
                            myTrips.remove(trip)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isPinned ? "My trip" : "Add to My trips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        myTrips.save(trip)
                        dismiss()
                    }
                    .disabled(trip.days.isEmpty)
                }
            }
            .sheet(isPresented: $showCalendar) {
                CalendarEventSheet(event: TripCalendar.event(for: schedule, trip: trip))
                    .ignoresSafeArea()
            }
        }
    }

    private func dayName(_ code: String) -> String {
        guard let weekday = MyTrip.weekday(of: code) else { return code }
        return BusAssignment.calendar.weekdaySymbols[weekday - 1]
    }

    private func dayBinding(_ code: String) -> Binding<Bool> {
        Binding {
            trip.days.contains(code)
        } set: { on in
            if on {
                trip.days = MyTrip.dayCodes.filter { trip.days.contains($0) || $0 == code }
            } else {
                trip.days.removeAll { $0 == code }
            }
        }
    }
}

// A weekly calendar event for a trip, on the picked days, starting at the next one.
enum TripCalendar {
    static let store = EKEventStore()

    static func event(for schedule: BusSchedule, trip: MyTrip, from now: Date = Date()) -> EKEvent {
        let event = EKEvent(eventStore: store)
        let time = trip.time(in: schedule)
        event.title = trip.leg == .campus
            ? String(localized: "\(schedule.tripName) from KUET")
            : String(localized: "\(schedule.tripName) from \(schedule.spotDisplayName)")
        event.location = trip.leg == .campus ? "KUET" : schedule.spotDisplayName
        event.notes = String(localized: "KUET Bus Live: \(schedule.displayTitle)")
        event.timeZone = BusAssignment.timeZone
        let start = nextStart(time: time, days: trip.days, after: now) ?? now
        event.startDate = start
        event.endDate = start.addingTimeInterval(30 * 60)
        let weekdays = trip.days.compactMap { MyTrip.weekday(of: $0) }.compactMap { EKWeekday(rawValue: $0) }
        if !weekdays.isEmpty {
            event.recurrenceRules = [EKRecurrenceRule(recurrenceWith: .weekly, interval: 1,
                                                      daysOfTheWeek: weekdays.map { EKRecurrenceDayOfWeek($0) },
                                                      daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil,
                                                      daysOfTheYear: nil, setPositions: nil, end: nil)]
        }
        if trip.remindMinutes > 0 {
            event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-trip.remindMinutes * 60)))
        }
        return event
    }

    // The next time in Dhaka, on one of the days, that the bus leaves.
    static func nextStart(time: String, days: [String], after now: Date) -> Date? {
        guard let minutes = BusSchedule.minutes(from: time) else { return nil }
        let calendar = BusAssignment.calendar
        let weekdays = Set(days.compactMap { MyTrip.weekday(of: $0) })
        for offset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                  weekdays.contains(calendar.component(.weekday, from: day)),
                  let start = calendar.date(byAdding: .minute, value: minutes, to: day),
                  start > now else { continue }
            return start
        }
        return nil
    }
}

// The system's "New Event" screen. It runs outside the app, so no calendar permission is asked.
struct CalendarEventSheet: UIViewControllerRepresentable {
    let event: EKEvent
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = TripCalendar.store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            dismiss()
        }
    }
}

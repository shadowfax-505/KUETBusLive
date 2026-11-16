//
//  MyTrip.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  "My trips": a timetable trip a rider usually takes, on the days they take it,
//  with an optional reminder before it leaves. Saved in users/{uid}/myTrips/{scheduleId},
//  with the same fields on Android, so pinned trips follow the person to any phone.
//

import Foundation
import FirebaseFirestore

struct MyTrip: Identifiable, Codable, Equatable {
    @DocumentID var id: String?    // the schedule document's ID
    var leg: Leg                   // which departure the rider takes
    var days: [String]             // "sun" ... "sat", from MyTrip.dayCodes
    var remindMinutes: Int         // minutes before it leaves; 0 means no reminder
    var createdAt: Date

    enum Leg: String, Codable, CaseIterable {
        case campus   // leaves KUET for the city
        case spot     // leaves the city spot for KUET
    }

    // Index + 1 is the Calendar weekday: 1 = Sunday ... 7 = Saturday.
    static let dayCodes = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
    static let reminderChoices = [0, 5, 10, 15, 20, 30, 45, 60]

    static func weekday(of code: String) -> Int? {
        dayCodes.firstIndex(of: code).map { $0 + 1 }
    }

    // The days a timetable trip runs, as day codes.
    static func dayCodes(for days: TripDays) -> [String] {
        switch days {
        case .sunToThu:
            return ["sun", "mon", "tue", "wed", "thu"]
        case .saturday:
            return ["sat"]
        }
    }

    // A new pin: every day the trip runs, from campus, reminded ten minutes before.
    static func new(for schedule: BusSchedule) -> MyTrip {
        MyTrip(id: schedule.id, leg: .campus, days: dayCodes(for: schedule.days),
               remindMinutes: 10, createdAt: Date())
    }

    // "07:00" for the chosen departure.
    func time(in schedule: BusSchedule) -> String {
        leg == .campus ? schedule.campusTime : schedule.spotTime
    }

    // When to remind, in Dhaka: the weekday, hour and minute, `remindMinutes` before
    // the bus leaves. A reminder before midnight moves to the day before.
    static func reminder(weekday: Int, time: String, minutesBefore: Int) -> DateComponents? {
        guard let leaves = BusSchedule.minutes(from: time) else { return nil }
        var total = leaves - minutesBefore
        var day = weekday
        if total < 0 {
            total += 24 * 60
            day = day == 1 ? 7 : day - 1
        }
        var parts = DateComponents()
        parts.calendar = BusAssignment.calendar
        parts.timeZone = BusAssignment.timeZone
        parts.weekday = day
        parts.hour = total / 60
        parts.minute = total % 60
        return parts
    }

    // "Sun–Thu", "Sat", or "Sun, Tue, Thu".
    var daysText: String {
        let ordered = MyTrip.dayCodes.filter { days.contains($0) }
        if ordered == MyTrip.dayCodes(for: .sunToThu) {
            return String(localized: "Sun to Thu")
        }
        let symbols = BusAssignment.calendar.shortWeekdaySymbols
        return ordered.compactMap { MyTrip.weekday(of: $0).map { symbols[$0 - 1] } }.joined(separator: ", ")
    }
}

extension BusSchedule {
    // What a reminder depends on, to notice timetable changes.
    var reminderKey: String {
        "\(id ?? "")|\(campusTime)|\(spotTime)|\(tripName)|\(spot)"
    }
}

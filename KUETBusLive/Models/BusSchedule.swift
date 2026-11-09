//
//  BusSchedule.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  One trip from the KUET transport timetable, stored in the "schedules" collection.
//  The transport admin keeps these up to date in the app, so a change reaches every
//  phone straight away.
//

import SwiftUI
import FirebaseFirestore

// Who a bus is allocated to. KUET runs "Normal" trips for students and
// "Special" trips for teachers.
enum BusAudience: String, Codable, CaseIterable {
    case student
    case teacher

    var title: String {
        switch self {
        case .student:
            return String(localized: "Student bus")
        case .teacher:
            return String(localized: "Teacher bus")
        }
    }

    var color: Color {
        switch self {
        case .student:
            return .blue
        case .teacher:
            return .purple
        }
    }

    // Teachers can ride any bus. Students can only ride student buses.
    func canBoard(_ role: UserRole) -> Bool {
        switch role {
        case .teacher, .driver, .admin:
            return true
        case .student:
            return self == .student
        }
    }

    // "Special-1 (AC)" -> teacher, "Normal-2" -> student
    static func from(tripName: String) -> BusAudience {
        tripName.lowercased().hasPrefix("special") ? .teacher : .student
    }
}

enum TripDays: String, Codable, CaseIterable {
    case sunToThu
    case saturday

    var title: String {
        switch self {
        case .sunToThu:
            return String(localized: "Sunday to Thursday")
        case .saturday:
            return String(localized: "Saturday")
        }
    }

    // Calendar weekdays: 1 = Sunday ... 5 = Thursday, 7 = Saturday. Friday has no buses.
    func includes(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch self {
        case .sunToThu:
            return (1...5).contains(weekday)
        case .saturday:
            return weekday == 7
        }
    }
}

enum TripPeriod: String, Codable, CaseIterable {
    case morning
    case noon
    case afternoon
    case night

    var title: String {
        switch self {
        case .morning:
            return String(localized: "Morning")
        case .noon:
            return String(localized: "Noon")
        case .afternoon:
            return String(localized: "Afternoon")
        case .night:
            return String(localized: "Night")
        }
    }
}

struct BusSchedule: Identifiable, Codable {
    @DocumentID var id: String?
    var tripName: String       // "Normal-1", "Special-1 (AC)"
    var audience: BusAudience
    var days: TripDays
    var period: TripPeriod
    var campusTime: String     // 24-hour time the bus leaves KUET, e.g. "06:30"
    var spot: String           // starting spot in the city, e.g. "Rupsha"
    var spotBn: String? = nil  // optional Bangla name of the spot, e.g. "রূপসা"
    var spotTime: String       // 24-hour time the bus leaves that spot
    var remarks: String

    // Saved on the bus document and shown on the map, e.g. "Normal-1 · Rupsha".
    var title: String {
        "\(tripName) · \(spot)"
    }

    // The starting spot in the app's language.
    var spotDisplayName: String {
        PlaceNames.display(spot, bangla: spotBn)
    }

    // "Normal-1 · রূপসা" in Bangla. Trip names such as Normal-1 stay as they are.
    var displayTitle: String {
        "\(tripName) · \(spotDisplayName)"
    }

    var runsToday: Bool {
        days.includes(Date())
    }

    // The trip still has a departure later today (from campus or from the city).
    var isUpcoming: Bool {
        isUpcoming(at: Date())
    }

    // Same check for any moment, so unit tests can use a fixed date and time.
    func isUpcoming(at date: Date) -> Bool {
        guard days.includes(date) else { return false }
        let now = BusSchedule.minutesNow(date)
        let times = [campusTime, spotTime].compactMap { BusSchedule.minutes(from: $0) }
        return times.contains { $0 >= now }
    }

    // The first trip (by campus time) this person may ride that still leaves later that day.
    static func nextTrip(in schedules: [BusSchedule], for role: UserRole, at date: Date = Date()) -> BusSchedule? {
        let sorted = schedules.sorted {
            (minutes(from: $0.campusTime) ?? 0) < (minutes(from: $1.campusTime) ?? 0)
        }
        return sorted.first { $0.audience.canBoard(role) && $0.isUpcoming(at: date) }
    }

    // "13:30" -> 810 minutes after midnight. Returns nil for anything that isn't a valid time.
    static func minutes(from time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0..<24).contains(hour),
              (0..<60).contains(minute) else {
            return nil
        }
        return hour * 60 + minute
    }

    static func minutesNow(_ date: Date = Date()) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func isValidTime(_ time: String) -> Bool {
        minutes(from: time) != nil
    }

    // "13:30" -> "1:30 PM"
    static func display(_ time: String) -> String {
        guard let total = minutes(from: time) else { return time }
        let hour = total / 60
        let minute = total % 60
        let suffix = hour < 12 ? "AM" : "PM"
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d ", hour12, minute) + suffix
    }

    // Starting point for a new trip in the editor.
    static var blank: BusSchedule {
        BusSchedule(tripName: "Normal-1", audience: .student, days: .sunToThu, period: .morning,
                    campusTime: "", spot: "", spotTime: "", remarks: "")
    }
}

//
//  FleetBus.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The transport office's own buses (Normal-1, Normal-2, Special-1 ...), kept in the
//  "fleet" collection, separate from "buses" (the live trips on the map). Ending a
//  trip deletes the live document, never the assignment.
//
//  Each fleet bus has a regular driver and, sometimes, a cover driver for a few days
//  (the regular driver is off sick, or has left and a replacement isn't fixed yet):
//
//      a driver set for this trip? -> that driver drives this trip only
//      cover active today?         -> the cover driver drives
//      otherwise                   -> the regular (default) driver drives
//      neither                     -> nobody: "No driver today"
//
//  Trip drivers are optional. Most buses have none, and then every trip goes to the
//  cover or regular driver as before.
//
//  Dates are days in Khulna (Asia/Dhaka), written "yyyy-MM-dd". The cover also keeps
//  the same range as two timestamps (start of the first day, start of the day after
//  the last), so the security rules can compare them with the request time.
//

import Foundation
import FirebaseFirestore

struct BusCover: Codable, Equatable {
    var driverId: String
    var fromDate: String          // "2026-11-10", first day of the cover
    var untilDate: String         // "2026-11-12", last day (inclusive)
    var start: Date               // 00:00 on fromDate in Dhaka
    var end: Date                 // 00:00 on the day after untilDate in Dhaka
    var reason: String
    var setBy: String             // the admin's uid
}

struct FleetBus: Identifiable, Codable {
    @DocumentID var id: String?   // "normal-1"
    var name: String              // "Normal-1", same as tripName in the timetable
    var defaultDriverId: String?
    var cover: BusCover?
    // A different driver for some trips: schedule document ID -> driver uid.
    var tripDrivers: [String: String]?
}

enum BusAssignment {
    // KUET is in Khulna, so "today" always means today in Bangladesh, whatever
    // time zone the phone is set to.
    static let timeZone = TimeZone(identifier: "Asia/Dhaka")!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    // 10 Nov 2026 at any time in Dhaka -> "2026-11-10".
    static func dayString(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    // "2026-11-10" -> 00:00 that day in Dhaka.
    static func startOfDay(_ day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    // Builds a cover from two days, with the timestamps the rules need.
    static func makeCover(driverId: String, from fromDate: Date, until untilDate: Date,
                          reason: String, setBy: String) -> BusCover? {
        let first = dayString(fromDate)
        let last = dayString(max(fromDate, untilDate))
        guard let start = startOfDay(first), let lastStart = startOfDay(last),
              let end = calendar.date(byAdding: .day, value: 1, to: lastStart) else { return nil }
        return BusCover(driverId: driverId, fromDate: first, untilDate: last,
                        start: start, end: end, reason: reason, setBy: setBy)
    }

    // Is the cover in force on this day? Days in "yyyy-MM-dd" form compare correctly as text.
    static func isCoverActive(_ cover: BusCover?, on date: Date) -> Bool {
        guard let cover = cover else { return false }
        let today = dayString(date)
        return cover.fromDate <= today && today <= cover.untilDate
    }

    // Who drives this bus on this day: the cover driver while a cover is active,
    // otherwise the regular driver. nil means nobody.
    static func driver(for bus: FleetBus, on date: Date) -> String? {
        if isCoverActive(bus.cover, on: date), let cover = bus.cover {
            return cover.driverId
        }
        return bus.defaultDriverId
    }

    // Who drives one trip of this bus: the driver set for that trip if there is one,
    // otherwise whoever drives the bus that day.
    static func driver(for bus: FleetBus, on date: Date, trip scheduleId: String?) -> String? {
        if let scheduleId = scheduleId, let tripDriver = bus.tripDrivers?[scheduleId] {
            return tripDriver
        }
        return driver(for: bus, on: date)
    }

    // The trips this driver drives on this day, on any bus, in timetable order.
    // On a day with no trips at all (Friday) every trip of the week is considered,
    // so a driver can still see their buses.
    static func trips(for driverId: String, fleet: [FleetBus], schedules: [BusSchedule],
                      on date: Date) -> [(bus: FleetBus, schedule: BusSchedule)] {
        let today = schedules.filter { $0.days.includes(date) }
        let candidates = today.isEmpty ? schedules : today
        return candidates.compactMap { schedule in
            guard let bus = fleet.first(where: { $0.name == schedule.tripName }),
                  driver(for: bus, on: date, trip: schedule.id) == driverId else { return nil }
            return (bus, schedule)
        }
        .sorted {
            (BusSchedule.minutes(from: $0.schedule.campusTime) ?? 0)
                < (BusSchedule.minutes(from: $1.schedule.campusTime) ?? 0)
        }
    }

    // The bus this driver drives on this day, if any.
    static func bus(for driverId: String, in fleet: [FleetBus], on date: Date) -> FleetBus? {
        fleet.first { driver(for: $0, on: date) == driverId }
    }

    // Approved drivers who don't drive any bus on this day and aren't off: they can cover.
    static func freeDrivers(_ drivers: [AppUser], fleet: [FleetBus], absentIds: Set<String>,
                            on date: Date) -> [AppUser] {
        let busy = Set(fleet.compactMap { driver(for: $0, on: date) })
        return drivers.filter { driver in
            guard let id = driver.id else { return false }
            return driver.approved && driver.isActive && !busy.contains(id) && !absentIds.contains(id)
        }
    }

    // "normal-1" for "Normal-1", "special-1-ac" for "Special-1 (AC)".
    static func fleetId(for name: String) -> String {
        let allowed = name.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return String(allowed).split(separator: "-").joined(separator: "-")
    }
}

// "I can't drive" from a driver, for one or more days. Saved in "driverAbsences".
struct DriverAbsence: Identifiable, Codable {
    @DocumentID var id: String?
    var driverId: String
    var driverName: String
    var fromDate: String         // "yyyy-MM-dd" in Dhaka
    var untilDate: String
    var reason: String
    var status: AbsenceStatus
    var createdAt: Date
    var coverDriverId: String?   // set by the admin when someone covers

    func includes(_ date: Date) -> Bool {
        let day = BusAssignment.dayString(date)
        return fromDate <= day && day <= untilDate
    }
}

enum AbsenceStatus: String, Codable {
    case open
    case covered
    case cancelled

    var title: String {
        switch self {
        case .open: return String(localized: "Waiting for the office")
        case .covered: return String(localized: "Cover arranged")
        case .cancelled: return String(localized: "Cancelled")
        }
    }
}

// One driven trip, kept as a history of who drove which bus and when. Saved in "trips".
struct TripRecord: Codable {
    var driverId: String
    var fleetBusId: String
    var scheduleId: String
    var routeId: String
    var startedAt: Date
    var endedAt: Date?
}

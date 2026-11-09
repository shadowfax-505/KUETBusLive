//
//  SharedTrip.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The small piece of the timetable the home screen widget needs. This file is
//  compiled into both the app and the widget, so it must not use Firebase.
//
//  The app saves the rider's trips and favourite stop in an App Group (a shared
//  UserDefaults that the app and its widget can both read). If the app hasn't saved
//  anything yet, the widget falls back to the timetable bundled in kuet_schedule.json.
//

import Foundation

struct SharedTrip: Codable, Hashable {
    var tripName: String     // "Normal-1"
    var spot: String         // "Rupsha"
    var days: String         // "sunToThu" or "saturday", same as TripDays
    var campusTime: String   // "06:30"

    var title: String {
        "\(tripName) · \(spot)"
    }

    // Students may only ride "Normal" trips. "Special" trips are for teachers.
    var isTeacherTrip: Bool {
        tripName.lowercased().hasPrefix("special")
    }

    // Does this trip run on the given day? 1 = Sunday ... 5 = Thursday, 7 = Saturday.
    func runs(on date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return days == "saturday" ? weekday == 7 : (1...5).contains(weekday)
    }

    // The moment the bus leaves campus on that day, or nil if the time is not valid.
    func departure(on date: Date) -> Date? {
        let parts = campusTime.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute) else {
            return nil
        }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date)
    }
}

// One trip with the exact time it leaves, used by the widget.
struct UpcomingTrip: Hashable {
    let trip: SharedTrip
    let leavesAt: Date
}

// The bus the rider is waiting for, saved by the app whenever a new ETA arrives.
struct LiveTripSnapshot: Codable {
    var busNumber: String       // "Normal-2 · Rupsha"
    var stopName: String        // the rider's stop
    var etaMinutes: Int
    var distanceKm: Double
    var crowd: String           // "unknown", "seats" or "full"
    var progress: TripProgress
    var busLat: Double
    var busLng: Double
    var updatedAt: Date

    // Older than 10 minutes: the bus probably finished or lost signal, so the
    // widget goes back to the timetable.
    var isFresh: Bool {
        Date().timeIntervalSince(updatedAt) < 10 * 60
    }

    var crowdText: String {
        switch crowd {
        case "seats": return String(localized: "Seats available")
        case "full": return String(localized: "Full")
        default: return String(localized: "No crowd report")
        }
    }
}

// The rider's route, for the map in the large widget.
struct SharedRoute: Codable {
    var name: String
    var stops: [SharedStop]
    var riderStopIndex: Int     // which stop is the rider's
}

enum SharedStore {
    // Must match the App Groups entitlement of both the app and the widget.
    static let appGroup = "group.KUETBusLive"

    private static let tripsKey = "widget.trips"
    private static let stopKey = "widget.favoriteStop"

    // Falls back to the normal UserDefaults if the App Group isn't available
    // (for example a build without the entitlement), so nothing crashes.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static var favoriteStop: String? {
        get { defaults.string(forKey: stopKey) }
        set { defaults.set(newValue, forKey: stopKey) }
    }

    private static let liveKey = "widget.liveTrip"
    private static let routeKey = "widget.route"

    static var liveTrip: LiveTripSnapshot? {
        get { decode(LiveTripSnapshot.self, key: liveKey) }
        set { encode(newValue, key: liveKey) }
    }

    static var route: SharedRoute? {
        get { decode(SharedRoute.self, key: routeKey) }
        set { encode(newValue, key: routeKey) }
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encode<T: Encodable>(_ value: T?, key: String) {
        if let value = value {
            defaults.set(try? JSONEncoder().encode(value), forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    // The trips this rider may take, saved by the app.
    static var trips: [SharedTrip] {
        get {
            guard let data = defaults.data(forKey: tripsKey) else { return [] }
            return (try? JSONDecoder().decode([SharedTrip].self, from: data)) ?? []
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: tripsKey)
        }
    }

    // Removes everything the app saved for the widget, for example after the account is deleted.
    static func clear() {
        for key in [tripsKey, stopKey, liveKey, routeKey] {
            defaults.removeObject(forKey: key)
        }
    }

    // The official timetable shipped inside the bundle (student trips only),
    // used when the app hasn't saved anything yet.
    static func bundledTrips() -> [SharedTrip] {
        struct File: Codable { let trips: [SharedTrip] }
        guard let url = Bundle.main.url(forResource: "kuet_schedule", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else {
            return []
        }
        return file.trips.filter { !$0.isTeacherTrip }
    }

    // The next departures after `date`, looking up to a week ahead (so Friday shows Saturday's bus).
    static func upcoming(from trips: [SharedTrip], after date: Date, limit: Int = 3) -> [UpcomingTrip] {
        var result = [UpcomingTrip]()
        for dayOffset in 0..<7 {
            guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            let todays = trips
                .filter { $0.runs(on: day) }
                .compactMap { trip -> UpcomingTrip? in
                    guard let leaves = trip.departure(on: day), leaves > date else { return nil }
                    return UpcomingTrip(trip: trip, leavesAt: leaves)
                }
                .sorted { $0.leavesAt < $1.leavesAt }
            // The same bus can be listed for two city spots at the same time; show it once per spot.
            for item in todays where !result.contains(item) {
                result.append(item)
                if result.count == limit { return result }
            }
        }
        return result
    }
}

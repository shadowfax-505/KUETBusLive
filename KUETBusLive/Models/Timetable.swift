//
//  Timetable.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The official KUET timetable shipped with the app as kuet_schedule.json.
//  The admin loads it into Firestore once, then edits trips in the app when KUET changes them.
//

import Foundation

struct TimetableFile: Codable {
    let source: String
    let updated: String
    let trips: [TimetableRow]
}

struct TimetableRow: Codable {
    let tripName: String
    let days: TripDays
    let period: TripPeriod
    let campusTime: String
    let spot: String
    let spotTime: String
    let remarks: String

    // The JSON has no audience field: it comes from the trip name.
    var schedule: BusSchedule {
        BusSchedule(tripName: tripName,
                    audience: BusAudience.from(tripName: tripName),
                    days: days,
                    period: period,
                    campusTime: campusTime,
                    spot: spot,
                    spotTime: spotTime,
                    remarks: remarks)
    }

    // JSON parsing: read the file from the app bundle and decode it.
    static func loadBundled() -> [BusSchedule] {
        guard let url = Bundle.main.url(forResource: "kuet_schedule", withExtension: "json") else {
            print("kuet_schedule.json is missing from the app bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(TimetableFile.self, from: data)
            return file.trips.map { $0.schedule }
        } catch {
            print("Error reading timetable: \(error)")
            return []
        }
    }
}

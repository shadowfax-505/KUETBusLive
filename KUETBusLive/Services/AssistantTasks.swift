//
//  AssistantTasks.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The four jobs the assistant can do, each with its prompt and a strict check of
//  the answer. Nothing the model writes is used until it passes these checks, and
//  nothing is posted or saved until a person approves it.
//
//  All of it runs on the phone. Even so, prompts carry only what the job needs:
//  a complaint goes in as its category, bus and text, never the sender's name,
//  email or KUET ID.
//

import Foundation

// MARK: - Admin: complaint triage

struct ComplaintTriage: Codable, Equatable {
    var category: String
    var urgency: String
    var summary: String
    var reply: String

    static let urgencies = ["low", "medium", "high"]

    var isValid: Bool {
        ComplaintCategory(rawValue: category) != nil && Self.urgencies.contains(urgency)
            && !summary.trimmingCharacters(in: .whitespaces).isEmpty
            && !reply.trimmingCharacters(in: .whitespaces).isEmpty
    }

    static let system = """
    You help the KUET transport office sort complaints about university buses.
    category is one of: late, driverBehaviour, overcrowding, busCondition, app, other.
    urgency is one of: low, medium, high (high only for safety problems or a bus that did not come).
    summary is one short sentence in your own words. reply is a short, polite reply from the
    transport office, written in plain English. Do not promise anything specific.
    """

    // Only the complaint itself: no name, email or ID of the person who sent it.
    static func prompt(for complaint: Complaint) -> String {
        var lines = ["Category chosen by the rider: \(complaint.category.rawValue)"]
        if let bus = complaint.busAndRoute { lines.append("Bus: \(bus)") }
        lines.append("Complaint: \(complaint.text)")
        return lines.joined(separator: "\n")
    }

}

// MARK: - Admin: announcement draft in English and Bangla

struct AnnouncementDraft: Codable, Equatable {
    var titleEn: String
    var bodyEn: String
    var titleBn: String
    var bodyBn: String

    var isValid: Bool {
        [titleEn, bodyEn, titleBn, bodyBn].allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            && titleEn.count <= 200 && titleBn.count <= 200
    }

    static let system = """
    You write short notices for KUET university bus riders from a note by the transport office.
    Reply with JSON only: {"titleEn": "...", "bodyEn": "...", "titleBn": "...", "bodyBn": "..."}.
    Titles are under 60 characters. Bodies are one to three plain sentences.
    The Bangla version says the same thing in natural Bangla. Do not add facts that are not in the note.
    """

    static func parse(_ text: String) -> AnnouncementDraft? {
        guard let draft = AssistantJSON.decode(AnnouncementDraft.self, from: text), draft.isValid else { return nil }
        return draft
    }
}

// MARK: - Rider: "Ask"

enum RiderQuestion {
    static let maxQuestionLength = 300
    static let minSecondsBetween: TimeInterval = 10

    static func system(languageName: String) -> String {
        """
        You answer questions from a KUET bus rider. Use ONLY the information below the line \
        "DATA". If the answer is not in the data, say you don't know and suggest checking the \
        timetable or asking the transport office. Answer in \(languageName), in one to three short \
        sentences. Times are in 12-hour format.
        """
    }

    // Everything the model may use: today's trips for this rider, their boarding point,
    // the buses running now with their ETAs, and the latest announcements.
    // The on-device model has a small context window (about 4,000 tokens for
    // instructions, prompt and answer together), so the data is kept short: only
    // trips still to come today, only the place asked about when one is named, and
    // the start of each announcement.
    static let maxTrips = 12
    static let maxNewsCharacters = 160

    static func prompt(question: String, now: Date, schedules: [BusSchedule], role: UserRole,
                       boarding: String?, liveBuses: [(name: String, eta: String?)],
                       announcements: [Announcement]) -> String {
        let mine = schedules.filter { $0.days.includes(now) && $0.audience.canBoard(role) }
        let spots = Dictionary(mine.map { ($0.spot, $0.spotBn) }, uniquingKeysWith: { first, _ in first })
            .map { (english: $0.key, bangla: $0.value) }
        let asked = TimetableAnswerer.place(in: question, spots: spots)
        let lastToday = TimetableAnswerer.kind(of: question) == .last
        let today = mine
            .filter { asked == nil || $0.spot == asked }
            .filter { lastToday || $0.isUpcoming(at: now) }
            .sorted { ($0.campusTime, $0.tripName) < ($1.campusTime, $1.tripName) }
            .prefix(maxTrips)
            .map { "- \($0.tripName): leaves KUET \(BusSchedule.display($0.campusTime)), leaves \($0.spot) \(BusSchedule.display($0.spotTime))\($0.remarks.isEmpty ? "" : " (\($0.remarks.prefix(60)))")" }
        let buses = liveBuses.prefix(6).map { "- \($0.name) is running now\($0.eta.map { ", reaches my stop in \($0)" } ?? "")" }
        let news = announcements.prefix(2).map { "- \($0.title.prefix(80)): \($0.body.prefix(maxNewsCharacters))" }
        let time = now.formatted(date: .abbreviated, time: .shortened)
        return """
        Question: \(question.prefix(maxQuestionLength))

        DATA
        Now: \(time)
        My boarding point: \(boarding ?? "not set")
        Trips I may take that are still to come today:
        \(today.isEmpty ? "- none today" : today.joined(separator: "\n"))
        Buses running now:
        \(buses.isEmpty ? "- none" : buses.joined(separator: "\n"))
        Latest announcements:
        \(news.isEmpty ? "- none" : news.joined(separator: "\n"))
        """
    }
}

// MARK: - Admin: timetable from pasted text

struct ImportedTrip: Codable, Hashable {
    var tripName: String
    var audience: String
    var days: String
    var period: String
    var campusTime: String
    var spot: String
    var spotTime: String
    var remarks: String?

    // Same fields as the app's timetable, with every value checked.
    var isValid: Bool {
        !tripName.trimmingCharacters(in: .whitespaces).isEmpty
            && BusAudience(rawValue: audience) != nil
            && TripDays(rawValue: days) != nil
            && TripPeriod(rawValue: period) != nil
            && BusSchedule.minutes(from: campusTime) != nil
            && BusSchedule.minutes(from: spotTime) != nil
            && !spot.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // Two rows are "the same trip" when these match; anything else that differs is a change.
    var key: String { "\(tripName)|\(days)|\(campusTime)|\(spot)" }

    init(_ schedule: BusSchedule) {
        tripName = schedule.tripName; audience = schedule.audience.rawValue; days = schedule.days.rawValue
        period = schedule.period.rawValue; campusTime = schedule.campusTime; spot = schedule.spot
        spotTime = schedule.spotTime; remarks = schedule.remarks
    }

    init(tripName: String, audience: String, days: String, period: String, campusTime: String,
         spot: String, spotTime: String, remarks: String?) {
        self.tripName = tripName; self.audience = audience; self.days = days; self.period = period
        self.campusTime = campusTime; self.spot = spot; self.spotTime = spotTime; self.remarks = remarks
    }
}

enum TimetableImport {
    static let system = """
    You turn the text of the KUET transport timetable into JSON for an app.
    Reply with JSON only: {"trips": [ ... ]}. Each trip is
    {"tripName": "Normal-1", "audience": "student" or "teacher", "days": "sunToThu" or "saturday",
     "period": "morning", "noon", "afternoon" or "night", "campusTime": "HH:mm" (24-hour, leaves KUET),
     "spot": "the city starting place", "spotTime": "HH:mm" (24-hour, leaves the spot), "remarks": "..."}.
    Trips whose name starts with "Special" are for teachers. Do not invent trips that are not in the text.
    """

    struct File: Codable { var trips: [ImportedTrip] }

    // nil unless every single trip is valid: one bad row means the admin should look again.
    static func parse(_ text: String) -> [ImportedTrip]? {
        guard let file = AssistantJSON.decode(File.self, from: text), !file.trips.isEmpty,
              file.trips.allSatisfy(\.isValid) else { return nil }
        // A missing remark and an empty one mean the same thing.
        return file.trips.map { trip in
            var trip = trip
            trip.remarks = trip.remarks ?? ""
            return trip
        }
    }

    struct Diff: Equatable {
        var added: [ImportedTrip] = []
        var removed: [ImportedTrip] = []
        var changed: [(old: ImportedTrip, new: ImportedTrip)] = []

        static func == (a: Diff, b: Diff) -> Bool {
            a.added == b.added && a.removed == b.removed
                && a.changed.map(\.old) == b.changed.map(\.old) && a.changed.map(\.new) == b.changed.map(\.new)
        }

        var isEmpty: Bool { added.isEmpty && removed.isEmpty && changed.isEmpty }
    }

    static func diff(current: [ImportedTrip], proposed: [ImportedTrip]) -> Diff {
        let old = Dictionary(current.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        let new = Dictionary(proposed.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        var diff = Diff()
        for trip in proposed where old[trip.key] == nil { diff.added.append(trip) }
        for trip in current where new[trip.key] == nil { diff.removed.append(trip) }
        for trip in proposed {
            if let before = old[trip.key], before != trip { diff.changed.append((before, trip)) }
        }
        return diff
    }
}

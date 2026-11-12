//
//  TimetableAnswerer.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Answers the common rider questions straight from the timetable, with no
//  language model: "next bus to Rupsha", "when does the last bus leave",
//  "first bus tomorrow", "which buses are running". The Ask screen uses it when
//  the on-device model is off, not available on the phone, or fails, so riders
//  always get an answer.
//
//  How a question is read:
//    1. Which trips?  A place from the timetable named in the question (English
//       or Bangla, ignoring case) narrows the trips to that place. A place after
//       "to" or "from" that isn't in the timetable gets an honest "no bus goes there".
//    2. Which one?    "last" / "শেষ" -> the last trip today, "first" / "প্রথম" -> the
//       first, "running" / "now" / "চলছে" -> the buses on the road, otherwise the
//       next trip that still leaves today.
//

import Foundation

enum TimetableAnswerer {
    enum Kind: Equatable {
        case next, first, last, running
    }

    static func kind(of question: String) -> Kind {
        let q = question.lowercased()
        if q.contains("last") || q.contains("শেষ") { return .last }
        if q.contains("first") || q.contains("প্রথম") { return .first }
        if q.contains("running") || q.contains("on the road") || q.contains("চলছে") { return .running }
        return .next
    }

    // The timetable place named in the question, if any. Longer names are tried first,
    // so "Royal Mor" wins over a shorter name inside it.
    static func place(in question: String, spots: [(english: String, bangla: String?)]) -> String? {
        let q = question.lowercased()
        let sorted = spots.sorted { $0.english.count > $1.english.count }
        for spot in sorted {
            if q.contains(spot.english.lowercased()) { return spot.english }
            if let bangla = spot.bangla, !bangla.isEmpty, q.contains(bangla) { return spot.english }
            let translated = PlaceNames.display(spot.english, bangla: nil, inBangla: true)
            if translated != spot.english, q.contains(translated) { return spot.english }
        }
        return nil
    }

    // The word(s) after "to" or "from" when they aren't a timetable place: "to Boyra?" -> "Boyra".
    static func unknownPlace(in question: String) -> String? {
        let words = question.split { $0 == " " || $0 == "?" || $0 == "," || $0 == "." }.map(String.init)
        guard let index = words.firstIndex(where: { ["to", "from"].contains($0.lowercased()) }),
              index + 1 < words.count else { return nil }
        let name = words[(index + 1)...].prefix(2)
            .filter { !["today", "tomorrow", "now", "please"].contains($0.lowercased()) }
            .joined(separator: " ")
        return name.isEmpty ? nil : name
    }

    // The answer, in the app's language. `liveBuses` are the names of buses running now.
    static func answer(question: String, now: Date, schedules: [BusSchedule], role: UserRole,
                       liveBuses: [String]) -> String {
        let mine = schedules.filter { $0.audience.canBoard(role) }
        let today = mine.filter { $0.days.includes(now) }
            .sorted { (BusSchedule.minutes(from: $0.campusTime) ?? 0) < (BusSchedule.minutes(from: $1.campusTime) ?? 0) }
        let spots = Dictionary(mine.map { ($0.spot, $0.spotBn) }, uniquingKeysWith: { first, _ in first })
            .map { (english: $0.key, bangla: $0.value) }

        let kind = kind(of: question)
        if kind == .running {
            return liveBuses.isEmpty
                ? String(localized: "No buses are running right now.")
                : String(localized: "Running now: \(liveBuses.map { PlaceNames.display($0) }.joined(separator: ", ")).")
        }

        let place = place(in: question, spots: spots)
        if place == nil, let unknown = unknownPlace(in: question) {
            let known = spots.map { PlaceNames.display($0.english, bangla: $0.bangla) }.sorted()
            return String(localized: "No bus you can take goes to \(unknown) in the timetable. Buses go to: \(known.joined(separator: ", ")).")
        }
        let trips = place.map { name in today.filter { $0.spot == name } } ?? today
        let placeName = place.map { name in PlaceNames.display(name, bangla: spots.first { $0.english == name }?.bangla) }

        guard !trips.isEmpty else {
            if let placeName = placeName {
                return String(localized: "There is no bus you can take to \(placeName) today.")
            }
            return String(localized: "There are no buses you can take today.")
        }

        switch kind {
        case .first:
            return sentence(String(localized: "The first bus today"), trips.first!)
        case .last:
            return sentence(String(localized: "The last bus today"), trips.last!)
        default:
            let nowMinutes = BusSchedule.minutesNow(now)
            guard let next = trips.first(where: { $0.isUpcoming(at: now) }) else {
                if let placeName = placeName {
                    return String(localized: "No more buses to \(placeName) today. The last one left KUET at \(BusSchedule.display(trips.last!.campusTime)).")
                }
                return String(localized: "No more buses today. The last one left KUET at \(BusSchedule.display(trips.last!.campusTime)).")
            }
            // Already gone from campus, but not yet from the city: say which way is still to come.
            if let campus = BusSchedule.minutes(from: next.campusTime), campus < nowMinutes {
                return String(localized: "\(next.displayTitle) has left KUET. It leaves \(next.spotDisplayName) at \(BusSchedule.display(next.spotTime)).")
            }
            return sentence(String(localized: "The next bus"), next)
        }
    }

    // "The next bus is Normal-2 · Rupsha: leaves KUET 1:15 PM, leaves Rupsha 2:00 PM."
    private static func sentence(_ lead: String, _ trip: BusSchedule) -> String {
        String(localized: "\(lead) is \(trip.displayTitle): leaves KUET \(BusSchedule.display(trip.campusTime)), leaves \(trip.spotDisplayName) \(BusSchedule.display(trip.spotTime)).")
    }
}

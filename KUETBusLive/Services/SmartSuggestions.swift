//
//  SmartSuggestions.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  "Smart suggestions": the app learns which bus a rider usually takes, on this
//  phone only, with a small frequency-and-recency model (no cloud, no machine
//  learning library). Everything here is plain Swift, so it can be unit tested.
//
//  1. Each time the rider follows a bus, gets an arrival alert, waves, or is next
//     to the bus at their boarding point, the app saves a RideEvent.
//  2. SuggestionScorer adds up those events for each trip:
//        score(trip) = sum of weight(event) over events for that trip, on the same
//                      kind of day, within 45 minutes of the trip's departure
//        weight(event) = 0.5 ^ (age in days / 21)          (half-life of 3 weeks)
//                        x 1.5 if it was at the same boarding point as now
//     plus 1 if the rider is standing near that boarding point right now.
//     The trip with the highest score is "Your usual bus".
//  3. DelayModel keeps a running average of how late each trip was seen to leave,
//     so the app can say "usually 3 min late".
//
//  A Core ML model could replace SuggestionScorer later (same inputs, same output),
//  once there is enough ride history to train one.
//

import Foundation

// Buses run Sunday to Thursday and on Saturday, with different timetables,
// so habits are learned separately for each kind of day.
enum DayType: String, Codable {
    case sunToThu
    case saturday
    case friday     // no buses

    init(_ date: Date, calendar: Calendar = .current) {
        switch calendar.component(.weekday, from: date) {
        case 7: self = .saturday
        case 6: self = .friday
        default: self = .sunToThu
        }
    }
}

enum RideEventKind: String, Codable {
    case followed      // tapped "Follow on Lock Screen"
    case alerted       // got an arrival alert
    case waved         // sent "I'm waiting here"
    case boarded       // was next to the bus at the boarding point
}

// One remembered moment. Plain fields only, so it could also be saved in Firestore
// (users/{uid}/rideHistory) and read on another phone, including Android.
struct RideEvent: Codable, Hashable, Identifiable {
    var id = UUID().uuidString
    var kind: RideEventKind
    var tripTitle: String        // "Normal-2 · Rupsha", the bus label
    var routeId: String
    var boardingKey: String      // "stop:Fulbarigate" or "place:p1"
    var boardingName: String     // shown on the card, e.g. "Home"
    var dayType: DayType
    var minuteOfDay: Int         // 0 ... 1439
    var date: Date
}

// A trip the rider could take today, as the scorer sees it.
struct TripCandidate: Hashable {
    var title: String            // "Normal-2 · Rupsha"
    var departureMinute: Int     // minute of the day it leaves (the next of campus / spot time)
}

struct Suggestion: Equatable {
    var trip: TripCandidate
    var score: Double
    var boardingKey: String
    var boardingName: String
}

enum SuggestionScorer {
    static let halfLifeDays = 21.0
    static let timeWindowMinutes = 45
    static let sameBoardingBonus = 1.5
    static let nearbyBonus = 1.0
    // A trip needs at least this score (about one recent ride) to be suggested.
    static let minimumScore = 0.5

    // 1 for an event today, 0.5 three weeks ago, 0.25 six weeks ago...
    static func recencyWeight(eventDate: Date, now: Date) -> Double {
        let ageDays = max(now.timeIntervalSince(eventDate) / 86_400, 0)
        return pow(0.5, ageDays / halfLifeDays)
    }

    static func score(_ trip: TripCandidate, events: [RideEvent], now: Date,
                      currentBoardingKey: String?, nearBoardingKey: String? = nil) -> Double {
        let today = DayType(now)
        var total = 0.0
        for event in events where event.tripTitle == trip.title
            && event.dayType == today
            && abs(event.minuteOfDay - trip.departureMinute) <= timeWindowMinutes {
            var weight = recencyWeight(eventDate: event.date, now: now)
            if let key = currentBoardingKey, key == event.boardingKey {
                weight *= sameBoardingBonus
            }
            total += weight
        }
        if total > 0, let near = nearBoardingKey,
           events.contains(where: { $0.tripTitle == trip.title && $0.boardingKey == near }) {
            total += nearbyBonus
        }
        return total
    }

    // The best trip among today's remaining trips, or nil (cold start, or no habit yet).
    // Ties go to the trip that leaves first, then to the name, so the answer never flickers.
    static func suggest(from trips: [TripCandidate], events: [RideEvent], now: Date,
                        currentBoardingKey: String?, nearBoardingKey: String? = nil) -> Suggestion? {
        let scored = trips.map { trip in
            (trip, score(trip, events: events, now: now,
                         currentBoardingKey: currentBoardingKey, nearBoardingKey: nearBoardingKey))
        }
        guard let best = scored
            .filter({ $0.1 >= minimumScore })
            .sorted(by: { a, b in
                if a.1 != b.1 { return a.1 > b.1 }
                if a.0.departureMinute != b.0.departureMinute { return a.0.departureMinute < b.0.departureMinute }
                return a.0.title < b.0.title
            })
            .first else { return nil }

        // Where the rider usually gets on this trip: the most common boarding point.
        let mine = events.filter { $0.tripTitle == best.0.title }
        let counts = Dictionary(grouping: mine, by: { $0.boardingKey })
        let usual = counts.max { a, b in
            a.value.count != b.value.count ? a.value.count < b.value.count : a.key > b.key
        }
        return Suggestion(trip: best.0, score: best.1,
                          boardingKey: usual?.key ?? currentBoardingKey ?? "",
                          boardingName: usual?.value.last?.boardingName ?? "")
    }
}

// How late each trip usually leaves, as a running average per trip and kind of day.
struct DelayModel: Codable, Equatable {
    struct Average: Codable, Equatable {
        var count = 0
        var meanMinutes = 0.0
    }

    var averages: [String: Average] = [:]

    // Only plausible observations count: a few minutes early to an hour late.
    static let acceptedRange = -10.0...60.0

    static func key(trip: String, dayType: DayType) -> String {
        "\(trip)|\(dayType.rawValue)"
    }

    // A new observation: the bus was seen leaving `minutesLate` after the timetable.
    mutating func record(trip: String, dayType: DayType, minutesLate: Double) {
        guard Self.acceptedRange.contains(minutesLate) else { return }
        let key = Self.key(trip: trip, dayType: dayType)
        var average = averages[key] ?? Average()
        average.count += 1
        // Running mean: no need to keep every observation.
        average.meanMinutes += (minutesLate - average.meanMinutes) / Double(average.count)
        averages[key] = average
    }

    // Whole minutes late, once there are at least two observations; otherwise nil.
    func usualDelay(trip: String, dayType: DayType) -> Int? {
        guard let average = averages[Self.key(trip: trip, dayType: dayType)], average.count >= 2 else {
            return nil
        }
        return Int(average.meanMinutes.rounded())
    }
}

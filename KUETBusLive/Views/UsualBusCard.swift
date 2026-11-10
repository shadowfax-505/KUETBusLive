//
//  UsualBusCard.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Smart suggestions on the map: "Your usual bus, Normal-2 · Rupsha at 8:10 from
//  Home, leaves in 12 min, usually 3 min late", with a one-tap Follow.
//  The suggestion comes from RideHistory (learned on this phone only).
//

import SwiftUI
import CoreLocation

struct UsualBusCard: View {
    let suggestion: Suggestion
    let schedule: BusSchedule
    let liveBus: Bus?
    let usualDelay: Int?
    let onFollow: () -> Void
    let onClose: () -> Void

    var minutesUntil: Int {
        max(suggestion.trip.departureMinute - BusSchedule.minutesNow(), 0)
    }

    // "Leaves in 12 min", or "Leaves in 4 h 29 min" for a later trip.
    var leavesText: String {
        let minutes = minutesUntil
        if minutes >= 60 {
            return String(localized: "Leaves in \(minutes / 60) h \(minutes % 60) min")
        }
        return String(localized: "Leaves in \(minutes) min")
    }

    var timeText: String {
        let hour = suggestion.trip.departureMinute / 60
        let minute = suggestion.trip.departureMinute % 60
        return BusSchedule.display(String(format: "%02d:%02d", hour, minute))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Your usual bus", systemImage: "sparkles")
                    .font(.caption.bold())
                    .foregroundColor(.accentColor)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .accessibilityLabel("Hide suggestion")
            }
            Text(suggestion.boardingName.isEmpty
                 ? String(localized: "\(schedule.displayTitle) at \(timeText)")
                 : String(localized: "\(schedule.displayTitle) at \(timeText) from \(PlaceNames.display(suggestion.boardingName))"))
                .font(.headline)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(liveBus != nil ? String(localized: "Running now") : leavesText)
                    if let delay = usualDelay, delay > 0 {
                        Text("Usually \(delay) min late")
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
                Button(liveBus != nil ? String(localized: "Follow") : String(localized: "Use this stop"),
                       action: onFollow)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .font(.subheadline)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
    }
}

// Picks today's trips the rider may take that haven't left yet, in the scorer's form.
enum UsualBusFinder {
    static func candidates(from schedules: [BusSchedule], role: UserRole,
                           now: Date = Date()) -> [(TripCandidate, BusSchedule)] {
        let nowMinute = BusSchedule.minutesNow(now)
        return schedules
            .filter { $0.days.includes(now) && $0.audience.canBoard(role) }
            .compactMap { schedule in
                // The next of the two departures (from campus or from the city) still ahead,
                // allowing 10 minutes for a bus that is running a little late.
                let times = [schedule.campusTime, schedule.spotTime]
                    .compactMap { BusSchedule.minutes(from: $0) }
                    .filter { $0 >= nowMinute - 10 }
                guard let next = times.min() else { return nil }
                return (TripCandidate(title: schedule.title, departureMinute: next), schedule)
            }
    }

    // "stop:Fulbarigate" or "place:p1" when the rider is within 300 m of it right now.
    static func nearbyKey(me: CLLocation?, stop: Stop?, places: [MyPlace]) -> String? {
        guard let me = me else { return nil }
        if let stop = stop,
           me.distance(from: CLLocation(latitude: stop.lat, longitude: stop.lng)) < 300 {
            return "stop:\(stop.name)"
        }
        for place in places where me.distance(from: CLLocation(latitude: place.lat, longitude: place.lng)) < 300 {
            if let id = place.id { return "place:\(id)" }
        }
        return nil
    }
}

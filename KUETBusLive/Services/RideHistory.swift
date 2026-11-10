//
//  RideHistory.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Keeps the rider's ride events (last 90 days) and the learned trip delays in a
//  small JSON file on this phone. If the rider turns on "Keep my ride history in my
//  account", new events are also copied to users/{uid}/rideHistory in Firestore, so
//  they follow the rider to a new phone. Off by default.
//
//  Profile > Reset what the app has learned deletes all of it.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class RideHistory: ObservableObject {
    static let shared = RideHistory()

    @Published private(set) var events: [RideEvent] = []
    @Published private(set) var delays = DelayModel()

    static let keepDays = 90.0
    // Profile switches.
    static let suggestionsOnKey = "smartSuggestionsOn"
    static let backupOnKey = "rideHistoryBackupOn"

    private struct SavedFile: Codable {
        var events: [RideEvent]
        var delays: DelayModel
    }

    private let fileURL: URL = {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("ride-history.json")
    }()

    private init() {
        load()
    }

    var suggestionsOn: Bool {
        UserDefaults.standard.object(forKey: Self.suggestionsOnKey) as? Bool ?? true
    }

    // MARK: - Learning

    // Saves one event. The same kind of event for the same trip is kept once a day,
    // so following and unfollowing a bus five times doesn't count five times.
    func record(_ kind: RideEventKind, tripTitle: String, routeId: String,
                boardingKey: String, boardingName: String, at date: Date = Date()) {
        guard suggestionsOn else { return }
        let calendar = Calendar.current
        if events.contains(where: { $0.kind == kind && $0.tripTitle == tripTitle
            && calendar.isDate($0.date, inSameDayAs: date) }) {
            return
        }
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let event = RideEvent(kind: kind, tripTitle: tripTitle, routeId: routeId,
                              boardingKey: boardingKey, boardingName: boardingName,
                              dayType: DayType(date), minuteOfDay: minute, date: date)
        events.append(event)
        pruneAndSave()
        backUp(event)
    }

    // A bus was first seen leaving, `minutesLate` after its timetable time.
    func recordDelay(trip: String, minutesLate: Double, at date: Date = Date()) {
        guard suggestionsOn else { return }
        delays.record(trip: trip, dayType: DayType(date), minutesLate: minutesLate)
        save()
    }

    func usualDelay(trip: String, at date: Date = Date()) -> Int? {
        delays.usualDelay(trip: trip, dayType: DayType(date))
    }

    // MARK: - Suggesting

    func suggestion(trips: [TripCandidate], now: Date = Date(),
                    currentBoardingKey: String?, nearBoardingKey: String?) -> Suggestion? {
        guard suggestionsOn else { return nil }
        return SuggestionScorer.suggest(from: trips, events: events, now: now,
                                        currentBoardingKey: currentBoardingKey,
                                        nearBoardingKey: nearBoardingKey)
    }

    // MARK: - Forgetting

    // Profile > Reset what the app has learned (and account deletion).
    func reset(uid: String?) {
        let old = events
        events = []
        delays = DelayModel()
        try? FileManager.default.removeItem(at: fileURL)
        if let uid = uid {
            let collection = Firestore.firestore().collection("users").document(uid).collection("rideHistory")
            for event in old {
                collection.document(event.id).delete()
            }
            // Also anything saved from another phone.
            collection.getDocuments { snapshot, _ in
                snapshot?.documents.forEach { $0.reference.delete() }
            }
        }
    }

    // MARK: - Saving

    private func pruneAndSave() {
        let cutoff = Date().addingTimeInterval(-Self.keepDays * 86_400)
        events.removeAll { $0.date < cutoff }
        save()
    }

    private func save() {
        let file = SavedFile(events: events, delays: delays)
        if let data = try? JSONEncoder().encode(file) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let file = try? JSONDecoder().decode(SavedFile.self, from: data) else { return }
        events = file.events
        delays = file.delays
    }

    // Optional copy in Firestore, so a new phone can learn from the old one's history.
    private func backUp(_ event: RideEvent) {
        guard UserDefaults.standard.bool(forKey: Self.backupOnKey),
              let uid = Auth.auth().currentUser?.uid else { return }
        try? Firestore.firestore().collection("users").document(uid)
            .collection("rideHistory").document(event.id).setData(from: event)
    }

    // On a new phone: bring back the events saved in the account.
    func restoreFromAccount(uid: String) {
        guard UserDefaults.standard.bool(forKey: Self.backupOnKey) else { return }
        Firestore.firestore().collection("users").document(uid).collection("rideHistory")
            .getDocuments { snapshot, _ in
                let saved = snapshot?.documents.compactMap { try? $0.data(as: RideEvent.self) } ?? []
                let known = Set(self.events.map(\.id))
                self.events.append(contentsOf: saved.filter { !known.contains($0.id) })
                self.pruneAndSave()
            }
    }
}

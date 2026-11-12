//
//  ScheduleViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Live bus timetable from Firestore. The transport admin edits it in the app,
//  so when KUET changes a trip every phone gets the new times straight away.
//

import Foundation
import FirebaseFirestore

class ScheduleViewModel: ObservableObject {
    @Published var schedules = [BusSchedule]()

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // Read: real-time updates, sorted by the time the bus leaves campus.
    func startListening() {
        guard listener == nil else { return }
        listener = db.collection("schedules").order(by: "campusTime").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error getting schedules: \(error)")
                return
            }
            self.schedules = snapshot?.documents.compactMap { document in
                try? document.data(as: BusSchedule.self)
            } ?? []
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }

    // Only the trips this person is allowed to ride, on the chosen days and part of the day.
    func trips(for role: UserRole, days: TripDays, period: TripPeriod) -> [BusSchedule] {
        schedules.filter { trip in
            trip.audience.canBoard(role) && trip.days == days && trip.period == period
        }
    }

    // The next trip today this person can ride.
    func nextTrip(for role: UserRole) -> BusSchedule? {
        BusSchedule.nextTrip(in: schedules, for: role)
    }

    // Add a new trip, or Update an existing one (it already has a document ID).
    func save(_ schedule: BusSchedule) {
        do {
            if let id = schedule.id {
                try db.collection("schedules").document(id).setData(from: schedule)
            } else {
                _ = try db.collection("schedules").addDocument(from: schedule)
            }
        } catch {
            print("Error saving schedule: \(error)")
        }
    }

    // Delete
    func delete(_ schedule: BusSchedule) {
        guard let id = schedule.id else { return }
        db.collection("schedules").document(id).delete { error in
            if let error = error {
                print("Error deleting schedule: \(error)")
            }
        }
    }

    // Replaces every trip with the official timetable from kuet_schedule.json, in one batch.
    func loadOfficialTimetable() {
        let trips = TimetableRow.loadBundled()
        guard !trips.isEmpty else { return }

        let batch = db.batch()
        for old in schedules {
            if let id = old.id {
                batch.deleteDocument(db.collection("schedules").document(id))
            }
        }
        for trip in trips {
            do {
                try batch.setData(from: trip, forDocument: db.collection("schedules").document())
            } catch {
                print("Error adding trip: \(error)")
            }
        }
        batch.commit { error in
            if let error = error {
                print("Error loading timetable: \(error)")
            }
        }
    }
}

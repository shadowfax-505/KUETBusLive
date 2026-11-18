//
//  MyTripsViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Reads and writes the rider's pinned trips, and keeps a weekly local reminder for
//  each pinned day. Reminders are rebuilt from the pins and the live timetable every
//  time either changes, so a timetable change moves the reminders too.
//

import Foundation
import FirebaseFirestore
import UserNotifications

class MyTripsViewModel: ObservableObject {
    @Published var trips: [MyTrip] = []
    @Published var errorMessage = ""

    static let reminderPrefix = "mytrip-"

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var uid: String?

    func startListening(uid: String) {
        guard listener == nil || self.uid != uid else { return }
        listener?.remove()
        self.uid = uid
        listener = collection(uid).addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("Could not load my trips: \(error)")
                return
            }
            self?.trips = snapshot?.documents.compactMap { try? $0.data(as: MyTrip.self) } ?? []
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func trip(for schedule: BusSchedule) -> MyTrip? {
        trips.first { $0.id == schedule.id }
    }

    func save(_ trip: MyTrip) {
        guard let uid, let id = trip.id else { return }
        if trip.remindMinutes > 0 {
            NotificationManager.shared.requestPermission()
        }
        do {
            try collection(uid).document(id).setData(from: trip) { [weak self] error in
                if let error = error {
                    self?.errorMessage = String(localized: "Could not save the trip: \(error.localizedDescription)")
                }
            }
        } catch {
            errorMessage = String(localized: "Could not save the trip: \(error.localizedDescription)")
        }
    }

    func remove(_ trip: MyTrip) {
        guard let uid, let id = trip.id else { return }
        collection(uid).document(id).delete()
    }

    private func collection(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("myTrips")
    }

    // MARK: - Reminders

    // Replaces every "My trips" reminder with one weekly reminder per pinned day.
    // A trip the admin removed from the timetable gets no reminder.
    // Until Firestore has sent the timetable, nothing is known yet, so the reminders stay.
    // Once it has, an empty timetable clears them like any other trip that went away.
    static func scheduleReminders(trips: [MyTrip], schedules: [BusSchedule], timetableLoaded: Bool) {
        guard timetableLoaded else { return }
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix(reminderPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for request in reminderRequests(trips: trips, schedules: schedules) {
                center.add(request)
            }
        }
    }

    // Signing out takes this account's reminders off the phone, so the next person
    // to use it isn't told about someone else's trips.
    static func removeReminders() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix(reminderPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
        }
    }

    static func reminderRequests(trips: [MyTrip], schedules: [BusSchedule]) -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []
        for trip in trips where trip.remindMinutes > 0 {
            guard let schedule = schedules.first(where: { $0.id == trip.id }), let id = trip.id else { continue }
            let time = trip.time(in: schedule)
            for code in trip.days {
                guard let weekday = MyTrip.weekday(of: code),
                      let when = MyTrip.reminder(weekday: weekday, time: time, minutesBefore: trip.remindMinutes) else {
                    continue
                }
                let content = UNMutableNotificationContent()
                content.title = schedule.displayTitle
                content.body = trip.leg == .campus
                    ? String(localized: "Leaves KUET at \(BusSchedule.display(time)), in \(trip.remindMinutes) min.")
                    : String(localized: "Leaves \(schedule.spotDisplayName) at \(BusSchedule.display(time)), in \(trip.remindMinutes) min.")
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
                requests.append(UNNotificationRequest(identifier: "\(reminderPrefix)\(id)-\(code)",
                                                      content: content, trigger: trigger))
            }
        }
        return requests
    }
}

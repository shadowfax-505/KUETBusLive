//
//  FleetViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Bus assignment. The admin sets each bus's regular driver, adds cover when a driver
//  is off, answers "I can't drive" requests and deactivates drivers who left.
//  Drivers use it to see their bus for today and to send "I can't drive".
//  The rules in firestore.rules check every write again on the server.
//

import Foundation
import FirebaseFirestore

class FleetViewModel: ObservableObject {
    @Published var fleet = [FleetBus]()
    @Published var drivers = [AppUser]()          // admin only
    @Published var absences = [DriverAbsence]()   // admin: all; driver: their own
    @Published var errorMessage = ""

    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []

    // MARK: - Listening

    func listenAsAdmin() {
        stopListening()
        listenToFleet()
        listeners.append(db.collection("users").whereField("role", isEqualTo: UserRole.driver.rawValue)
            .addSnapshotListener { snapshot, _ in
                self.drivers = (snapshot?.documents.compactMap { try? $0.data(as: AppUser.self) } ?? [])
                    .sorted { $0.name < $1.name }
            })
        listeners.append(db.collection("driverAbsences").addSnapshotListener { snapshot, _ in
            self.absences = (snapshot?.documents.compactMap { try? $0.data(as: DriverAbsence.self) } ?? [])
                .sorted { $0.createdAt > $1.createdAt }
        })
    }

    func listenAsDriver(uid: String) {
        stopListening()
        listenToFleet()
        listeners.append(db.collection("driverAbsences").whereField("driverId", isEqualTo: uid)
            .addSnapshotListener { snapshot, _ in
                self.absences = (snapshot?.documents.compactMap { try? $0.data(as: DriverAbsence.self) } ?? [])
                    .sorted { $0.createdAt > $1.createdAt }
            })
    }

    private func listenToFleet() {
        listeners.append(db.collection("fleet").addSnapshotListener { snapshot, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            self.fleet = (snapshot?.documents.compactMap { try? $0.data(as: FleetBus.self) } ?? [])
                .sorted { $0.name < $1.name }
        })
    }

    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners = []
    }

    // MARK: - Reading

    func driverName(_ id: String?) -> String? {
        guard let id = id else { return nil }
        return drivers.first { $0.id == id }?.name
    }

    var activeDrivers: [AppUser] {
        drivers.filter { $0.approved && $0.isActive }
    }

    var openAbsences: [DriverAbsence] {
        absences.filter { $0.status == .open }
    }

    // Drivers who can cover on a day: approved, active, not driving and not off.
    func freeDrivers(on date: Date) -> [AppUser] {
        let absent = Set(absences.filter { $0.status != .cancelled && $0.includes(date) }.map(\.driverId))
        return BusAssignment.freeDrivers(drivers, fleet: fleet, absentIds: absent, on: date)
    }

    // The bus a driver is the regular driver of, if any.
    func regularBus(of driverId: String) -> FleetBus? {
        fleet.first { $0.defaultDriverId == driverId }
    }

    // MARK: - Admin: fleet

    // First time only: one fleet bus for each bus name in the timetable (Normal-1, Normal-2 ...).
    func createFleet(from schedules: [BusSchedule]) {
        let names = Set(schedules.map(\.tripName))
        for name in names.sorted() where !fleet.contains(where: { $0.name == name }) {
            let bus = FleetBus(name: name, defaultDriverId: nil, cover: nil)
            try? db.collection("fleet").document(BusAssignment.fleetId(for: name)).setData(from: bus)
        }
    }

    // Permanent change of a bus's regular driver. If that driver was regular on another
    // bus, the two buses swap drivers, so nobody is regular on two buses.
    func setRegularDriver(_ driverId: String?, for bus: FleetBus) {
        guard let busId = bus.id else { return }
        let batch = db.batch()
        if let driverId = driverId, let other = regularBus(of: driverId), let otherId = other.id, otherId != busId {
            batch.updateData(["defaultDriverId": bus.defaultDriverId ?? NSNull()],
                             forDocument: db.collection("fleet").document(otherId))
        }
        batch.updateData(["defaultDriverId": driverId ?? NSNull()], forDocument: db.collection("fleet").document(busId))
        batch.commit { error in
            if let error = error { self.errorMessage = error.localizedDescription }
        }
    }

    // A temporary replacement for some days. Also marks the matching request as covered.
    func addCover(to bus: FleetBus, driverId: String, from: Date, until: Date, reason: String,
                  adminId: String, absence: DriverAbsence? = nil) {
        guard let busId = bus.id,
              let cover = BusAssignment.makeCover(driverId: driverId, from: from, until: until,
                                                  reason: reason, setBy: adminId),
              let encoded = try? Firestore.Encoder().encode(cover) else { return }
        db.collection("fleet").document(busId).updateData(["cover": encoded]) { error in
            if let error = error { self.errorMessage = error.localizedDescription }
        }
        if let absenceId = absence?.id {
            db.collection("driverAbsences").document(absenceId)
                .updateData(["status": AbsenceStatus.covered.rawValue, "coverDriverId": driverId])
        }
    }

    // The regular driver is back early, or the cover was a mistake.
    func endCover(of bus: FleetBus) {
        guard let busId = bus.id else { return }
        db.collection("fleet").document(busId).updateData(["cover": FieldValue.delete()])
    }

    // MARK: - Admin: drivers

    // A driver who left the job: blocked at once, their running trip ends, and they are
    // removed from every bus, which then shows "No driver today" until someone is assigned.
    func deactivate(_ driver: AppUser) {
        guard let driverId = driver.id else { return }
        db.collection("users").document(driverId).updateData(["isApproved": false, "active": false])
        for bus in fleet {
            guard let busId = bus.id else { continue }
            if bus.defaultDriverId == driverId {
                db.collection("fleet").document(busId).updateData(["defaultDriverId": NSNull()])
            }
            if bus.cover?.driverId == driverId {
                db.collection("fleet").document(busId).updateData(["cover": FieldValue.delete()])
            }
        }
        // Their live bus disappears from every map.
        db.collection("buses").whereField("driverId", isEqualTo: driverId).getDocuments { snapshot, _ in
            snapshot?.documents.forEach { $0.reference.delete() }
        }
    }

    func reactivate(_ driver: AppUser) {
        guard let driverId = driver.id else { return }
        db.collection("users").document(driverId).updateData(["isApproved": true, "active": true])
    }

    // MARK: - Driver: "I can't drive"

    func requestAbsence(driverId: String, driverName: String, from: Date, until: Date, reason: String,
                        completion: @escaping (String?) -> Void) {
        let absence = DriverAbsence(driverId: driverId, driverName: driverName,
                                    fromDate: BusAssignment.dayString(from),
                                    untilDate: BusAssignment.dayString(max(from, until)),
                                    reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
                                    status: .open, createdAt: Date(), coverDriverId: nil)
        do {
            _ = try db.collection("driverAbsences").addDocument(from: absence) { error in
                completion(error?.localizedDescription)
            }
        } catch {
            completion(error.localizedDescription)
        }
    }

    func cancelAbsence(_ absence: DriverAbsence) {
        guard let id = absence.id else { return }
        db.collection("driverAbsences").document(id).delete()
    }
}

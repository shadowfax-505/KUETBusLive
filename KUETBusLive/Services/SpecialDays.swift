//
//  SpecialDays.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  The special-days calendar: exam weeks, holidays and events, kept by the
//  transport admin in specialDays/{yyyy-MM-dd}. On those days traffic and riders
//  differ, so the travel model learns them as their own kind of day.
//

import Foundation
import FirebaseFirestore

struct SpecialDay: Identifiable, Codable, Equatable {
    @DocumentID var id: String?   // "2026-12-01"
    var kind: String              // "exam", "holiday" or "event"
    var note: String

    static let kinds = ["exam", "holiday", "event"]

    static func title(_ kind: String) -> String {
        switch kind {
        case "exam": return String(localized: "Exams")
        case "holiday": return String(localized: "Holiday")
        default: return String(localized: "Event")
        }
    }

    static func id(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", locale: Locale(identifier: "en_US_POSIX"),
                      parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

final class SpecialDays: ObservableObject {
    static let shared = SpecialDays()

    @Published private(set) var days: [SpecialDay] = []
    private var listener: ListenerRegistration?
    private lazy var db = Firestore.firestore()

    // nil on an ordinary day.
    func kind(on date: Date) -> String? {
        let id = SpecialDay.id(for: date)
        return days.first { $0.id == id }?.kind
    }

    func startListening() {
        guard listener == nil else { return }
        listener = db.collection("specialDays").addSnapshotListener { snapshot, _ in
            self.days = (snapshot?.documents.compactMap { try? $0.data(as: SpecialDay.self) } ?? [])
                .sorted { ($0.id ?? "") < ($1.id ?? "") }
        }
    }

    // Admin only (the rules check).
    func save(date: Date, kind: String, note: String) {
        let day = SpecialDay(kind: kind, note: String(note.prefix(100)))
        try? db.collection("specialDays").document(SpecialDay.id(for: date)).setData(from: day)
    }

    func delete(_ day: SpecialDay) {
        guard let id = day.id else { return }
        db.collection("specialDays").document(id).delete()
    }

    // For tests and previews.
    func set(_ days: [SpecialDay]) {
        self.days = days
    }
}

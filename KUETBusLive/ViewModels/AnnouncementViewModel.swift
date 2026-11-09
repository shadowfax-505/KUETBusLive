//
//  AnnouncementViewModel.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Live list of announcements, newest first. The admin can post and delete them.
//  Each phone remembers when the list was last opened, so the tab can show
//  how many announcements are new (the unread badge).
//

import Foundation
import FirebaseFirestore

class AnnouncementViewModel: ObservableObject {
    @Published var announcements = [Announcement]()
    // When this phone last opened the announcements, saved between launches.
    @Published var lastSeen: Date

    static let lastSeenKey = "announcementsLastSeen"

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init() {
        let saved = UserDefaults.standard.double(forKey: Self.lastSeenKey)
        lastSeen = Date(timeIntervalSince1970: saved)
    }

    var latest: Announcement? {
        announcements.first
    }

    var unreadCount: Int {
        announcements.filter { $0.createdAt > lastSeen }.count
    }

    // Read: newest first, updated live when the admin posts.
    func startListening() {
        guard listener == nil else { return }
        listener = db.collection("announcements")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error getting announcements: \(error)")
                    return
                }
                self.announcements = snapshot?.documents.compactMap { document in
                    try? document.data(as: Announcement.self)
                } ?? []
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // Opening the list, or closing the banner, clears the badge.
    func markAllRead() {
        lastSeen = Date()
        UserDefaults.standard.set(lastSeen.timeIntervalSince1970, forKey: Self.lastSeenKey)
    }

    // Add (admin only, the security rules check this too)
    func post(title: String, body: String, routeName: String?, postedBy: String,
              completion: @escaping (String?) -> Void) {
        let announcement = Announcement(title: title, body: body, createdAt: Date(),
                                        postedBy: postedBy, routeName: routeName)
        do {
            _ = try db.collection("announcements").addDocument(from: announcement) { error in
                completion(error?.localizedDescription)
            }
        } catch {
            completion(error.localizedDescription)
        }
    }

    // Delete (admin only)
    func delete(_ announcement: Announcement) {
        guard let id = announcement.id else { return }
        db.collection("announcements").document(id).delete { error in
            if let error = error {
                print("Error deleting announcement: \(error)")
            }
        }
    }
}

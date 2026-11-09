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
//  Riders can also hide single announcements from their own list. The hidden
//  IDs are kept on this phone only, separately for each signed-in account.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class AnnouncementViewModel: ObservableObject {
    @Published var announcements = [Announcement]()
    // When this phone last opened the announcements, saved between launches.
    @Published var lastSeen: Date

    // Announcements this person swiped away. Only their own list changes.
    @Published var hiddenIds: Set<String> = []

    static let lastSeenKey = "announcementsLastSeen"
    // Profile > "Show news and announcements". Off hides the badge and the map banner.
    static let showNewsKey = "showAnnouncements"

    // "hiddenAnnouncements.<uid>", so two people sharing a phone keep separate lists.
    static func hiddenKey(for uid: String) -> String {
        "hiddenAnnouncements.\(uid)"
    }

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init() {
        let saved = UserDefaults.standard.double(forKey: Self.lastSeenKey)
        lastSeen = Date(timeIntervalSince1970: saved)
    }

    // The list without the ones this person hid.
    var visibleAnnouncements: [Announcement] {
        announcements.filter { !isHidden($0) }
    }

    var hiddenCount: Int {
        announcements.filter { isHidden($0) }.count
    }

    var latest: Announcement? {
        visibleAnnouncements.first
    }

    var unreadCount: Int {
        visibleAnnouncements.filter { $0.createdAt > lastSeen }.count
    }

    func isHidden(_ announcement: Announcement) -> Bool {
        guard let id = announcement.id else { return false }
        return hiddenIds.contains(id)
    }

    // Swipe to hide: removes it from this person's list only.
    func hide(_ announcement: Announcement) {
        guard let id = announcement.id else { return }
        hiddenIds.insert(id)
        saveHidden()
    }

    // "Show hidden" lets the person bring one back.
    func unhide(_ announcement: Announcement) {
        guard let id = announcement.id else { return }
        hiddenIds.remove(id)
        saveHidden()
    }

    private func loadHidden() {
        guard let uid = Auth.auth().currentUser?.uid else {
            hiddenIds = []
            return
        }
        let saved = UserDefaults.standard.stringArray(forKey: Self.hiddenKey(for: uid)) ?? []
        hiddenIds = Set(saved)
    }

    private func saveHidden() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        UserDefaults.standard.set(Array(hiddenIds), forKey: Self.hiddenKey(for: uid))
    }

    // Read: newest first, updated live when the admin posts.
    func startListening() {
        guard listener == nil else { return }
        loadHidden()
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

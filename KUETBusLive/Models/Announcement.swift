//
//  Announcement.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  One document in the "announcements" collection, posted by the transport admin,
//  e.g. "Normal-2 is late today" or "No buses on Friday".
//

import Foundation
import FirebaseFirestore

struct Announcement: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var body: String
    var createdAt: Date
    var postedBy: String       // the admin's name
    var routeName: String?     // optional: the route this is about

    // "Just now", "5 minutes ago", "yesterday" and so on.
    // A post from the last minute reads "Just now". Without this a fresh post,
    // or one stamped a moment ahead by another phone's clock, read "in 0 seconds".
    var timeText: String {
        let now = Date()
        if now.timeIntervalSince(createdAt) < 60 {
            return String(localized: "Just now")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: now)
    }
}

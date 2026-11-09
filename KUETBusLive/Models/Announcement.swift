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

    // "5 min ago", "yesterday" and so on.
    var timeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

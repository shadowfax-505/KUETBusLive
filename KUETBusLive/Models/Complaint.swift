//
//  Complaint.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  One document in the "complaints" collection: a problem a rider or driver
//  reported from Settings > Help & feedback > Report a problem. Only the transport admin can
//  change its status or reply. Categories and statuses are saved as plain
//  strings, so an Android app can read the same documents.
//

import Foundation
import FirebaseFirestore

enum ComplaintCategory: String, Codable, CaseIterable, Identifiable {
    case late            // bus late or didn't come
    case driverBehaviour
    case overcrowding
    case busCondition
    case app             // a problem with this app
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .late: return String(localized: "Bus late / didn't come")
        case .driverBehaviour: return String(localized: "Driver behaviour")
        case .overcrowding: return String(localized: "Overcrowding")
        case .busCondition: return String(localized: "Bus condition")
        case .app: return String(localized: "App problem")
        case .other: return String(localized: "Other")
        }
    }

    var icon: String {
        switch self {
        case .late: return "clock.badge.exclamationmark"
        case .driverBehaviour: return "person.fill.questionmark"
        case .overcrowding: return "person.3.fill"
        case .busCondition: return "bus"
        case .app: return "iphone"
        case .other: return "ellipsis.bubble"
        }
    }
}

enum ComplaintStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case inReview
    case resolved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open: return String(localized: "Open")
        case .inReview: return String(localized: "In review")
        case .resolved: return String(localized: "Resolved")
        }
    }

    var icon: String {
        switch self {
        case .open: return "envelope.badge"
        case .inReview: return "magnifyingglass"
        case .resolved: return "checkmark.seal.fill"
        }
    }
}

struct Complaint: Identifiable, Codable {
    @DocumentID var id: String?
    var uid: String              // who sent it
    var userName: String
    var userRole: String         // "student", "teacher" or "driver"
    var category: ComplaintCategory
    var routeName: String?       // optional: which route
    var busName: String?         // optional: which bus, e.g. "Normal-2"
    var tripTime: Date?          // optional: when it happened
    var text: String
    var createdAt: Date
    var status: ComplaintStatus
    var adminReply: String?
    var repliedAt: Date?
    var readByAdmin: Bool        // false until the admin opens it (the inbox badge)

    // Longest message the rules accept.
    static let maxTextLength = 2000

    // A new complaint as the app sends it: open, unread and without a reply.
    static func new(uid: String, userName: String, userRole: UserRole, category: ComplaintCategory,
                    routeName: String?, busName: String?, tripTime: Date?, text: String) -> Complaint {
        Complaint(uid: uid, userName: userName, userRole: userRole.rawValue, category: category,
                  routeName: routeName, busName: busName, tripTime: tripTime,
                  text: text.trimmingCharacters(in: .whitespacesAndNewlines), createdAt: Date(),
                  status: .open, adminReply: nil, repliedAt: nil, readByAdmin: false)
    }

    // "Normal-2 · Rupsha", or nil when neither was given.
    var busAndRoute: String? {
        let parts = [busName, routeName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

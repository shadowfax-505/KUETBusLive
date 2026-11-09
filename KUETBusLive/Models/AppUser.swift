//
//  AppUser.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//

import Foundation
import FirebaseFirestore

enum UserRole: String, Codable, CaseIterable {
    case student
    case teacher
    case driver
    case admin

    // Roles a person can pick on the sign-up screen. Admins are set up by the transport office.
    static let signUpRoles: [UserRole] = [.student, .teacher, .driver]

    var title: String {
        switch self {
        case .student:
            return String(localized: "Student")
        case .teacher:
            return String(localized: "Teacher")
        case .driver:
            return String(localized: "Driver")
        case .admin:
            return String(localized: "Transport Admin")
        }
    }

    var idLabel: String {
        switch self {
        case .student:
            return String(localized: "Roll number")
        case .teacher:
            return String(localized: "Employee ID")
        case .driver:
            return String(localized: "Driver ID")
        case .admin:
            return String(localized: "Staff ID")
        }
    }
}

// One document in the "users" collection. The document ID is the Firebase Auth uid.
struct AppUser: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var role: UserRole
    var kuetId: String?
    var isApproved: Bool?
    var favoriteStopName: String?
    var favoriteStopLat: Double?
    var favoriteStopLng: Double?

    // Teachers and drivers must be approved by the transport admin before they can use the app.
    var needsApproval: Bool {
        role == .teacher || role == .driver
    }

    var approved: Bool {
        isApproved ?? false
    }

    // Computed property: builds a Stop only when all three fields are saved.
    var favoriteStop: Stop? {
        guard let name = favoriteStopName,
              let lat = favoriteStopLat,
              let lng = favoriteStopLng else {
            return nil
        }
        return Stop(name: name, lat: lat, lng: lng)
    }
}

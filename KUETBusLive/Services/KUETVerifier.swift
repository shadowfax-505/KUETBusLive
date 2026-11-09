//
//  KUETVerifier.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  Checks that a new account belongs to a KUET student or teacher.
//  - Students: 7-digit roll number, KUET student email, and the roll must appear in the email.
//  - Teachers: KUET staff email and an employee ID. The transport admin then approves them.
//  Students and teachers must also open the verification link Firebase emails them.
//

import Foundation

struct KUETVerifier {
    static let studentEmailDomain = "stud.kuet.ac.bd"
    static let staffEmailDomain = "kuet.ac.bd"

    // Debug builds accept @test.com accounts so the app can be demonstrated without real
    // KUET mailboxes. Release builds never accept them.
    #if DEBUG
    static let demoEmailDomain: String? = "test.com"
    #else
    static let demoEmailDomain: String? = nil
    #endif

    // The two accounts Apple's App Review team signs in with (see docs/app-review-notes.md).
    // They are created by hand in the Firebase console, have no KUET mailbox, and so skip
    // the KUET email checks. Only these exact addresses do; nothing else on that domain.
    static let appReviewStudentEmail = "appreview.student@kuetbuslive.app"
    static let appReviewDriverEmail = "appreview.driver@kuetbuslive.app"
    static let appReviewEmails: Set<String> = [appReviewStudentEmail, appReviewDriverEmail]

    static func isAppReviewEmail(_ email: String) -> Bool {
        appReviewEmails.contains(email.lowercased().trimmingCharacters(in: .whitespaces))
    }

    // "Name@CSE.kuet.ac.bd" -> "cse.kuet.ac.bd"
    static func domain(of email: String) -> String {
        let parts = email.lowercased().trimmingCharacters(in: .whitespaces).split(separator: "@")
        guard parts.count == 2 else { return "" }
        return String(parts[1])
    }

    static func isDemoEmail(_ email: String) -> Bool {
        guard let demo = demoEmailDomain else { return false }
        return domain(of: email) == demo
    }

    static func isStudentEmail(_ email: String) -> Bool {
        domain(of: email) == studentEmailDomain
    }

    // kuet.ac.bd or a department subdomain such as cse.kuet.ac.bd, but not the student domain.
    static func isStaffEmail(_ email: String) -> Bool {
        let domain = domain(of: email)
        guard domain != studentEmailDomain else { return false }
        return domain == staffEmailDomain || domain.hasSuffix("." + staffEmailDomain)
    }

    // 7 digits, starting with a batch year that isn't in the future, e.g. 2207001.
    static func isValidRoll(_ roll: String) -> Bool {
        guard roll.count == 7, roll.allSatisfy({ $0.isNumber }) else { return false }
        guard let batchYear = Int(roll.prefix(2)) else { return false }
        let currentYear = Calendar.current.component(.year, from: Date()) % 100
        return batchYear <= currentYear
    }

    // Returns nil when everything is valid, otherwise a message to show the user.
    static func validate(role: UserRole, email: String, kuetId: String) -> String? {
        let email = email.lowercased().trimmingCharacters(in: .whitespaces)
        let id = kuetId.trimmingCharacters(in: .whitespaces)
        let demo = isDemoEmail(email) || isAppReviewEmail(email)

        switch role {
        case .student:
            guard isValidRoll(id) else {
                return String(localized: "Roll number must be 7 digits, like 2207001.")
            }
            if demo { return nil }
            guard isStudentEmail(email) else {
                return String(localized: "Use your KUET student email (ending in @\(studentEmailDomain)).")
            }
            guard email.contains(id) else {
                return String(localized: "The roll number doesn't match the one in your KUET email.")
            }
            return nil
        case .teacher:
            guard !id.isEmpty else {
                return String(localized: "Enter your KUET employee ID.")
            }
            if demo { return nil }
            guard isStaffEmail(email) else {
                return String(localized: "Use your KUET staff email (ending in \(staffEmailDomain)).")
            }
            return nil
        case .driver:
            guard !id.isEmpty else {
                return String(localized: "Enter your driver ID.")
            }
            return nil
        case .admin:
            return String(localized: "Transport admin accounts are set up by the transport office.")
        }
    }

    static func needsEmailVerification(role: UserRole, email: String) -> Bool {
        (role == .student || role == .teacher) && !isDemoEmail(email) && !isAppReviewEmail(email)
    }
}

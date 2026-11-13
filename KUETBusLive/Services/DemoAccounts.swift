//
//  DemoAccounts.swift
//  KUETBusLive
//
//  Created by Muttakin Rahman Shoscho.
//
//  DEMO ONLY. The accounts used to show the app in the lab and to App Review.
//  They have no KUET mailbox, so they can't open an email verification link.
//  These accounts skip the "verify your KUET email" step in every build.
//
//  It only skips the email link. Signing up with an @test.com address is still
//  refused in release builds (KUETVerifier.demoEmailDomain), so nobody can make a
//  new account that avoids verification there; the demo accounts must already exist.
//
//  To remove before a public release: delete this file and its use in
//  KUETVerifier.needsEmailVerification.
//

import Foundation

enum DemoAccounts {
    static let domain = "test.com"
    static let addresses: Set<String> = [
        "appreview.student@kuetbuslive.app",
        "appreview.driver@kuetbuslive.app",
    ]

    static func contains(_ email: String) -> Bool {
        let email = email.lowercased().trimmingCharacters(in: .whitespaces)
        return addresses.contains(email) || KUETVerifier.domain(of: email) == domain
    }
}

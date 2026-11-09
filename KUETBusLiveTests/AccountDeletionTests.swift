//
//  AccountDeletionTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  Checks who may delete their account, what the confirmation says,
//  and that the phone forgets the account's settings.
//

import XCTest
@testable import KUETBusLive

final class AccountDeletionTests: XCTestCase {

    func testRidersAndDriversCanAlwaysDelete() {
        for role in [UserRole.student, .teacher, .driver] {
            XCTAssertNil(AccountDeletion.blockReason(role: role, adminCount: 0))
            XCTAssertNil(AccountDeletion.blockReason(role: role, adminCount: 1))
        }
    }

    func testLastAdminCannotDelete() {
        XCTAssertNotNil(AccountDeletion.blockReason(role: .admin, adminCount: 1))
        // A count of 0 means the list could not be read properly; stay on the safe side.
        XCTAssertNotNil(AccountDeletion.blockReason(role: .admin, adminCount: 0))
    }

    func testAdminCanDeleteWhenAnotherAdminExists() {
        XCTAssertNil(AccountDeletion.blockReason(role: .admin, adminCount: 2))
    }

    func testExplanationMentionsTheRunningTrip() {
        let onTrip = AccountDeletion.explanation(role: .driver, isOnTrip: true)
        let offTrip = AccountDeletion.explanation(role: .driver, isOnTrip: false)
        let student = AccountDeletion.explanation(role: .student, isOnTrip: false)
        XCTAssertNotEqual(onTrip, offTrip)
        XCTAssertTrue(student.count < offTrip.count)
    }

    func testClearLocalSettingsRemovesOnlyTheAppsKeys() {
        let suite = "AccountDeletionTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        for key in AccountDeletion.localSettingKeys {
            defaults.set(true, forKey: key)
        }
        defaults.set("keep", forKey: "somethingElse")

        AccountDeletion.clearLocalSettings(in: defaults)

        for key in AccountDeletion.localSettingKeys {
            XCTAssertNil(defaults.object(forKey: key), key)
        }
        XCTAssertEqual(defaults.string(forKey: "somethingElse"), "keep")
        defaults.removePersistentDomain(forName: suite)
    }
}

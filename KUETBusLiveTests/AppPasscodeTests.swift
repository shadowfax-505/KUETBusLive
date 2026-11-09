//
//  AppPasscodeTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  The passcode is only ever stored as a SHA-256 hash. The Keychain part is
//  skipped on machines where the simulator can't use the Keychain (some CI runners).
//

import XCTest
@testable import KUETBusLive

final class AppPasscodeTests: XCTestCase {

    func testHashIsDeterministicSHA256Hex() {
        // Known SHA-256 of "1234".
        let expected = "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4"
        XCTAssertEqual(AppPasscode.hash("1234"), expected)
        XCTAssertEqual(AppPasscode.hash("1234"), AppPasscode.hash("1234"))
        XCTAssertEqual(AppPasscode.hash("0000").count, 64)
    }

    func testDifferentCodesGiveDifferentHashes() {
        XCTAssertNotEqual(AppPasscode.hash("1234"), AppPasscode.hash("1235"))
    }

    func testSaveCheckAndRemove() throws {
        // Only the hash is stored, so an existing passcode couldn't be put back afterwards.
        // Skip rather than wipe a passcode someone set on this simulator.
        try XCTSkipIf(AppPasscode.isSet, "A passcode is already set on this simulator")
        guard AppPasscode.save("2468") else {
            throw XCTSkip("Keychain is not available here")
        }
        defer { AppPasscode.remove() }

        XCTAssertTrue(AppPasscode.isSet)
        XCTAssertTrue(AppPasscode.check("2468"))
        XCTAssertFalse(AppPasscode.check("1357"))

        AppPasscode.remove()
        XCTAssertFalse(AppPasscode.isSet)
        XCTAssertFalse(AppPasscode.check("2468"))
    }
}

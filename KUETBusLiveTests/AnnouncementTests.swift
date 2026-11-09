//
//  AnnouncementTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  The time under each announcement: a fresh post must never read "in 0 seconds".
//

import XCTest
@testable import KUETBusLive

final class AnnouncementTests: XCTestCase {

    private func announcement(postedSecondsAgo seconds: TimeInterval) -> Announcement {
        Announcement(title: "Test", body: "Body",
                     createdAt: Date().addingTimeInterval(-seconds),
                     postedBy: "Admin")
    }

    func testFreshPostReadsJustNow() {
        XCTAssertEqual(announcement(postedSecondsAgo: 0).timeText, String(localized: "Just now"))
        XCTAssertEqual(announcement(postedSecondsAgo: 30).timeText, String(localized: "Just now"))
    }

    // Another phone's clock can be a little ahead, so the post looks like it is from the future.
    func testPostStampedSlightlyAheadReadsJustNow() {
        XCTAssertEqual(announcement(postedSecondsAgo: -5).timeText, String(localized: "Just now"))
    }

    func testOlderPostUsesRelativeTime() {
        let text = announcement(postedSecondsAgo: 5 * 60).timeText
        XCTAssertNotEqual(text, String(localized: "Just now"))
        XCTAssertFalse(text.hasPrefix("in "))
    }
}

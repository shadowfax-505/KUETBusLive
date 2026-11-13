//
//  BusAgeTextTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  How long ago a bus last sent its position: seconds, minutes, then hours and days.
//

import XCTest
@testable import KUETBusLive

final class BusAgeTextTests: XCTestCase {

    func testSecondsUnderAMinute() {
        XCTAssertEqual(Bus.ageText(seconds: 0), "0 s ago")
        XCTAssertEqual(Bus.ageText(seconds: 59), "59 s ago")
    }

    func testClockSkewNeverShowsNegative() {
        XCTAssertEqual(Bus.ageText(seconds: -5), "0 s ago")
    }

    func testMinutesUnderAnHour() {
        XCTAssertEqual(Bus.ageText(seconds: 60), "1 min ago")
        XCTAssertEqual(Bus.ageText(seconds: 3599), "59 min ago")
    }

    func testLongGapsReadInHours() {
        XCTAssertEqual(Bus.ageText(seconds: 3600), "1 h ago")
        XCTAssertEqual(Bus.ageText(seconds: 157 * 60), "2 h ago")
        XCTAssertEqual(Bus.ageText(seconds: 86_399), "23 h ago")
    }

    func testVeryLongGapsReadInDays() {
        XCTAssertEqual(Bus.ageText(seconds: 86_400), "1 d ago")
        XCTAssertEqual(Bus.ageText(seconds: 3 * 86_400 + 10), "3 d ago")
    }
}

//
//  LanguageSwitchTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  Choosing a language in Settings changes text at once, including text the
//  app builds in code (speeds, "5 s ago", crowd labels), without a restart.
//

import XCTest
@testable import KUETBusLive

final class LanguageSwitchTests: XCTestCase {

    override func tearDown() {
        LanguageBundle.use(nil)
    }

    func testCodeBuiltTextFollowsTheChosenLanguage() {
        LanguageBundle.use("bn")
        XCTAssertEqual(CrowdLevel.seats.shortLabel, "সিট খালি")
        XCTAssertEqual(Bus.ageText(seconds: 5), "5 সেকেন্ড আগে")

        LanguageBundle.use("en")
        XCTAssertEqual(CrowdLevel.seats.shortLabel, "Seats free")
        XCTAssertEqual(Bus.ageText(seconds: 5), "5 s ago")
    }
}

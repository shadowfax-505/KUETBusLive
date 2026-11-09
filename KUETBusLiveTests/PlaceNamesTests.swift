//
//  PlaceNamesTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  Checks how stop and place names are shown in English and in Bangla.
//

import XCTest
@testable import KUETBusLive

final class PlaceNamesTests: XCTestCase {

    func testEnglishStaysEnglish() {
        XCTAssertEqual(PlaceNames.display("Rupsha", bangla: "রূপসা", inBangla: false), "Rupsha")
    }

    func testAdminBanglaNameWins() {
        XCTAssertEqual(PlaceNames.display("Rupsha", bangla: "রূপসা ঘাট", inBangla: true), "রূপসা ঘাট")
    }

    func testBuiltInListIsUsedWithoutAnAdminName() {
        XCTAssertEqual(PlaceNames.display("Fulbarigate", bangla: nil, inBangla: true), "ফুলবাড়ীগেট")
        XCTAssertEqual(PlaceNames.display("KUET Main Gate", bangla: "  ", inBangla: true), "কুয়েট মেইন গেট")
        // Case does not matter.
        XCTAssertEqual(PlaceNames.display("sonadanga bus terminal", bangla: nil, inBangla: true), "সোনাডাঙ্গা বাস টার্মিনাল")
    }

    func testUnknownPlaceFallsBackToEnglish() {
        XCTAssertEqual(PlaceNames.display("Some New Stop", bangla: nil, inBangla: true), "Some New Stop")
    }

    func testBusLabelsKeepTheTripName() {
        XCTAssertEqual(PlaceNames.translate("Normal-2 · Rupsha"), "Normal-2 · রূপসা")
        XCTAssertEqual(PlaceNames.translate("Special-1 (AC) · Gollamari"), "Special-1 (AC) · গল্লামারী")
    }

    func testRouteNamesAreTranslatedPartByPart() {
        XCTAssertEqual(PlaceNames.translate("KUET to Sonadanga"), "কুয়েট – সোনাডাঙ্গা")
    }

    // Every starting spot in the bundled timetable has a Bangla name.
    func testEveryTimetableSpotHasABanglaName() throws {
        let url = try XCTUnwrap(Bundle(for: PlaceNamesTests.self).url(forResource: "kuet_schedule", withExtension: "json")
                                ?? Bundle.main.url(forResource: "kuet_schedule", withExtension: "json"))
        struct File: Decodable { struct Trip: Decodable { let spot: String }; let trips: [Trip] }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        for spot in Set(file.trips.map(\.spot)) {
            XCTAssertNotEqual(PlaceNames.translate(spot), spot, "No Bangla name for \(spot)")
        }
    }
}

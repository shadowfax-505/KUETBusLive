//
//  AppCacheTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  Measuring and emptying a cache folder, and finding pages in Settings.
//

import XCTest
@testable import KUETBusLive

final class AppCacheTests: XCTestCase {

    var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("AppCacheTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("inner"),
                                                withIntermediateDirectories: true)
        try Data(count: 1000).write(to: folder.appendingPathComponent("a.bin"))
        try Data(count: 500).write(to: folder.appendingPathComponent("inner/b.bin"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testSizeCountsNestedFiles() {
        XCTAssertEqual(AppCache.size(of: folder), 1500)
    }

    func testEmptyRemovesContentsButKeepsFolder() {
        AppCache.empty(folder)
        var isFolder: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path, isDirectory: &isFolder))
        XCTAssertTrue(isFolder.boolValue)
        XCTAssertEqual(AppCache.size(of: folder), 0)
    }

    func testMissingFolderHasNoSize() {
        XCTAssertEqual(AppCache.size(of: folder.appendingPathComponent("nope")), 0)
    }

    func testSettingsSearchMatchesTitlesAndKeywords() {
        let all = SettingsPage.allCases
        XCTAssertEqual(SettingsPage.matching("", in: all), all)
        XCTAssertEqual(SettingsPage.matching("face id", in: all), [.privacy])
        XCTAssertEqual(SettingsPage.matching("dark", in: all), [.appearance])
        XCTAssertEqual(SettingsPage.matching("বাংলা", in: all), [.language])
        XCTAssertTrue(SettingsPage.matching("cache", in: all).contains(.storage))
        XCTAssertTrue(SettingsPage.matching("zzzz", in: all).isEmpty)
    }

    func testAdminsSeeNoRiderOnlyPages() {
        XCTAssertFalse(SettingsPage.visible(for: .admin).contains(.notifications))
        XCTAssertTrue(SettingsPage.visible(for: .driver).contains(.notifications))
        XCTAssertTrue(SettingsPage.visible(for: .student).contains(.account))
    }
}

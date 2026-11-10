//
//  AssistantTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  The smart assistant's on/off logic, and the checks on what the model writes.
//  A fake model stands in for Apple's, so these run on any simulator.
//

import XCTest
@testable import KUETBusLive

// Answers with fixed text, and records what it was asked.
final class FakeModel: AssistantModel {
    var reply: Result<String, AssistantError>
    var lastUser = ""
    init(_ reply: Result<String, AssistantError>) { self.reply = reply }
    func complete(system: String, user: String,
                  completion: @escaping (Result<String, AssistantError>) -> Void) -> AssistantRequest {
        lastUser = user
        completion(reply)
        return AssistantRequest()
    }
}

final class AssistantTests: XCTestCase {

    // MARK: - When the assistant is offered and used

    func testOnlyCapablePhonesAreOfferedTheSwitch() {
        XCTAssertTrue(AssistantStatus(availability: .available, speaksLanguage: true, optedIn: false).canOffer)
        for reason in [DeviceModelAvailability.notSupported, .appleIntelligenceOff, .downloading] {
            let status = AssistantStatus(availability: reason, speaksLanguage: true, optedIn: true)
            XCTAssertFalse(status.canOffer)
            XCTAssertFalse(status.isReady)
            XCTAssertNotNil(status.note)
        }
    }

    func testOffByDefaultUntilThePersonTurnsItOn() {
        XCTAssertFalse(AssistantStatus(availability: .available, speaksLanguage: true, optedIn: false).isReady)
        XCTAssertTrue(AssistantStatus(availability: .available, speaksLanguage: true, optedIn: true).isReady)
    }

    func testUnsupportedLanguageHidesTheAssistant() {
        let bangla = AssistantStatus(availability: .available, speaksLanguage: false, optedIn: true)
        XCTAssertFalse(bangla.isReady)
        XCTAssertTrue(bangla.canOffer)          // the switch is still shown
        XCTAssertNotNil(bangla.note)            // with a note saying why
    }

    // MARK: - Checking what the model wrote

    func testJSONInsideFencesIsFound() {
        let text = "Here you go:\n```json\n{\"titleEn\":\"Late\",\"bodyEn\":\"Late today.\",\"titleBn\":\"দেরি\",\"bodyBn\":\"আজ দেরি।\"}\n```"
        XCTAssertEqual(AnnouncementDraft.parse(text)?.titleBn, "দেরি")
        XCTAssertNil(AnnouncementDraft.parse("no json here"))
    }

    func testTriageChecks() {
        XCTAssertTrue(ComplaintTriage(category: "late", urgency: "high", summary: "x", reply: "y").isValid)
        XCTAssertFalse(ComplaintTriage(category: "spam", urgency: "high", summary: "x", reply: "y").isValid)
        XCTAssertFalse(ComplaintTriage(category: "late", urgency: "urgent!!", summary: "x", reply: "y").isValid)
        XCTAssertFalse(ComplaintTriage(category: "late", urgency: "low", summary: " ", reply: "y").isValid)
    }

    func testTriagePromptHasNoPersonalDetails() {
        let complaint = Complaint.new(uid: "uid-123", userName: "Rahman", userRole: .student, category: .late,
                                      routeName: "KUET to Rupsha", busName: "Normal-2", tripTime: nil,
                                      text: "The bus didn't come.")
        let prompt = ComplaintTriage.prompt(for: complaint)
        XCTAssertTrue(prompt.contains("The bus didn't come."))
        XCTAssertFalse(prompt.contains("Rahman"))
        XCTAssertFalse(prompt.contains("uid-123"))
    }

    func testAnnouncementDraftNeedsBothLanguages() {
        XCTAssertNil(AnnouncementDraft.parse(#"{"titleEn":"Late","bodyEn":"Late today.","titleBn":"","bodyBn":""}"#))
    }

    func testTimetableImportIsStrict() {
        let good = #"{"trips":[{"tripName":"Normal-1","audience":"student","days":"sunToThu","period":"morning","campusTime":"06:30","spot":"Rupsha","spotTime":"07:10"}]}"#
        XCTAssertEqual(TimetableImport.parse(good)?.first?.remarks, "")
        XCTAssertNil(TimetableImport.parse(good.replacingOccurrences(of: "06:30", with: "6.30am")))
        XCTAssertNil(TimetableImport.parse(good.replacingOccurrences(of: "sunToThu", with: "weekdays")))
        XCTAssertNil(TimetableImport.parse(#"{"trips":[]}"#))
        XCTAssertNil(TimetableImport.parse("I could not read that."))
    }

    func testTimetableDiff() {
        func trip(_ name: String, _ time: String, _ spotTime: String = "07:10") -> ImportedTrip {
            ImportedTrip(tripName: name, audience: "student", days: "sunToThu", period: "morning",
                         campusTime: time, spot: "Rupsha", spotTime: spotTime, remarks: "")
        }
        let current = [trip("Normal-1", "06:30"), trip("Normal-2", "07:00")]
        let proposed = [trip("Normal-1", "06:30", "07:20"), trip("Normal-3", "08:00")]
        let diff = TimetableImport.diff(current: current, proposed: proposed)
        XCTAssertEqual(diff.added.map(\.tripName), ["Normal-3"])
        XCTAssertEqual(diff.removed.map(\.tripName), ["Normal-2"])
        XCTAssertEqual(diff.changed.map(\.new.spotTime), ["07:20"])
        XCTAssertTrue(TimetableImport.diff(current: current, proposed: current).isEmpty)
    }

    // MARK: - Rider questions

    func testRiderPromptUsesOnlyTheGivenData() {
        let schedule = BusSchedule(tripName: "Normal-1", audience: .student, days: .sunToThu, period: .noon,
                                   campusTime: "13:15", spot: "Rupsha", spotTime: "14:00", remarks: "")
        let teacherTrip = BusSchedule(tripName: "Special-1", audience: .teacher, days: .sunToThu, period: .noon,
                                      campusTime: "13:15", spot: "Rupsha", spotTime: "14:20", remarks: "")
        let monday = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 9))!
        let prompt = RiderQuestion.prompt(question: "Next bus to Rupsha?", now: monday,
                                          schedules: [schedule, teacherTrip], role: .student,
                                          boarding: "Home", liveBuses: [], announcements: [])
        XCTAssertTrue(prompt.contains("Normal-1: leaves KUET"))
        XCTAssertFalse(prompt.contains("Special-1"))     // students can't ride it, so it isn't given
        XCTAssertTrue(prompt.contains("My boarding point: Home"))
    }

    func testRiderQuestionsAreRateLimited() {
        let assistant = AssistantViewModel(model: FakeModel(.success("ok")))
        var results: [Result<String, AssistantError>] = []
        _ = assistant.askAsRider(system: "", user: "a") { results.append($0) }
        _ = assistant.askAsRider(system: "", user: "b") { results.append($0) }
        XCTAssertEqual(results.last, .failure(.rateLimited))
    }

    func testBanglaTextIsDetected() {
        XCTAssertEqual(AssistantViewModel.language(of: "বাস আসেনি"), "bn")
        XCTAssertEqual(AssistantViewModel.language(of: "Bus didn't come"), "en")
    }

    func testErrorsHaveMessages() {
        XCTAssertFalse(AssistantError.contextTooLong.message.isEmpty)
        XCTAssertTrue(AssistantError.contextTooLong.message.contains("smaller part"))
    }
}

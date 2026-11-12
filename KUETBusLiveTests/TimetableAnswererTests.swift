//
//  TimetableAnswererTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  Answers from the timetable alone, used when the on-device model can't answer.
//

import XCTest
@testable import KUETBusLive

final class TimetableAnswererTests: XCTestCase {

    // 10 Nov 2026 is a Tuesday, so the Sunday-to-Thursday trips run.
    func tuesday(_ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: hour, minute: minute))!
    }

    func trip(_ name: String, _ campus: String, _ spot: String, _ spotTime: String,
              days: TripDays = .sunToThu) -> BusSchedule {
        BusSchedule(tripName: name, audience: BusAudience.from(tripName: name), days: days, period: .noon,
                    campusTime: campus, spot: spot, spotTime: spotTime, remarks: "")
    }

    var timetable: [BusSchedule] {
        [trip("Normal-1", "07:00", "Rupsha", "07:40"),
         trip("Normal-2", "13:15", "Rupsha", "14:00"),
         trip("Normal-1", "17:00", "Sonadanga", "17:45"),
         trip("Special-1", "18:00", "Rupsha", "18:40"),          // teachers only
         trip("Normal-2", "09:00", "Rupsha", "09:40", days: .saturday)]
    }

    func answer(_ question: String, at date: Date, role: UserRole = .student, live: [String] = []) -> String {
        TimetableAnswerer.answer(question: question, now: date, schedules: timetable, role: role, liveBuses: live)
    }

    func testReadsWhatKindOfQuestionItIs() {
        XCTAssertEqual(TimetableAnswerer.kind(of: "When is the next bus?"), .next)
        XCTAssertEqual(TimetableAnswerer.kind(of: "When does the last bus leave"), .last)
        XCTAssertEqual(TimetableAnswerer.kind(of: "first bus to Rupsha"), .first)
        XCTAssertEqual(TimetableAnswerer.kind(of: "Which buses are running?"), .running)
        XCTAssertEqual(TimetableAnswerer.kind(of: "শেষ বাস কখন?"), .last)
    }

    func testFindsTheTimetablePlaceInTheQuestion() {
        let spots: [(english: String, bangla: String?)] = [("Rupsha", nil), ("Royal Mor", nil), ("Sonadanga", "সোনাডাঙ্গা")]
        XCTAssertEqual(TimetableAnswerer.place(in: "next bus to rupsha?", spots: spots), "Rupsha")
        XCTAssertEqual(TimetableAnswerer.place(in: "bus to Royal Mor", spots: spots), "Royal Mor")
        XCTAssertEqual(TimetableAnswerer.place(in: "সোনাডাঙ্গা যাওয়ার বাস", spots: spots), "Sonadanga")
        XCTAssertNil(TimetableAnswerer.place(in: "next bus to Boyra", spots: spots))
    }

    func testNextBusToAPlace() {
        let reply = answer("When is the next bus to Rupsha?", at: tuesday(9))
        XCTAssertTrue(reply.contains("Normal-2"), reply)
        XCTAssertTrue(reply.contains("1:15 PM"), reply)
    }

    func testNextBusAnywhere() {
        let reply = answer("next bus", at: tuesday(15))
        XCTAssertTrue(reply.contains("Normal-1") && reply.contains("5:00 PM"), reply)
    }

    func testABusThatLeftCampusButNotTheCity() {
        // 13:30: Normal-2 left KUET at 13:15 but leaves Rupsha at 14:00.
        let reply = answer("next bus to Rupsha", at: tuesday(13, 30))
        XCTAssertTrue(reply.contains("2:00 PM"), reply)
        XCTAssertTrue(reply.contains("has left KUET"), reply)
    }

    func testStudentsDontGetTeacherBuses() {
        // After 17:45 only the teachers' Special-1 is left.
        XCTAssertTrue(answer("next bus", at: tuesday(17, 50)).contains("No more buses today"))
        XCTAssertTrue(answer("next bus", at: tuesday(17, 50), role: .teacher).contains("Special-1"))
    }

    func testLastAndFirstBus() {
        XCTAssertTrue(answer("When does the last bus leave?", at: tuesday(8)).contains("5:00 PM"))
        XCTAssertTrue(answer("last bus to Rupsha", at: tuesday(8)).contains("1:15 PM"))
        XCTAssertTrue(answer("first bus", at: tuesday(12)).contains("7:00 AM"))
    }

    func testAPlaceNoBusGoesTo() {
        let reply = answer("When is the next bus to Boyra?", at: tuesday(9))
        XCTAssertTrue(reply.contains("Boyra"), reply)
        XCTAssertTrue(reply.contains("Rupsha") && reply.contains("Sonadanga"), reply)
    }

    func testFridayHasNoBuses() {
        let friday = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 9))!
        XCTAssertTrue(answer("next bus", at: friday).contains("no buses"))
    }

    func testRunningBuses() {
        XCTAssertTrue(answer("Which buses are running?", at: tuesday(9)).contains("No buses are running"))
        XCTAssertTrue(answer("which buses are running", at: tuesday(9), live: ["Normal-1 · Rupsha"]).contains("Normal-1 · Rupsha"))
    }

    func testPromptForTheModelStaysShort() {
        let many = (0..<60).map { trip("Normal-\($0)", String(format: "%02d:%02d", 6 + $0 / 4, ($0 % 4) * 15), "Rupsha", "23:00") }
        let news = Announcement(title: "Holiday", body: String(repeating: "Long text. ", count: 400),
                                createdAt: Date(), postedBy: "Office")
        let prompt = RiderQuestion.prompt(question: "next bus", now: tuesday(6), schedules: many, role: .student,
                                          boarding: nil, liveBuses: [], announcements: [news, news, news])
        XCTAssertLessThan(prompt.count, 2_000)
        XCTAssertEqual(prompt.components(separatedBy: "leaves KUET").count - 1, RiderQuestion.maxTrips)
    }
}

//
//  KUETVerifierTests.swift
//  KUETBusLiveTests
//
//  Created by Muttakin Rahman Shoscho.
//
//  Checks the sign-up rules: roll numbers, KUET emails, and what each role must enter.
//

import XCTest
@testable import KUETBusLive

final class KUETVerifierTests: XCTestCase {

    // MARK: - Roll numbers

    func testValidRoll() {
        XCTAssertTrue(KUETVerifier.isValidRoll("2207001"))
        XCTAssertTrue(KUETVerifier.isValidRoll("1907120"))
    }

    func testRollMustBeSevenDigits() {
        XCTAssertFalse(KUETVerifier.isValidRoll("220700"))     // too short
        XCTAssertFalse(KUETVerifier.isValidRoll("22070011"))   // too long
        XCTAssertFalse(KUETVerifier.isValidRoll("22O7001"))    // letter O, not zero
        XCTAssertFalse(KUETVerifier.isValidRoll(""))
    }

    func testRollBatchYearCannotBeInTheFuture() {
        let nextYear = (Calendar.current.component(.year, from: Date()) + 1) % 100
        let futureRoll = String(format: "%02d07001", nextYear)
        XCTAssertFalse(KUETVerifier.isValidRoll(futureRoll))
    }

    // MARK: - Email domains

    func testDomainIsLowercasedAndTrimmed() {
        XCTAssertEqual(KUETVerifier.domain(of: " Name@CSE.KUET.ac.bd "), "cse.kuet.ac.bd")
        XCTAssertEqual(KUETVerifier.domain(of: "no-at-sign"), "")
    }

    func testStudentAndStaffEmails() {
        XCTAssertTrue(KUETVerifier.isStudentEmail("rahman2207001@stud.kuet.ac.bd"))
        XCTAssertFalse(KUETVerifier.isStudentEmail("someone@gmail.com"))

        XCTAssertTrue(KUETVerifier.isStaffEmail("teacher@kuet.ac.bd"))
        XCTAssertTrue(KUETVerifier.isStaffEmail("teacher@cse.kuet.ac.bd"))
        // The student domain also ends in kuet.ac.bd, but it is not a staff email.
        XCTAssertFalse(KUETVerifier.isStaffEmail("rahman2207001@stud.kuet.ac.bd"))
        XCTAssertFalse(KUETVerifier.isStaffEmail("teacher@fakekuet.ac.bd"))
    }

    // MARK: - Students

    func testStudentWithMatchingEmailPasses() {
        let problem = KUETVerifier.validate(role: .student,
                                            email: "rahman2207001@stud.kuet.ac.bd",
                                            kuetId: "2207001")
        XCTAssertNil(problem)
    }

    func testStudentEmailMustContainRoll() {
        let problem = KUETVerifier.validate(role: .student,
                                            email: "rahman2207002@stud.kuet.ac.bd",
                                            kuetId: "2207001")
        XCTAssertNotNil(problem)
    }

    func testStudentNeedsStudentEmail() {
        let problem = KUETVerifier.validate(role: .student,
                                            email: "2207001@gmail.com",
                                            kuetId: "2207001")
        XCTAssertNotNil(problem)
    }

    func testStudentWithBadRollFails() {
        let problem = KUETVerifier.validate(role: .student,
                                            email: "rahman22070@stud.kuet.ac.bd",
                                            kuetId: "22070")
        XCTAssertNotNil(problem)
    }

    // MARK: - Teachers, drivers and admins

    func testTeacherNeedsStaffEmailAndId() {
        XCTAssertNil(KUETVerifier.validate(role: .teacher, email: "t@cse.kuet.ac.bd", kuetId: "E-101"))
        XCTAssertNotNil(KUETVerifier.validate(role: .teacher, email: "t@cse.kuet.ac.bd", kuetId: " "))
        XCTAssertNotNil(KUETVerifier.validate(role: .teacher, email: "t@gmail.com", kuetId: "E-101"))
    }

    func testDriverOnlyNeedsAnId() {
        XCTAssertNil(KUETVerifier.validate(role: .driver, email: "driver@gmail.com", kuetId: "D-7"))
        XCTAssertNotNil(KUETVerifier.validate(role: .driver, email: "driver@gmail.com", kuetId: ""))
    }

    func testNobodyCanSignUpAsAdmin() {
        XCTAssertNotNil(KUETVerifier.validate(role: .admin, email: "boss@kuet.ac.bd", kuetId: "1"))
    }

    // MARK: - Email verification

    func testWhoMustVerifyTheirEmail() {
        XCTAssertTrue(KUETVerifier.needsEmailVerification(role: .student, email: "a2207001@stud.kuet.ac.bd"))
        XCTAssertTrue(KUETVerifier.needsEmailVerification(role: .teacher, email: "t@kuet.ac.bd"))
        XCTAssertFalse(KUETVerifier.needsEmailVerification(role: .driver, email: "d@gmail.com"))
    }

    // MARK: - @test.com demo accounts (debug builds only)

    func testDemoEmailRule() {
        #if DEBUG
        XCTAssertTrue(KUETVerifier.isDemoEmail("student2@test.com"))
        // A demo student still needs a valid roll, but the email doesn't have to match it.
        XCTAssertNil(KUETVerifier.validate(role: .student, email: "student2@test.com", kuetId: "2207002"))
        XCTAssertNotNil(KUETVerifier.validate(role: .student, email: "student2@test.com", kuetId: "12"))
        XCTAssertNil(KUETVerifier.validate(role: .teacher, email: "teacher@test.com", kuetId: "E-1"))
        XCTAssertFalse(KUETVerifier.needsEmailVerification(role: .student, email: "student2@test.com"))
        #else
        XCTAssertFalse(KUETVerifier.isDemoEmail("student2@test.com"))
        #endif
    }
}

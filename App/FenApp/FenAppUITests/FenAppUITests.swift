//
//  FenAppUITests.swift
//  FenAppUITests
//
//  Created by Sean Smith on 1/22/26.
//

import XCTest

final class FenAppUITests: XCTestCase {
    private let startupTimeout: TimeInterval = 90
    private let interactionTimeout: TimeInterval = 30

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingCaptureJournalAndEditFlow() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-reset-onboarding", "-reset-observations"]
        app.launch()

        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: startupTimeout) {
            continueButton.tap()
        } else {
            XCTAssertTrue(app.tabBars.buttons["Capture"].waitForExistence(timeout: startupTimeout))
        }

        let notePrefix = "UITest observation"
        let note = "\(notePrefix) \(UUID().uuidString.prefix(8))"
        let updatedNote = "\(note) edited"

        app.tabBars.buttons["Capture"].tap()
        let captureField = app.textFields["capture.notesField"]
        XCTAssertTrue(captureField.waitForExistence(timeout: interactionTimeout))
        captureField.tap()
        captureField.typeText(note)

        app.buttons["capture.saveButton"].tap()
        XCTAssertTrue(app.staticTexts["capture.statusMessage"].waitForExistence(timeout: interactionTimeout))

        app.tabBars.buttons["Journal"].tap()
        let refreshButton = app.buttons["journal.refreshButton"]
        if refreshButton.waitForExistence(timeout: interactionTimeout) {
            refreshButton.tap()
        }

        let createdRow = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", notePrefix)).firstMatch
        XCTAssertTrue(createdRow.waitForExistence(timeout: startupTimeout))
        createdRow.tap()

        let detailField = app.textFields["journal.detail.notesField"]
        XCTAssertTrue(detailField.waitForExistence(timeout: interactionTimeout))
        detailField.tap()
        if let existingValue = detailField.value as? String, !existingValue.isEmpty {
            for _ in existingValue {
                detailField.typeText(XCUIKeyboardKey.delete.rawValue)
            }
        }
        detailField.typeText(updatedNote)

        app.buttons["journal.detail.saveButton"].tap()
        XCTAssertTrue(app.staticTexts["journal.detail.statusMessage"].waitForExistence(timeout: interactionTimeout))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts[updatedNote].waitForExistence(timeout: interactionTimeout))
    }
}

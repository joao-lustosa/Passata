//
//  PassataUITestsLaunchTests.swift
//  PassataUITests
//
//  Created by João Vitor Leão Lustosa de Souza on 08/09/26.
//

import XCTest

final class PassataUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        // See PassataUITests.setUpWithError: Passata now survives its window closing on macOS,
        // so a leftover background instance from a prior run/test must be cleared before launch.
        XCUIApplication().terminate()
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        app.activate()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

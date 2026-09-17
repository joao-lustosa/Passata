//
//  PassataUITests.swift
//  PassataUITests
//
//  Created by João Vitor Leão Lustosa de Souza on 08/09/26.
//

import XCTest

final class PassataUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.

        // On macOS, Passata stays running in the background (menu bar presence, see
        // AppDelegate.applicationShouldTerminateAfterLastWindowClosed) instead of quitting when
        // its window closes. Without this, a leftover instance from a previous test/run sits in
        // "Running Background" and XCUIApplication's next launch() fails to activate it.
        XCUIApplication().terminate()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        XCUIApplication().terminate()
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launch()
            app.terminate()
        }
    }
}

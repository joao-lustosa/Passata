//
//  PassataUITests.swift
//  PassataUITests
//
//  Created by João Vitor Leão Lustosa de Souza on 08/09/26.
//

import XCTest

final class PassataUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false

        // On macOS, Passata stays running in the background (menu bar presence, see
        // AppDelegate.applicationShouldTerminateAfterLastWindowClosed) instead of quitting when
        // its window closes. Without this, a leftover instance from a previous test/run sits in
        // "Running Background" and XCUIApplication's next launch() fails to activate it.
        MainActor.assumeIsolated {
            XCUIApplication().terminate()
        }
    }

    override func tearDownWithError() throws {
        MainActor.assumeIsolated {
            XCUIApplication().terminate()
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launch()
            app.terminate()
        }
    }
}

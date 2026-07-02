//
//  FinanceAppUITests.swift
//  FinanceAppUITests
//
//  Created by Douglas de Carli Immig on 01/06/26.
//

import XCTest

final class FinanceAppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    /// Reproduces the reported flow: a Meses dashboard card must open its detail
    /// screen, and the "Adicionar" button there must open its sheet (previously a
    /// sheet-on-sheet "presentation in progress" failure). Then the category
    /// Picker must respond to a tap (previously the "Selecione…" Menu did nothing).
    @MainActor
    func testDashboardCardOpensDetailThenAddSheetAndPicker() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Dashboard card -> pushed detail screen.
        let card = app.staticTexts["Despesas avulsas"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Dashboard card not found")
        card.tap()

        // 2. Detail screen shows its add button.
        let addButton = app.buttons["Adicionar despesa avulsa"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5),
                      "Detail screen / add button did not appear after tapping card")
        addButton.tap()

        // 3. The Add sheet must actually present (the bug: it did not).
        let cancel = app.buttons["Cancelar"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5),
                      "Add sheet failed to present (presentation-in-progress regression)")

        // 4. The category Picker must respond to a tap and push its options list
        //    (previously the custom "Selecione…" Menu did nothing).
        let pickerRow = app.buttons["Categoria"]
        XCTAssertTrue(pickerRow.waitForExistence(timeout: 5), "Category picker row not found")
        pickerRow.tap()
        XCTAssertTrue(app.navigationBars["Categoria"].waitForExistence(timeout: 5),
                      "Picker did not push its options list (Selecione… regression)")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

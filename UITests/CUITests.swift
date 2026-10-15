import XCTest

@MainActor final class CUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    private func configuredApplication() -> XCUIApplication {
        let application = XCUIApplication()
        application.launchEnvironment["C_UI_TESTING"] = "1"
        return application
    }

    private func launch(_ lab: String) {
        if app == nil { app = configuredApplication() }
        app.launchArguments = ["--lab=\(lab)"]
        app.launch()
    }

    private func reveal(_ element: XCUIElement, limit: Int = 8) {
        for _ in 0..<limit {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Control should be reachable")
    }

    private func returnUp(to element: XCUIElement) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeDown()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Control should be visible near the top")
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testExploreRoutesToCalculusAndConstantPreservesSlope() throws {
        launch("atlas")
        let route = app.buttons["atlas-calculus"]
        XCTAssertTrue(route.waitForExistence(timeout: 15))
        screenshot("Explore")
        reveal(route)
        route.tap()
        let slider = app.sliders["Constant of integration"]
        reveal(slider)
        let beforeSlope = try XCTUnwrap(app.descendants(matching: .any)["calculus.slope"].value as? String)
        let before = app.staticTexts["calculus.constant.value"].label
        slider.adjust(toNormalizedSliderPosition: 0.8)
        XCTAssertNotEqual(before, app.staticTexts["calculus.constant.value"].label)
        XCTAssertEqual(beforeSlope, app.descendants(matching: .any)["calculus.slope"].value as? String)
        screenshot("Constant changes height, preserves slope")
    }

    func testSignedIntegralReversesAndCSourceIsReachable() {
        launch("calculus")
        app.segmentedControls["calculus.mode"].buttons["Signed area → C"].tap()
        let exact = app.descendants(matching: .any)["calculus.exact"]
        reveal(exact)
        XCTAssertEqual((exact.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), "4.0000")
        let reverse = app.buttons["calculus.reverse"]
        reveal(reverse)
        reverse.tap()
        XCTAssertEqual((exact.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), "-4.0000")
        screenshot("Reversed signed integral")
        let code = app.descendants(matching: .any)["calculus.c.source"]
        reveal(code)
        XCTAssertTrue(code.exists)
    }

    func testCExecutionAndCSharpAliasing() {
        launch("language")
        let next = app.buttons["language.next"]
        reveal(next)
        for _ in 0..<12 {
            if !next.isEnabled { break }
            reveal(next)
            next.tap()
        }
        XCTAssertFalse(next.isEnabled)
        let console = app.staticTexts["language.console"]
        reveal(console)
        XCTAssertEqual(console.label, "3 3.00 3.50")
        screenshot("C division output")
        let mode = app.segmentedControls["language.mode"]
        returnUp(to: mode.buttons["C#"])
        mode.buttons["C#"].tap()
        app.segmentedControls["language.program"].buttons["Aliases"].tap()
        reveal(next)
        for _ in 0..<16 {
            if !next.isEnabled { break }
            reveal(next)
            next.tap()
        }
        XCTAssertFalse(next.isEnabled)
        reveal(console)
        XCTAssertEqual(console.label, "10 8")
        screenshot("C sharp reference aliasing")
    }

    func testPianoSharpChangesPitchAndFrequency() {
        launch("music")
        let sharp = app.buttons["music.key.1"]
        reveal(sharp)
        sharp.tap()
        app.swipeDown()
        app.swipeDown()
        let frequency = app.descendants(matching: .any)["music.selectedPitch"]
        XCTAssertTrue(frequency.waitForExistence(timeout: 5))
        XCTAssertTrue((frequency.value as? String)?.contains("277.18") == true)
        screenshot("C sharp four frequency")
        // This verifies selection and audio action availability; acoustic output is a hardware check.
        XCTAssertTrue(app.buttons["music.playNote"].exists)
    }

    func testNotebookSurvivesRelaunch() {
        app = configuredApplication()
        app.launchArguments = ["--lab=notes", "--reset-notebook"]
        app.launch()
        let collection = app.segmentedControls["notes-collection"]
        collection.buttons["My notebook"].tap()
        app.buttons["notes-new"].tap()
        let title = "C observation"
        let titleField = app.textFields["note-title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)
        let body = app.textViews["note-body"]
        body.tap()
        body.typeText("A shifted curve keeps its slope.")
        app.buttons["note-save"].tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
        app.terminate()
        launch("notes")
        app.segmentedControls["notes-collection"].buttons["My notebook"].tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["A shifted curve keeps its slope."].exists)
        screenshot("Notebook restored")
    }

    func testPlayableDemoNavigationAndTransport() {
        app = configuredApplication()
        app.launchArguments = ["--demo"]
        app.launch()
        let title = app.staticTexts["demo.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertEqual(title.label, "Why integrals have +C")
        let play = app.buttons["demo.play"]
        play.tap()
        XCTAssertEqual(play.label, "Pause")
        play.tap()
        XCTAssertEqual(play.label, "Play")
        app.buttons["demo.next"].tap()
        XCTAssertEqual(title.label, "One point chooses a curve")
        app.buttons["demo.chapter.code"].tap()
        XCTAssertEqual(title.label, "When division loses a fraction")
        app.buttons["demo.chapter.sound"].tap()
        XCTAssertEqual(title.label, "Hear the step from C to C♯")
        screenshot("Playable C sound scene")
        app.buttons["demo.close"].tap()
        XCTAssertTrue(app.buttons["atlas-demo"].waitForExistence(timeout: 5))
    }

    func testDemoKeyboardKeepsGuidedOctaveWhenTakingOver() throws {
        app = configuredApplication()
        app.launchArguments = ["--demo"]
        app.launch()
        let sound = app.buttons["demo.chapter.sound"]
        XCTAssertTrue(sound.waitForExistence(timeout: 15))
        sound.tap()
        app.buttons["demo.next"].tap()
        XCTAssertEqual(app.staticTexts["demo.title"].label, "Double a frequency")
        app.sliders["demo.progress"].adjust(toNormalizedSliderPosition: 0.55)
        let pitch = app.descendants(matching: .any)["demo.sound.pitch"]
        XCTAssertTrue((pitch.value as? String)?.contains("523.25") == true)
        let key = app.buttons["demo.sound.key.0"]
        reveal(key)
        XCTAssertTrue(key.label.contains("octave 5"))
        key.tap()
        returnUp(to: pitch)
        XCTAssertTrue((pitch.value as? String)?.contains("523.25") == true)
        XCTAssertEqual(app.buttons["demo.play"].label, "Play")
        screenshot("C5 demo keyboard takeover")
    }
}

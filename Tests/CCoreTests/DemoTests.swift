import XCTest
@testable import CCore

final class DemoTests: XCTestCase {
    func testPausedClockAndInvalidDeltasDoNotAdvance() {
        var demo = CDemoPlayback()
        demo.advance(by: 20)
        XCTAssertEqual(demo.progress, 0)
        demo.play()
        for delta in [Double.nan, .infinity, -1, 0] { demo.advance(by: delta) }
        XCTAssertEqual(demo.progress, 0)
        demo.advance(by: 6)
        XCTAssertEqual(demo.progress, 0.5)
        demo.pause()
        demo.advance(by: 20)
        XCTAssertEqual(demo.progress, 0.5)
    }

    func testSceneBoundaryPreservesRemainder() {
        var demo = CDemoPlayback()
        demo.play()
        demo.advance(by: CDemoStep.constant.duration + 2)
        XCTAssertEqual(demo.step, .anchor)
        XCTAssertEqual(demo.elapsed, 2)
        XCTAssertTrue(demo.isPlaying)
    }

    func testWholeTourFinishesAndCanRestart() {
        var demo = CDemoPlayback()
        demo.play()
        demo.advance(by: CDemoStep.allCases.reduce(0) { $0 + $1.duration } + 100)
        XCTAssertEqual(demo.step, .scale)
        XCTAssertEqual(demo.progress, 1)
        XCTAssertTrue(demo.hasFinished)
        XCTAssertFalse(demo.isPlaying)
        demo.play()
        XCTAssertEqual(demo.step, .constant)
        XCTAssertEqual(demo.progress, 0)
        XCTAssertFalse(demo.hasFinished)
    }

    func testManualNavigationScrubbingAndReplay() {
        var demo = CDemoPlayback()
        demo.play()
        demo.select(.aliases)
        XCTAssertFalse(demo.isPlaying)
        demo.seek(to: 2)
        XCTAssertEqual(demo.progress, 1)
        demo.seek(to: .nan)
        XCTAssertEqual(demo.progress, 1)
        demo.seek(to: -2)
        XCTAssertEqual(demo.progress, 0)
        demo.replay()
        XCTAssertTrue(demo.isPlaying)
        XCTAssertEqual(demo.step, .aliases)
        XCTAssertEqual(CDemoChapter.sound.firstStep, .semitone)
    }
}

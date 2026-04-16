import XCTest
import QuartzCore
@testable import MobilePT

final class SquatAnalyzerTests: XCTestCase {

    /// Creates a pose where both knees have the specified angle.
    private func makePose(kneeAngle: Double) -> BodyPose {
        let kneeL = (x: Float(0.4), y: Float(0.5))
        let kneeR = (x: Float(0.6), y: Float(0.5))
        let hipL = (x: Float(0.4), y: Float(0.3))  // MediaPipe: y increases downward, so hip is above knee = smaller y
        let hipR = (x: Float(0.6), y: Float(0.3))

        let radians = kneeAngle * .pi / 180.0
        let legLength: Float = 0.2
        let dy = legLength * Float(cos(radians))
        let dx = legLength * Float(sin(radians))

        // Ankle is below knee (larger y in MediaPipe coords)
        let ankleL = (x: kneeL.x + dx, y: kneeL.y + dy)
        let ankleR = (x: kneeR.x + dx, y: kneeR.y + dy)

        // Build 33 landmarks array, fill with defaults
        var landmarks = [(x: Float, y: Float, z: Float)](repeating: (x: 0.5, y: 0.5, z: 0), count: 33)
        var visibility = [Float](repeating: 0, count: 33)

        // Set the joints we care about
        let jointMap: [(PoseLandmark, (x: Float, y: Float))] = [
            (.nose, (0.5, 0.1)),
            (.leftShoulder, (0.4, 0.2)),
            (.rightShoulder, (0.6, 0.2)),
            (.leftHip, (hipL.x, hipL.y)),
            (.rightHip, (hipR.x, hipR.y)),
            (.leftKnee, (kneeL.x, kneeL.y)),
            (.rightKnee, (kneeR.x, kneeR.y)),
            (.leftAnkle, (ankleL.x, ankleL.y)),
            (.rightAnkle, (ankleR.x, ankleR.y)),
        ]

        for (landmark, pos) in jointMap {
            let idx = landmark.rawValue
            landmarks[idx] = (x: pos.x, y: pos.y, z: 0)
            visibility[idx] = 1.0
        }

        return BodyPose(landmarks: landmarks, visibility: visibility, timestamp: CACurrentMediaTime())
    }

    func testInitialState() {
        let analyzer = SquatAnalyzer()
        XCTAssertEqual(analyzer.state.phase, .standing)
        XCTAssertEqual(analyzer.state.repCount, 0)
    }

    func testReset() {
        var analyzer = SquatAnalyzer()
        _ = analyzer.analyze(pose: makePose(kneeAngle: 90))
        analyzer.reset()
        XCTAssertEqual(analyzer.state.repCount, 0)
        XCTAssertEqual(analyzer.state.phase, .standing)
    }

    func testPhaseTransition() {
        var analyzer = SquatAnalyzer()

        _ = analyzer.analyze(pose: makePose(kneeAngle: 170))
        XCTAssertEqual(analyzer.state.phase, .standing)

        _ = analyzer.analyze(pose: makePose(kneeAngle: 130))
        XCTAssertEqual(analyzer.state.phase, .descending)

        _ = analyzer.analyze(pose: makePose(kneeAngle: 90))
        XCTAssertEqual(analyzer.state.phase, .bottom)
    }

    func testFullRepCycle() {
        var analyzer = SquatAnalyzer()

        _ = analyzer.analyze(pose: makePose(kneeAngle: 170)) // standing
        _ = analyzer.analyze(pose: makePose(kneeAngle: 130)) // descending
        _ = analyzer.analyze(pose: makePose(kneeAngle: 90))  // bottom
        _ = analyzer.analyze(pose: makePose(kneeAngle: 120)) // ascending
        _ = analyzer.analyze(pose: makePose(kneeAngle: 170)) // standing → rep completed

        XCTAssertEqual(analyzer.state.repCount, 1)
        XCTAssertEqual(analyzer.state.phase, .standing)
    }
}

import XCTest
@testable import MobilePT

final class AngleCalculatorTests: XCTestCase {

    func testStraightLine() {
        // Three points in a straight line → 180 degrees
        let a = CGPoint(x: 0, y: 0)
        let b = CGPoint(x: 1, y: 0)
        let c = CGPoint(x: 2, y: 0)
        let angle = AngleCalculator.angle(a: a, b: b, c: c)
        XCTAssertEqual(angle, 180.0, accuracy: 0.1)
    }

    func testRightAngle() {
        // 90 degree angle
        let a = CGPoint(x: 0, y: 1)
        let b = CGPoint(x: 0, y: 0)
        let c = CGPoint(x: 1, y: 0)
        let angle = AngleCalculator.angle(a: a, b: b, c: c)
        XCTAssertEqual(angle, 90.0, accuracy: 0.1)
    }

    func testNilPoints() {
        // Nil points should return 180 (default standing)
        let angle = AngleCalculator.angle(a: nil, b: CGPoint.zero, c: nil)
        XCTAssertEqual(angle, 180.0)
    }

    func testAngleFromVertical() {
        // Perfectly vertical line
        let angle = AngleCalculator.angleFromVertical(
            top: CGPoint(x: 0.5, y: 1.0),
            bottom: CGPoint(x: 0.5, y: 0.0)
        )
        XCTAssertEqual(angle, 0.0, accuracy: 0.1)
    }

    func testAngleFromVertical45Degrees() {
        // 45 degree lean
        let angle = AngleCalculator.angleFromVertical(
            top: CGPoint(x: 1.0, y: 1.0),
            bottom: CGPoint(x: 0.0, y: 0.0)
        )
        XCTAssertEqual(angle, 45.0, accuracy: 0.1)
    }
}

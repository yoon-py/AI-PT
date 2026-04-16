import CoreGraphics
import Foundation

enum AngleCalculator {
    /// Angle at point B formed by segments BA and BC, in degrees (0-180)
    static func angle(a: CGPoint?, b: CGPoint?, c: CGPoint?) -> Double {
        guard let a, let b, let c else { return 180.0 }
        let ba = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let bc = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = ba.dx * bc.dx + ba.dy * bc.dy
        let magBA = sqrt(ba.dx * ba.dx + ba.dy * ba.dy)
        let magBC = sqrt(bc.dx * bc.dx + bc.dy * bc.dy)
        guard magBA > 0, magBC > 0 else { return 180.0 }
        let cosAngle = max(-1, min(1, dot / (magBA * magBC)))
        return acos(cosAngle) * 180.0 / .pi
    }

    /// Angle of a line segment from the vertical axis, in degrees
    static func angleFromVertical(top: CGPoint?, bottom: CGPoint?) -> Double {
        guard let top, let bottom else { return 0.0 }
        let dx = top.x - bottom.x
        let dy = top.y - bottom.y
        guard dy != 0 else { return 90.0 }
        return abs(atan2(dx, dy)) * 180.0 / .pi
    }
}

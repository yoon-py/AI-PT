import Foundation
import CoreGraphics

/// BlazePose 33 landmark indices
enum PoseLandmark: Int, CaseIterable, Sendable {
    case nose = 0
    case leftEyeInner = 1
    case leftEye = 2
    case leftEyeOuter = 3
    case rightEyeInner = 4
    case rightEye = 5
    case rightEyeOuter = 6
    case leftEar = 7
    case rightEar = 8
    case mouthLeft = 9
    case mouthRight = 10
    case leftShoulder = 11
    case rightShoulder = 12
    case leftElbow = 13
    case rightElbow = 14
    case leftWrist = 15
    case rightWrist = 16
    case leftPinky = 17
    case rightPinky = 18
    case leftIndex = 19
    case rightIndex = 20
    case leftThumb = 21
    case rightThumb = 22
    case leftHip = 23
    case rightHip = 24
    case leftKnee = 25
    case rightKnee = 26
    case leftAnkle = 27
    case rightAnkle = 28
    case leftHeel = 29
    case rightHeel = 30
    case leftFootIndex = 31
    case rightFootIndex = 32
}

struct BodyPose: Sendable {
    /// 33 landmarks: normalized (x, y) + z depth
    let landmarks: [(x: Float, y: Float, z: Float)]
    /// Visibility score per landmark
    let visibility: [Float]
    let timestamp: TimeInterval

    /// Get 2D point for a landmark (nil if not visible enough)
    func point(for landmark: PoseLandmark) -> CGPoint? {
        let idx = landmark.rawValue
        guard idx < landmarks.count else { return nil }
        guard visibility[idx] > 0.5 else { return nil }
        let lm = landmarks[idx]
        return CGPoint(x: CGFloat(lm.x), y: CGFloat(lm.y))
    }

    /// Get 3D position (x, y, z) for a landmark
    func point3D(for landmark: PoseLandmark) -> (x: Float, y: Float, z: Float)? {
        let idx = landmark.rawValue
        guard idx < landmarks.count else { return nil }
        guard visibility[idx] > 0.5 else { return nil }
        return landmarks[idx]
    }

    /// Midpoint between two landmarks
    func midpoint(of a: PoseLandmark, _ b: PoseLandmark) -> CGPoint? {
        guard let pa = point(for: a), let pb = point(for: b) else { return nil }
        return CGPoint(x: (pa.x + pb.x) / 2, y: (pa.y + pb.y) / 2)
    }
}

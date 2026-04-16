import SwiftUI

struct PoseOverlayView: View {
    let pose: BodyPose

    // Video aspect adapts to current device orientation
    private var videoAspect: CGFloat {
        let orientation = UIDevice.current.orientation
        if orientation.isLandscape {
            return 1280.0 / 720.0
        }
        return 720.0 / 1280.0
    }

    // Body skeleton connections (face excluded)
    private static let connections: [(PoseLandmark, PoseLandmark)] = [
        // Torso
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        // Left arm
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        // Right arm
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        // Left leg
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.leftAnkle, .leftHeel), (.leftAnkle, .leftFootIndex), (.leftHeel, .leftFootIndex),
        // Right leg
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        (.rightAnkle, .rightHeel), (.rightAnkle, .rightFootIndex), (.rightHeel, .rightFootIndex),
    ]

    // Body landmarks only (no face)
    private static let bodyLandmarks: [PoseLandmark] = [
        .leftShoulder, .rightShoulder,
        .leftElbow, .rightElbow,
        .leftWrist, .rightWrist,
        .leftHip, .rightHip,
        .leftKnee, .rightKnee,
        .leftAnkle, .rightAnkle,
        .leftHeel, .rightHeel,
        .leftFootIndex, .rightFootIndex,
    ]

    // Key joint labels (mirrored for front camera — MediaPipe left = user's right)
    private static let jointLabels: [(PoseLandmark, String)] = [
        (.leftShoulder, "우어깨"), (.rightShoulder, "좌어깨"),
        (.leftElbow, "우팔꿈치"), (.rightElbow, "좌팔꿈치"),
        (.leftWrist, "우손목"), (.rightWrist, "좌손목"),
        (.leftHip, "우엉덩이"), (.rightHip, "좌엉덩이"),
        (.leftKnee, "우무릎"), (.rightKnee, "좌무릎"),
        (.leftAnkle, "우발목"), (.rightAnkle, "좌발목"),
    ]

    var body: some View {
        Canvas { context, size in
            // Draw connections
            for (from, to) in Self.connections {
                guard let p1 = pose.point(for: from),
                      let p2 = pose.point(for: to) else { continue }
                let s1 = toScreen(p1, in: size)
                let s2 = toScreen(p2, in: size)
                var path = Path()
                path.move(to: s1)
                path.addLine(to: s2)

                // Color: green for body, cyan for hands/feet
                let isExtremity = [from, to].contains(where: {
                    [.leftPinky, .rightPinky, .leftIndex, .rightIndex, .leftThumb, .rightThumb,
                     .leftHeel, .rightHeel, .leftFootIndex, .rightFootIndex].contains($0)
                })
                let color: Color = isExtremity ? .cyan : .green
                context.stroke(path, with: .color(color), lineWidth: 3)
            }

            // Draw head-neck-spine (nose → neck → mid-spine → pelvis)
            let nosePoint = pose.point(for: .nose)
            let neck = pose.midpoint(of: .leftShoulder, .rightShoulder)
            let pelvis = pose.midpoint(of: .leftHip, .rightHip)
            if let neck, let pelvis {
                let midSpine = CGPoint(x: (neck.x + pelvis.x) / 2, y: (neck.y + pelvis.y) / 2)
                let sNeck = toScreen(neck, in: size)
                let sMid = toScreen(midSpine, in: size)
                let sPelvis = toScreen(pelvis, in: size)

                // Nose → Neck line
                if let nosePoint {
                    let sNose = toScreen(nosePoint, in: size)
                    var headPath = Path()
                    headPath.move(to: sNose)
                    headPath.addLine(to: sNeck)
                    context.stroke(headPath, with: .color(.orange), lineWidth: 3)

                    // Head dot
                    let headRect = CGRect(x: sNose.x - 6, y: sNose.y - 6, width: 12, height: 12)
                    context.fill(Path(ellipseIn: headRect), with: .color(.orange))
                    let headLabel = Text("머리")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    context.draw(headLabel, at: CGPoint(x: sNose.x, y: sNose.y - 14))

                    // Neck tilt angle
                    let neckAngle = AngleCalculator.angleFromVertical(top: nosePoint, bottom: neck)
                    let angleColor: Color = neckAngle > 20 ? .red : .white
                    let angleText = Text("\(Int(neckAngle))°")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(angleColor)
                    let angleLabelPos = CGPoint(x: (sNose.x + sNeck.x) / 2 + 20, y: (sNose.y + sNeck.y) / 2)
                    context.draw(angleText, at: angleLabelPos)
                }

                // Spine line (neck → mid → pelvis)
                var spinePath = Path()
                spinePath.move(to: sNeck)
                spinePath.addLine(to: sMid)
                spinePath.addLine(to: sPelvis)
                context.stroke(spinePath, with: .color(.yellow), lineWidth: 4)

                // Spine joints
                for (sp, label) in [(sNeck, "목"), (sMid, "척추"), (sPelvis, "골반")] {
                    let rect = CGRect(x: sp.x - 6, y: sp.y - 6, width: 12, height: 12)
                    context.fill(Path(ellipseIn: rect), with: .color(.yellow))
                    let text = Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    context.draw(text, at: CGPoint(x: sp.x, y: sp.y - 14))
                }
            }

            // Draw key joints with labels
            for (joint, label) in Self.jointLabels {
                guard let point = pose.point(for: joint) else { continue }
                let sp = toScreen(point, in: size)

                let rect = CGRect(x: sp.x - 6, y: sp.y - 6, width: 12, height: 12)
                context.fill(Path(ellipseIn: rect), with: .color(.yellow))

                let text = Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                context.draw(text, at: CGPoint(x: sp.x, y: sp.y - 14))
            }

            // Draw remaining body joints (smaller, no label)
            for landmark in Self.bodyLandmarks {
                if Self.jointLabels.contains(where: { $0.0 == landmark }) { continue }
                guard let point = pose.point(for: landmark) else { continue }
                let sp = toScreen(point, in: size)
                let rect = CGRect(x: sp.x - 4, y: sp.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: rect), with: .color(.orange.opacity(0.8)))
            }
        }
    }

    /// Convert MediaPipe normalized coordinates to screen coordinates,
    /// accounting for resizeAspectFill cropping.
    ///
    /// MediaPipe: origin TOP-left, (0,0)→(1,1) — unlike Vision which is bottom-left
    /// Screen: origin top-left
    private func toScreen(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let viewAspect = size.width / size.height

        let screenX: CGFloat
        let screenY: CGFloat

        if videoAspect > viewAspect {
            // Video wider → width cropped
            let visibleFraction = viewAspect / videoAspect
            let offset = (1 - visibleFraction) / 2
            screenX = (point.x - offset) / visibleFraction * size.width
            screenY = point.y * size.height  // MediaPipe Y is already top-down
        } else {
            // Video taller → height cropped
            let visibleFraction = videoAspect / viewAspect
            let offset = (1 - visibleFraction) / 2
            screenX = point.x * size.width
            screenY = (point.y - offset) / visibleFraction * size.height
        }

        return CGPoint(x: screenX, y: screenY)
    }
}

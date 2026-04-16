import Foundation

struct PushUpAnalyzer: ExerciseAnalyzer {
    let exerciseName = "푸쉬업"
    private(set) var state = ExerciseState()

    // Elbow angle thresholds
    private let elbowAnglePlank: Double = 155
    private let elbowAngleDescending: Double = 130
    private let elbowAngleBottom: Double = 95

    // Form thresholds
    private let maxBodyLineDeviation: Double = 25  // shoulder-hip-ankle should be ~180°
    private let maxHipSag: Double = 160             // body angle below this = hips sagging
    private let maxHipPike: Double = 195            // body angle above this = hips piking
    private let maxAsymmetry: Double = 15

    private var reachedProperDepth = false
    private var isInPosition = false

    mutating func analyze(pose: BodyPose) -> [FeedbackMessage] {
        var feedback: [FeedbackMessage] = []

        // Elbow angles
        let leftElbowAngle = AngleCalculator.angle(
            a: pose.point(for: .leftShoulder),
            b: pose.point(for: .leftElbow),
            c: pose.point(for: .leftWrist)
        )
        let rightElbowAngle = AngleCalculator.angle(
            a: pose.point(for: .rightShoulder),
            b: pose.point(for: .rightElbow),
            c: pose.point(for: .rightWrist)
        )
        let avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2.0

        state.currentAngles["leftElbow"] = leftElbowAngle
        state.currentAngles["rightElbow"] = rightElbowAngle
        state.currentAngles["avgElbow"] = avgElbowAngle

        // Body line angle (shoulder → hip → ankle)
        let bodyLineAngle = AngleCalculator.angle(
            a: pose.midpoint(of: .leftShoulder, .rightShoulder),
            b: pose.midpoint(of: .leftHip, .rightHip),
            c: pose.midpoint(of: .leftAnkle, .rightAnkle)
        )
        state.currentAngles["bodyLine"] = bodyLineAngle

        // Check if person is in push-up position (horizontal-ish)
        let shoulderY = pose.midpoint(of: .leftShoulder, .rightShoulder)?.y ?? 0
        let hipY = pose.midpoint(of: .leftHip, .rightHip)?.y ?? 0
        let ankleY = pose.midpoint(of: .leftAnkle, .rightAnkle)?.y ?? 0
        let isHorizontal = abs(CGFloat(shoulderY) - CGFloat(ankleY)) < 0.25

        if !isInPosition && isHorizontal && avgElbowAngle > elbowAnglePlank {
            isInPosition = true
            state.phase = .plankPosition
        }

        guard isInPosition else {
            feedback.append(FeedbackMessage(
                text: "푸쉬업 자세를 잡아주세요",
                type: .positionWarning,
                priority: 9
            ))
            return feedback
        }

        // Phase state machine
        switch state.phase {
        case .plankPosition:
            reachedProperDepth = false
            if avgElbowAngle < elbowAngleDescending {
                state.phase = .descending
            }

        case .descending:
            if avgElbowAngle <= elbowAngleBottom {
                state.phase = .bottom
                reachedProperDepth = true
            } else if avgElbowAngle >= elbowAnglePlank {
                state.phase = .plankPosition
            }

        case .bottom:
            if avgElbowAngle > elbowAngleBottom + 10 {
                state.phase = .ascending
            }

        case .ascending:
            if avgElbowAngle >= elbowAnglePlank {
                state.phase = .plankPosition
                state.repCount += 1
                let repText = reachedProperDepth
                    ? "\(state.repCount)회 완료! 좋아요"
                    : "\(state.repCount)회 — 더 내려가세요"
                feedback.append(FeedbackMessage(
                    text: repText,
                    type: reachedProperDepth ? .encouragement : .repCount,
                    priority: 5
                ))
            }

        default:
            state.phase = .plankPosition
        }

        // Form checks
        if state.phase == .descending || state.phase == .bottom || state.phase == .plankPosition {
            state.isFormCorrect = true

            // Body line check (hip sag / pike)
            if bodyLineAngle < maxHipSag {
                state.isFormCorrect = false
                feedback.append(FeedbackMessage(
                    text: "엉덩이가 처졌어요. 몸을 일직선으로!",
                    type: .correction,
                    priority: 8
                ))
            } else if bodyLineAngle > maxHipPike {
                state.isFormCorrect = false
                feedback.append(FeedbackMessage(
                    text: "엉덩이가 너무 올라갔어요. 낮추세요!",
                    type: .correction,
                    priority: 8
                ))
            }

            // Elbow asymmetry
            let asymmetry = abs(leftElbowAngle - rightElbowAngle)
            if asymmetry > maxAsymmetry {
                state.isFormCorrect = false
                feedback.append(FeedbackMessage(
                    text: "양팔 균형을 맞추세요",
                    type: .correction,
                    priority: 6
                ))
            }

            // Hand width check (wrists should be ~shoulder width)
            if let lw = pose.point(for: .leftWrist),
               let rw = pose.point(for: .rightWrist),
               let ls = pose.point(for: .leftShoulder),
               let rs = pose.point(for: .rightShoulder) {
                let wristWidth = abs(rw.x - lw.x)
                let shoulderWidth = abs(rs.x - ls.x)
                let ratio = Double(wristWidth / shoulderWidth)
                state.currentAngles["handWidth"] = ratio

                if ratio < 0.7 {
                    feedback.append(FeedbackMessage(
                        text: "손을 더 벌리세요. 어깨 너비로!",
                        type: .correction,
                        priority: 6
                    ))
                } else if ratio > 1.5 {
                    feedback.append(FeedbackMessage(
                        text: "손이 너무 넓어요. 어깨 너비로 좁히세요!",
                        type: .correction,
                        priority: 6
                    ))
                }
            }

            // Hand position check (wrists should be under shoulders, not too far forward)
            if let wristY = pose.midpoint(of: .leftWrist, .rightWrist)?.y,
               let shoulderY = pose.midpoint(of: .leftShoulder, .rightShoulder)?.y {
                let diff = Double(abs(wristY - shoulderY))
                if diff > 0.15 {
                    feedback.append(FeedbackMessage(
                        text: "손을 어깨 바로 아래에 두세요!",
                        type: .correction,
                        priority: 7
                    ))
                }
            }

            // Neck check
            let neckAngle = AngleCalculator.angleFromVertical(
                top: pose.point(for: .nose),
                bottom: pose.midpoint(of: .leftShoulder, .rightShoulder)
            )
            state.currentAngles["neck"] = neckAngle
            if neckAngle > 35 {
                feedback.append(FeedbackMessage(
                    text: "고개를 들지 마세요. 목을 중립으로!",
                    type: .correction,
                    priority: 5
                ))
            }
        }

        if state.phase == .ascending && !reachedProperDepth {
            feedback.append(FeedbackMessage(
                text: "팔꿈치를 90도까지 굽히세요",
                type: .correction,
                priority: 7
            ))
        }

        return feedback
    }

    mutating func reset() {
        state = ExerciseState()
        state.phase = .plankPosition
        reachedProperDepth = false
        isInPosition = false
    }
}

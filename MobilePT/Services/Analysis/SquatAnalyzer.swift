import Foundation

struct SquatAnalyzer: ExerciseAnalyzer {
    let exerciseName = "스쿼트"
    private(set) var state = ExerciseState()

    // Phase transition thresholds (degrees)
    private let kneeAngleStanding: Double = 160
    private let kneeAngleDescending: Double = 140
    private let kneeAngleBottom: Double = 100

    // Form check thresholds
    private let minKneeWidth: Double = 0.08
    private let maxTorsoLean: Double = 45.0
    private let maxAsymmetry: Double = 15.0

    private var reachedProperDepth = false

    mutating func analyze(pose: BodyPose) -> [FeedbackMessage] {
        var feedback: [FeedbackMessage] = []

        let leftKneeAngle = AngleCalculator.angle(
            a: pose.point(for: .leftHip),
            b: pose.point(for: .leftKnee),
            c: pose.point(for: .leftAnkle)
        )
        let rightKneeAngle = AngleCalculator.angle(
            a: pose.point(for: .rightHip),
            b: pose.point(for: .rightKnee),
            c: pose.point(for: .rightAnkle)
        )
        let avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2.0

        state.currentAngles["leftKnee"] = leftKneeAngle
        state.currentAngles["rightKnee"] = rightKneeAngle
        state.currentAngles["avgKnee"] = avgKneeAngle

        // Phase state machine
        switch state.phase {
        case .standing:
            reachedProperDepth = false
            if avgKneeAngle < kneeAngleDescending {
                state.phase = .descending
            }

        case .descending:
            if avgKneeAngle <= kneeAngleBottom {
                state.phase = .bottom
                reachedProperDepth = true
            } else if avgKneeAngle >= kneeAngleStanding {
                state.phase = .standing
            }

        case .bottom:
            if avgKneeAngle > kneeAngleBottom + 10 {
                state.phase = .ascending
            }

        case .ascending:
            if avgKneeAngle >= kneeAngleStanding {
                state.phase = .standing
                state.repCount += 1
                let repText = reachedProperDepth
                    ? "\(state.repCount)회 완료! 잘하고 있어요"
                    : "\(state.repCount)회 완료"
                feedback.append(FeedbackMessage(
                    text: repText,
                    type: reachedProperDepth ? .encouragement : .repCount,
                    priority: 5
                ))
            }

        default:
            break
        }

        // Form checks during descending/bottom phases
        if state.phase == .descending || state.phase == .bottom {
            state.isFormCorrect = true

            // Knee valgus check
            if let lk = pose.point(for: .leftKnee),
               let rk = pose.point(for: .rightKnee) {
                let kneeWidth = abs(rk.x - lk.x)
                if kneeWidth < minKneeWidth {
                    state.isFormCorrect = false
                    feedback.append(FeedbackMessage(
                        text: "무릎을 더 벌리세요",
                        type: .correction,
                        priority: 8
                    ))
                }
            }

            // Torso lean check
            let torsoAngle = AngleCalculator.angleFromVertical(
                top: pose.midpoint(of: .leftShoulder, .rightShoulder),
                bottom: pose.midpoint(of: .leftHip, .rightHip)
            )
            state.currentAngles["torso"] = torsoAngle
            if torsoAngle > maxTorsoLean {
                state.isFormCorrect = false
                feedback.append(FeedbackMessage(
                    text: "상체를 더 세워주세요",
                    type: .correction,
                    priority: 7
                ))
            }

            // Asymmetry check
            let asymmetry = abs(leftKneeAngle - rightKneeAngle)
            if asymmetry > maxAsymmetry {
                state.isFormCorrect = false
                feedback.append(FeedbackMessage(
                    text: "양쪽 균형을 맞추세요",
                    type: .correction,
                    priority: 6
                ))
            }

            // Knee over toes check (using 3D z-depth)
            if let kneeZ = pose.point3D(for: .leftKnee)?.z,
               let ankleZ = pose.point3D(for: .leftAnkle)?.z {
                if kneeZ < ankleZ - 0.05 {
                    feedback.append(FeedbackMessage(
                        text: "무릎이 발끝을 넘지 않게 하세요",
                        type: .correction,
                        priority: 7
                    ))
                }
            }
        }

        if state.phase == .ascending && !reachedProperDepth {
            feedback.append(FeedbackMessage(
                text: "더 깊이 앉으세요",
                type: .correction,
                priority: 6
            ))
        }

        return feedback
    }

    mutating func reset() {
        state = ExerciseState()
        reachedProperDepth = false
    }
}

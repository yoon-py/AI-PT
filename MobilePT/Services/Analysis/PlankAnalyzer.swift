import Foundation

struct PlankAnalyzer: ExerciseAnalyzer {
    let exerciseName = "플랭크"
    private(set) var state = ExerciseState()

    // Form thresholds
    private let goodBodyLineMin: Double = 160   // shoulder-hip-ankle angle
    private let goodBodyLineMax: Double = 190
    private let maxNeckTilt: Double = 30

    private var holdStartTime: Date?
    private var isInPosition = false
    private var lastFormCheckTime: Date?

    mutating func analyze(pose: BodyPose) -> [FeedbackMessage] {
        var feedback: [FeedbackMessage] = []

        // Body line angle (shoulder → hip → ankle)
        let bodyLineAngle = AngleCalculator.angle(
            a: pose.midpoint(of: .leftShoulder, .rightShoulder),
            b: pose.midpoint(of: .leftHip, .rightHip),
            c: pose.midpoint(of: .leftAnkle, .rightAnkle)
        )
        state.currentAngles["bodyLine"] = bodyLineAngle

        // Elbow angles (for position detection)
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
        state.currentAngles["avgElbow"] = avgElbowAngle

        // Neck angle
        let neckAngle = AngleCalculator.angleFromVertical(
            top: pose.point(for: .nose),
            bottom: pose.midpoint(of: .leftShoulder, .rightShoulder)
        )
        state.currentAngles["neck"] = neckAngle

        // Check if person is in plank position
        let shoulderY = pose.midpoint(of: .leftShoulder, .rightShoulder)?.y ?? 0
        let ankleY = pose.midpoint(of: .leftAnkle, .rightAnkle)?.y ?? 0
        let isHorizontal = abs(CGFloat(shoulderY) - CGFloat(ankleY)) < 0.25

        // Plank: elbows bent (~90°) or straight arms
        let isPlankArms = avgElbowAngle < 120 || avgElbowAngle > 155

        if !isInPosition && isHorizontal && isPlankArms {
            isInPosition = true
            holdStartTime = Date()
            state.phase = .holding
            feedback.append(FeedbackMessage(
                text: "플랭크 시작! 자세를 유지하세요",
                type: .encouragement,
                priority: 5
            ))
        }

        guard isInPosition else {
            state.phase = .standing
            feedback.append(FeedbackMessage(
                text: "플랭크 자세를 잡아주세요",
                type: .positionWarning,
                priority: 9
            ))
            return feedback
        }

        // Update hold time
        if let start = holdStartTime {
            state.holdTime = Date().timeIntervalSince(start)
        }

        // Lost position?
        if !isHorizontal {
            isInPosition = false
            holdStartTime = nil
            state.phase = .standing
            feedback.append(FeedbackMessage(
                text: "자세가 풀렸어요. 다시 잡아주세요",
                type: .positionWarning,
                priority: 9
            ))
            return feedback
        }

        state.phase = .holding
        state.isFormCorrect = true

        // Form checks (throttle to avoid spam)
        let now = Date()
        let shouldCheck = lastFormCheckTime == nil || now.timeIntervalSince(lastFormCheckTime!) > 2.0

        if shouldCheck {
            lastFormCheckTime = now

            // Hip sag
            if bodyLineAngle < goodBodyLineMin {
                state.isFormCorrect = false
                feedback.append(FeedbackMessage(
                    text: "엉덩이가 처졌어요! 올려주세요",
                    type: .correction,
                    priority: 8
                ))
            }

            // Hip pike
            if bodyLineAngle > goodBodyLineMax {
                state.isFormCorrect = false
                feedback.append(FeedbackMessage(
                    text: "엉덩이가 너무 높아요! 낮추세요",
                    type: .correction,
                    priority: 8
                ))
            }

            // Neck
            if neckAngle > maxNeckTilt {
                feedback.append(FeedbackMessage(
                    text: "고개를 숙이지 마세요. 정면을 보세요",
                    type: .correction,
                    priority: 5
                ))
            }
        }

        // Encouragement at milestones
        let seconds = Int(state.holdTime)
        if seconds > 0 && seconds % 15 == 0 {
            let prevSeconds = Int(state.holdTime - 1.0/30.0)
            if prevSeconds % 15 != 0 {
                feedback.append(FeedbackMessage(
                    text: "\(seconds)초! 잘 버티고 있어요",
                    type: .encouragement,
                    priority: 4
                ))
            }
        }

        return feedback
    }

    mutating func reset() {
        state = ExerciseState()
        holdStartTime = nil
        isInPosition = false
        lastFormCheckTime = nil
    }
}

import AVFoundation
import Combine
import SwiftUI

@MainActor
final class ExerciseViewModel: ObservableObject {
    @Published var currentPose: BodyPose?
    @Published var exerciseState = ExerciseState()
    @Published var latestFeedback: FeedbackMessage?
    @Published var isSessionActive = false
    @Published var isAICoachConnected = false
    @Published var debugStatus: String = "초기화 중..."
    @Published var frameCount: Int = 0

    let cameraManager = CameraManager()
    private let poseDetector = PoseDetector()
    private var analyzer: any ExerciseAnalyzer
    private let feedbackEngine = FeedbackEngine()
    private var poseSmoother = PoseSmoother()
    private var displayLink: CADisplayLink?

    let exerciseType: ExerciseType
    let realtimeService: OpenAIRealtimeService

    init(exercise: ExerciseType = .squat) {
        self.exerciseType = exercise
        let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String
            ?? ""
        self.realtimeService = OpenAIRealtimeService(apiKey: apiKey)
        switch exercise {
        case .squat:
            self.analyzer = SquatAnalyzer()
        case .pushUp:
            self.analyzer = PushUpAnalyzer()
        case .plank:
            self.analyzer = PlankAnalyzer()
        }
        setupPipeline()
    }

    private func setupPipeline() {
        let detector = poseDetector
        cameraManager.onFrameCaptured = { [weak self] sampleBuffer, timestampMs in
            detector.detectAsync(sampleBuffer: sampleBuffer, timestampMs: timestampMs)
            DispatchQueue.main.async {
                self?.frameCount += 1
            }
        }
    }

    /// Called by display link to poll latest pose result
    @objc private func pollPose() {
        // Show detector errors on screen
        if let err = poseDetector.lastError {
            debugStatus = "ERR: \(err)"
            return
        }

        let delegateOk = poseDetector.delegateCalled

        guard let pose = poseDetector.getLatestPose() else {
            if frameCount > 0 {
                debugStatus = delegateOk
                    ? "delegate 호출됨 - pose nil (\(frameCount))"
                    : "delegate 미호출 (\(frameCount)프레임)"
            }
            return
        }
        let smoothed = poseSmoother.smooth(pose)
        let feedback = analyzer.analyze(pose: smoothed)
        currentPose = smoothed
        exerciseState = analyzer.state
        feedbackEngine.process(feedback)
        latestFeedback = feedbackEngine.latestFeedback

        // Send pose context + feedback to OpenAI
        if isAICoachConnected {
            var context = buildPoseContext(smoothed)
            if !feedback.isEmpty {
                let feedbackTexts = feedback.map { $0.text }.joined(separator: ", ")
                context += " | 피드백: \(feedbackTexts)"
            }
            realtimeService.updatePoseContext(context)
        }
    }

    private func buildPoseContext(_ pose: BodyPose) -> String {
        var parts: [String] = []
        parts.append("운동: \(exerciseType.rawValue)")
        parts.append("단계: \(exerciseState.phase.rawValue)")
        parts.append("반복: \(exerciseState.repCount)회")

        if exerciseType == .plank {
            parts.append("유지시간: \(Int(exerciseState.holdTime))초")
        }

        for (key, value) in exerciseState.currentAngles {
            parts.append("\(key): \(Int(value))°")
        }

        parts.append("폼 정확: \(exerciseState.isFormCorrect ? "O" : "X")")

        return parts.joined(separator: ", ")
    }

    func startSession() {
        analyzer.reset()
        feedbackEngine.reset()
        poseSmoother.reset()
        isSessionActive = true

        debugStatus = poseDetector.isReady ? "모델 로드 완료" : "모델 로드 실패!"

        cameraManager.onConfigured = { [weak self] in
            guard let self else { return }
            self.cameraManager.startSession()

            self.displayLink = CADisplayLink(target: self, selector: #selector(self.pollPose))
            self.displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
            self.displayLink?.add(to: .main, forMode: .common)
        }

        cameraManager.checkAuthorization()
    }

    func toggleAICoach() {
        if isAICoachConnected {
            realtimeService.disconnect()
            isAICoachConnected = false
            feedbackEngine.muteLocalVoice = false
        } else {
            realtimeService.connect(exerciseType: exerciseType.rawValue)
            isAICoachConnected = true
            feedbackEngine.muteLocalVoice = true
        }
    }

    func stopSession() {
        cameraManager.stopSession()
        isSessionActive = false
        displayLink?.invalidate()
        displayLink = nil
        if isAICoachConnected {
            realtimeService.disconnect()
            isAICoachConnected = false
        }
    }
}

// MARK: - Temporal smoothing

private struct PoseSmoother {
    private var previous: [(x: Float, y: Float, z: Float)]?
    private let alpha: Float = 0.4

    mutating func smooth(_ pose: BodyPose) -> BodyPose {
        guard let prev = previous, prev.count == pose.landmarks.count else {
            previous = pose.landmarks
            return pose
        }

        var smoothed: [(x: Float, y: Float, z: Float)] = []
        for i in 0..<pose.landmarks.count {
            let cur = pose.landmarks[i]
            let p = prev[i]
            smoothed.append((
                x: p.x + alpha * (cur.x - p.x),
                y: p.y + alpha * (cur.y - p.y),
                z: p.z + alpha * (cur.z - p.z)
            ))
        }

        previous = smoothed
        return BodyPose(landmarks: smoothed, visibility: pose.visibility, timestamp: pose.timestamp)
    }

    mutating func reset() {
        previous = nil
    }
}

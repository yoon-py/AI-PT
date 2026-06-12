import AVFoundation
import Combine
import SwiftUI

@MainActor
final class ExerciseViewModel: ObservableObject {
    @Published var currentPose: BodyPose?
    @Published var exerciseState = ExerciseState()
    @Published var latestFeedback: FeedbackMessage?
    @Published var isSessionActive = false
    /// True when no OpenAI key is configured — voice coaching is silent.
    @Published var voiceUnavailable = false
    /// 준비 카운트다운이 끝나기 전엔 false — 반복/코칭 측정을 멈춰둔다(스켈레톤은 계속 표시).
    @Published var analysisEnabled = false
    @Published var debugStatus: String = "초기화 중..."
    @Published var frameCount: Int = 0

    let cameraManager = CameraManager()
    private let poseDetector = PoseDetector()
    private var analyzer: any ExerciseAnalyzer
    private let ttsService: OpenAITTSService
    private let llmCoach: LLMCoachService
    private var poseSmoother = PoseSmoother()
    private var displayLink: CADisplayLink?

    let exerciseType: ExerciseType

    init(exercise: ExerciseType = .squat, inBody: InBodyResult? = nil) {
        self.exerciseType = exercise
        // 로컬 데모는 Xcode Scheme 환경변수 OPENAI_API_KEY로만 켠다.
        let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            ?? Secrets.openAIAPIKey
        let tts = OpenAITTSService(apiKey: apiKey)
        self.ttsService = tts
        self.llmCoach = LLMCoachService(
            apiKey: apiKey,
            exerciseType: exercise.rawValue,
            userProfile: inBody?.coachProfileSummary
        )
        self.voiceUnavailable = !tts.isConfigured
        switch exercise.analyzerKind {
        case .squat:
            self.analyzer = SquatAnalyzer()
        case .pushUp:
            self.analyzer = PushUpAnalyzer()
        case .plank:
            self.analyzer = PlankAnalyzer()
        }
        setupPipeline()
        // LLM이 코칭 문장을 주면 화면 배너 + 음성으로 전달
        llmCoach.onCoaching = { [weak self] line in
            Task { @MainActor in self?.handleCoaching(line) }
        }
    }

    @MainActor
    private func handleCoaching(_ line: String) {
        latestFeedback = FeedbackMessage(text: line, type: .coaching, priority: 5)
        ttsService.speak(line)
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
        currentPose = smoothed

        // 준비 카운트다운 중에는 스켈레톤만 보여주고 측정/코칭은 멈춤
        guard analysisEnabled else { return }

        // analyzer = 객관적 측정 (각도, 단계, 반복수, 규칙 기반 감지)
        let ruleFeedback = analyzer.analyze(pose: smoothed)
        exerciseState = analyzer.state

        // 측정 결과를 요약해 LLM에 전달 → 전문가 판단을 코칭 문장으로 받음
        // (간격 제한·중복 제거는 LLMCoachService 내부에서 처리)
        let context = buildPoseContext(detectedSignals: ruleFeedback)
        llmCoach.coach(context: context)
    }

    /// 센서 측정값을 LLM이 읽을 수 있는 요약 텍스트로 변환
    private func buildPoseContext(detectedSignals: [FeedbackMessage]) -> String {
        var parts: [String] = []
        parts.append("운동: \(exerciseType.rawValue)")
        parts.append("단계: \(exerciseState.phase.rawValue)")
        parts.append("반복: \(exerciseState.repCount)회")

        if exerciseType.analyzerKind == .plank {
            parts.append("유지시간: \(Int(exerciseState.holdTime))초")
        }

        for (key, value) in exerciseState.currentAngles {
            parts.append("\(key): \(Int(value))도")
        }

        parts.append("폼정확: \(exerciseState.isFormCorrect ? "정상" : "문제있음")")

        if !detectedSignals.isEmpty {
            let signals = detectedSignals.map { $0.text }.joined(separator: ", ")
            parts.append("센서감지: \(signals)")
        }

        return parts.joined(separator: ", ")
    }

    /// 준비 카운트다운 종료 후 측정/코칭 시작
    func enableAnalysis() { analysisEnabled = true }

    /// 운동 시작 음성 안내 (TTS)
    func announceIntro(goal: Int) {
        let unit = exerciseType.goalUnit
        ttsService.speak("\(exerciseType.rawValue) \(goal)\(unit) 시작합니다. 천천히 따라오세요.")
    }

    func startSession() {
        analyzer.reset()
        llmCoach.reset()
        poseSmoother.reset()
        analysisEnabled = false
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

    func stopSession() {
        cameraManager.stopSession()
        isSessionActive = false
        displayLink?.invalidate()
        displayLink = nil
        ttsService.stop()
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

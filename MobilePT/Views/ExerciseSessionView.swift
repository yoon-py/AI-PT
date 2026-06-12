import SwiftUI

struct ExerciseSessionView: View {
    @StateObject private var viewModel: ExerciseViewModel
    private let goal: Int
    /// 운동을 마치면 완료 횟수(플랭크는 초)를 전달한다.
    private let onFinish: (Int) -> Void

    init(exercise: ExerciseType, goal: Int, inBody: InBodyResult?, onFinish: @escaping (Int) -> Void) {
        _viewModel = StateObject(wrappedValue: ExerciseViewModel(exercise: exercise, inBody: inBody))
        self.goal = goal
        self.onFinish = onFinish
    }

    private var completedCount: Int {
        viewModel.exerciseType.analyzerKind == .plank
            ? Int(viewModel.exerciseState.holdTime)
            : viewModel.exerciseState.repCount
    }

    private var goalReached: Bool { completedCount >= goal }

    /// 준비 카운트다운 (3·2·1·시작!). nil이면 종료.
    @State private var countdown: Int? = 3

    var body: some View {
        ZStack {
            // Layer 1: Camera preview
            CameraPreviewView(session: viewModel.cameraManager.captureSession)
                .ignoresSafeArea()

            // Layer 2: Skeleton overlay
            if let pose = viewModel.currentPose {
                PoseOverlayView(pose: pose)
                    .ignoresSafeArea()
            }

            // Layer 3: HUD
            VStack {
                // Top bar
                HStack {
                    Button(action: { onFinish(completedCount) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    // Exercise name + phase
                    VStack(spacing: 2) {
                        Text(viewModel.exerciseType.rawValue)
                            .font(.headline)
                            .fontWeight(.bold)
                        Text(viewModel.exerciseState.phase.rawValue)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.45), in: Capsule())

                    Spacer()

                    // Rep counter or hold time (목표 대비)
                    if viewModel.exerciseType.analyzerKind == .plank {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .foregroundColor(goalReached ? Theme.accent : .orange)
                            Text("\(Int(viewModel.exerciseState.holdTime)) / \(goal)초")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.45), in: Capsule())
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(goalReached ? Theme.accent : .orange)
                            Text("\(viewModel.exerciseState.repCount) / \(goal)")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.45), in: Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Voice unavailable warning (missing OpenAI key)
                if viewModel.voiceUnavailable {
                    HStack(spacing: 6) {
                        Image(systemName: "speaker.slash.fill")
                        Text("음성 코칭 꺼짐 — OPENAI_API_KEY 필요")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.8), in: Capsule())
                    .padding(.top, 8)
                }

                Spacer()
            }

            VStack {
                Spacer()
                bottomControls
            }

            // 준비 카운트다운 오버레이
            if let c = countdown {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    VStack(spacing: 10) {
                        Text("준비").font(.headline).foregroundColor(.white.opacity(0.8))
                        Text(c > 0 ? "\(c)" : "시작!")
                            .font(.system(size: 96, weight: .black))
                            .foregroundColor(.white)
                    }
                }
                .transition(.opacity)
            }

            // Camera error
            if let error = viewModel.cameraManager.cameraError {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text(error)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.latestFeedback?.id)
        .animation(.easeInOut(duration: 0.3), value: countdown)
        .onAppear {
            viewModel.startSession()
            runCountdown()
        }
        .onDisappear { viewModel.stopSession() }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .statusBarHidden(true)
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // TTS/AI 코칭 캡션
            if let feedback = viewModel.latestFeedback {
                Text(feedback.text)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(feedbackColor(for: feedback.type))
                    .cornerRadius(16)
                    .shadow(radius: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(feedback.id)
            }

            // 운동 완료 버튼 (목표 달성 시 라임그린으로 강조)
            Button(action: { onFinish(completedCount) }) {
                HStack(spacing: 8) {
                    Image(systemName: goalReached ? "checkmark.circle.fill" : "flag.checkered")
                    Text(goalReached ? "목표 달성! 결과 보기" : "운동 완료")
                }
            }
            .buttonStyle(EnergyButtonStyle(
                color: goalReached ? Theme.accent : Color.white.opacity(0.18),
                textColor: goalReached ? Theme.onAccent : .white
            ))
        }
        .padding(.horizontal)
        .padding(.bottom, 18)
    }

    /// 3·2·1·시작! 후 측정/코칭 시작 + 음성 안내
    private func runCountdown() {
        Task { @MainActor in
            for n in stride(from: 3, through: 1, by: -1) {
                countdown = n
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            countdown = 0           // "시작!"
            viewModel.announceIntro(goal: goal)
            try? await Task.sleep(nanoseconds: 700_000_000)
            countdown = nil
            viewModel.enableAnalysis()
        }
    }

    private func feedbackColor(for type: FeedbackType) -> Color {
        switch type {
        case .correction: return .red.opacity(0.85)
        case .encouragement: return .green.opacity(0.85)
        case .repCount: return .blue.opacity(0.85)
        case .positionWarning: return .orange.opacity(0.85)
        case .coaching: return .black.opacity(0.6)
        }
    }
}

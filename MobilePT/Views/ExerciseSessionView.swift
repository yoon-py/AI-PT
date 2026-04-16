import SwiftUI

struct ExerciseSessionView: View {
    @StateObject private var viewModel: ExerciseViewModel
    @Environment(\.dismiss) private var dismiss

    init(exercise: ExerciseType) {
        _viewModel = StateObject(wrappedValue: ExerciseViewModel(exercise: exercise))
    }

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
                    Button(action: { dismiss() }) {
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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())

                    Spacer()

                    // Rep counter or hold time
                    if viewModel.exerciseType == .plank {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .foregroundColor(.orange)
                            Text(formatTime(viewModel.exerciseState.holdTime))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(viewModel.exerciseState.repCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // AI Coach toggle button
                HStack {
                    Spacer()
                    Button(action: { viewModel.toggleAICoach() }) {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.isAICoachConnected ? "mic.fill" : "mic.slash.fill")
                                .font(.body)
                            Text(viewModel.isAICoachConnected ? "AI 코치 ON" : "AI 코치 OFF")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(viewModel.isAICoachConnected ? Color.green.opacity(0.85) : Color.gray.opacity(0.6), in: Capsule())
                    }
                    Spacer()
                }
                .padding(.top, 8)

                Spacer()

                // Angle info per exercise
                if !viewModel.exerciseState.currentAngles.isEmpty {
                    HStack(spacing: 12) {
                        switch viewModel.exerciseType {
                        case .squat:
                            if let angle = viewModel.exerciseState.currentAngles["avgKnee"] {
                                angleLabel("무릎", angle: angle)
                            }
                            if let angle = viewModel.exerciseState.currentAngles["torso"] {
                                angleLabel("상체", angle: angle)
                            }
                        case .pushUp:
                            if let angle = viewModel.exerciseState.currentAngles["avgElbow"] {
                                angleLabel("팔꿈치", angle: angle)
                            }
                            if let angle = viewModel.exerciseState.currentAngles["bodyLine"] {
                                angleLabel("몸 정렬", angle: angle)
                            }
                        case .plank:
                            if let angle = viewModel.exerciseState.currentAngles["bodyLine"] {
                                angleLabel("몸 정렬", angle: angle)
                            }
                            if let angle = viewModel.exerciseState.currentAngles["neck"] {
                                angleLabel("목", angle: angle)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }

                // Feedback banner
                if let feedback = viewModel.latestFeedback {
                    Text(feedback.text)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(feedbackColor(for: feedback.type))
                        .cornerRadius(16)
                        .shadow(radius: 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(feedback.id)
                        .padding(.bottom, 50)
                }
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
        .onAppear { viewModel.startSession() }
        .onDisappear { viewModel.stopSession() }
        .navigationBarHidden(true)
        .statusBarHidden(true)
    }

    private func feedbackColor(for type: FeedbackType) -> Color {
        switch type {
        case .correction: return .red.opacity(0.85)
        case .encouragement: return .green.opacity(0.85)
        case .repCount: return .blue.opacity(0.85)
        case .positionWarning: return .orange.opacity(0.85)
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func angleLabel(_ name: String, angle: Double) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
            Text("\(Int(angle))°")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

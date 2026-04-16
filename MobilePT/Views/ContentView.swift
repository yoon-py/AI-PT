import SwiftUI

struct ContentView: View {
    @State private var selectedExercise: ExerciseType?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // App title
                VStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue.gradient)
                    Text("MobilePT")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("AI 개인 트레이너")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Exercise selection
                VStack(spacing: 16) {
                    Text("운동 선택")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ForEach(ExerciseType.allCases) { exercise in
                        Button {
                            selectedExercise = exercise
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: exercise.icon)
                                    .font(.title2)
                                    .frame(width: 44)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.rawValue)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text("카메라로 자세를 분석합니다")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer()

                Text("전면 카메라를 사용합니다. 전신이 보이도록 서주세요.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
            .fullScreenCover(item: $selectedExercise) { exercise in
                ExerciseSessionView(exercise: exercise)
            }
        }
    }
}

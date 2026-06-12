import SwiftUI

/// 운동 사이 휴식 — 카운트다운 후 자동으로 다음 운동 가이드로. 건너뛰기 가능.
struct RestView: View {
    @EnvironmentObject private var store: AppStore
    let nextExercise: ExerciseType
    let goal: Int

    @State private var remaining = 30
    @State private var advanced = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("잠깐 휴식")
                .font(.title.weight(.heavy)).foregroundColor(Theme.ink)

            ZStack {
                Circle().stroke(Theme.accentSoft, lineWidth: 12)
                    .frame(width: 180, height: 180)
                Circle()
                    .trim(from: 0, to: CGFloat(remaining) / 30)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 180, height: 180)
                    .animation(.linear(duration: 1), value: remaining)
                Text("\(remaining)")
                    .font(.system(size: 56, weight: .black)).foregroundColor(Theme.ink)
            }

            VStack(spacing: 6) {
                Text("다음 운동").font(.caption).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: nextExercise.icon).foregroundColor(Theme.accent)
                    Text("\(nextExercise.rawValue) · \(goal)\(nextExercise.goalUnit)")
                        .font(.headline).foregroundColor(Theme.ink)
                }
            }

            Spacer()

            Button("바로 시작") { advance() }
                .buttonStyle(EnergyButtonStyle())
                .padding(.horizontal)
        }
        .padding(.bottom, 24)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await runTimer() }
    }

    private func runTimer() async {
        while remaining > 0 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            remaining -= 1
        }
        advance()
    }

    private func advance() {
        guard !advanced else { return }
        advanced = true
        store.proceedToGuide(nextExercise, goal: goal)
    }
}

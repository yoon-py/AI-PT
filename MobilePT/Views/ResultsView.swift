import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var store: AppStore
    let exercise: ExerciseType
    let reps: Int

    @State private var celebrate = false

    private var unit: String { exercise.goalUnit }

    private var shareText: String {
        "오늘 \(exercise.rawValue) \(reps)\(unit) 완료! 💪 AI 인바디 PT와 함께 운동 중 #AI인바디PT"
    }

    var body: some View {
        let inBody = store.inBody ?? .empty

        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Theme.success.gradient)
                        .scaleEffect(celebrate ? 1 : 0.5)
                        .opacity(celebrate ? 1 : 0)
                        .padding(.top, 24)

                    Text("운동 완료!")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(Theme.ink)

                    HStack(spacing: 12) {
                        summary(exercise.rawValue, "운동")
                        summary("\(reps)\(unit)", "수행량")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("인바디 개선 예상", systemImage: "chart.line.uptrend.xyaxis")
                            .sectionTitle()
                        Text(improvementMessage(inBody))
                            .font(.subheadline).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("꾸준히 하면 다음 인바디 측정에서 변화를 확인할 수 있어요.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()

                    ShareLink(item: shareText) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("결과 공유하기")
                        }
                        .font(.headline)
                        .foregroundColor(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: Theme.radius))
                    }

                    Spacer()
                }
                .padding()
            }

            // 축하 컨페티 (위에서 잠깐 터짐)
            ConfettiView()
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
        .navigationTitle("결과")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom) {
            Button("홈으로") { store.goHome() }
                .buttonStyle(EnergyButtonStyle())
                .padding()
                .background(.ultraThinMaterial)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { celebrate = true }
        }
    }

    private func summary(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .black)).foregroundColor(Theme.ink)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func improvementMessage(_ inBody: InBodyResult) -> String {
        switch exercise.analyzerKind {
        case .squat:
            return inBody.fatFocus
                ? "하체 큰 근육을 써서 칼로리를 태웠어요. 꾸준히 하면 체지방량이 줄어들 거예요."
                : "하체 근육을 단련했어요. 골격근량 증가에 도움이 됩니다."
        case .pushUp:
            return "상체 근육을 자극했어요. 가슴·팔 근육량 향상에 도움이 됩니다."
        case .plank:
            return "코어를 단련했어요. 몸통 안정성과 체지방 관리에 도움이 됩니다."
        }
    }
}

import SwiftUI

/// 루틴(추천 운동 순차) 완료 축하 화면 — 컨페티 + 완주 요약 + 공유.
struct RoutineCompleteView: View {
    @EnvironmentObject private var store: AppStore
    let exerciseCount: Int

    @State private var celebrate = false

    private var todayLogs: [WorkoutLog] {
        let cal = Calendar.current
        return store.workoutLogs
            .filter { cal.isDateInToday($0.date) }
            .prefix(exerciseCount)
            .reversed()
    }

    private var shareText: String {
        "오늘 운동 \(exerciseCount)개 루틴 완주! 💪 AI 인바디 PT와 함께 #AI인바디PT"
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Theme.success.gradient)
                        .scaleEffect(celebrate ? 1 : 0.5)
                        .opacity(celebrate ? 1 : 0)
                        .padding(.top, 24)

                    VStack(spacing: 6) {
                        Text("오늘의 루틴 완주!")
                            .font(.system(size: 30, weight: .black))
                            .foregroundColor(Theme.ink)
                        Text("운동 \(exerciseCount)개를 모두 끝냈어요")
                            .font(.subheadline).foregroundColor(.secondary)
                    }

                    // 완주한 운동 요약
                    VStack(spacing: 10) {
                        ForEach(todayLogs) { log in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.success)
                                Text(log.exercise.rawValue)
                                    .font(.subheadline.weight(.semibold)).foregroundColor(Theme.ink)
                                Spacer()
                                Text(log.summary)
                                    .font(.subheadline).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 12).padding(.horizontal, 14)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    ShareLink(item: shareText) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("기록 공유하기")
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

            ConfettiView()
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
        .navigationTitle("루틴 완료")
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
}

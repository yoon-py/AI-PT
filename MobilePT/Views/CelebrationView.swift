import SwiftUI

/// 오늘 운동 완료 축하 화면 — 컨페티 + 🔥 + 연속 일수 + 주간 스트립 + 격려.
struct CelebrationView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var pop = false

    var body: some View {
        let streak = store.dailyStreak
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // 🔥 + 초록 체크 pill
                ZStack {
                    Text("🔥").font(.system(size: 130))
                    ZStack {
                        RoundedRectangle(cornerRadius: 18).fill(Color(white: 0.25))
                            .frame(width: 64, height: 74)
                        Circle().fill(Theme.accent).frame(width: 44, height: 44)
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.black)).foregroundColor(.white)
                    }
                    .offset(y: 28)
                }
                .scaleEffect(pop ? 1 : 0.6)
                .opacity(pop ? 1 : 0)

                // 타이틀
                (Text("\(streak)일 ").foregroundColor(Theme.accent)
                 + Text("연속 초록불!").foregroundColor(Theme.ink))
                    .font(.system(size: 28, weight: .black))

                // 주간 스트립 + 격려
                VStack(spacing: 16) {
                    weekStrip
                    Divider()
                    Text("꾸준히 하는 게 정말 어려운 거 알죠?\n오늘도 정말 대단해요 👍")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .card()

                Spacer()

                Button("확인") { dismiss() }
                    .buttonStyle(EnergyButtonStyle())
            }
            .padding(24)

            ConfettiView()
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { pop = true }
        }
    }

    private var weekStrip: some View {
        let cal = store.weekCalendarForView
        let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let labels = ["월", "화", "수", "목", "금", "토", "일"]
        let days = Set(store.workoutLogs.map { cal.startOfDay(for: $0.date) })
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                let day = cal.date(byAdding: .day, value: i, to: start) ?? start
                let completed = days.contains(cal.startOfDay(for: day))
                VStack(spacing: 7) {
                    Text(labels[i])
                        .font(.caption.weight(.semibold))
                        .foregroundColor(completed ? Theme.accent : .secondary)
                    ZStack {
                        Circle()
                            .fill(completed ? Theme.accent : Theme.hairline)
                            .frame(width: 34, height: 34)
                        if completed {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.black)).foregroundColor(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

import SwiftUI

/// 운동 탭 — 이번 주 진행 + 추천 루틴 + 직접 고르기 + 최근 기록.
struct WorkoutView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            FixedHeader(title: "운동")
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    StepsCard(steps: store.todaySteps, goal: store.stepGoal,
                              kcal: store.walkingKcal(on: Date()),
                              distanceKm: store.distanceKm(on: Date()))
                    directPickRow
                    recentCard
                }
                .padding()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var directPickRow: some View {
        Button { store.path.append(.exerciseList) } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2.fill").foregroundColor(Theme.accent)
                Text("운동 직접 고르기").font(.subheadline.weight(.semibold)).foregroundColor(Theme.ink)
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.secondary)
            }
            .padding(.vertical, 14).padding(.horizontal, 16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 최근 기록

    @ViewBuilder
    private var recentCard: some View {
        let logs = store.recentLogs
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 기록").font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
            if logs.isEmpty {
                Text("아직 운동 기록이 없어요. 첫 운동을 시작해볼까요?")
                    .font(.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            } else {
                ForEach(logs) { log in
                    HStack(spacing: 12) {
                        Image(systemName: log.exercise.icon)
                            .foregroundColor(Theme.accent)
                            .frame(width: 38, height: 38)
                            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.exercise.rawValue).font(.subheadline.weight(.semibold)).foregroundColor(Theme.ink)
                            Text(dateText(log.date)).font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(log.summary)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(log.goalReached ? Theme.accent : Theme.ink)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - 공용

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline.weight(.black)).foregroundColor(Theme.ink)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: 34)
    }

    private func dateText(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "M월 d일 a h:mm"
        return f.string(from: date)
    }
}

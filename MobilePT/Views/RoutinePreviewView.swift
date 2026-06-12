import SwiftUI

/// 추천 운동 미리보기 — 오늘 루틴 목록 + 총 시간/세트/kcal, "시작하기"로 순차 진행 시작.
struct RoutinePreviewView: View {
    @EnvironmentObject private var store: AppStore

    private var recs: [ExerciseRecommendation] { store.recommendations() }
    private var totalSets: Int { recs.count * 3 }
    private var totalKcal: Int {
        let weight = store.inBody?.weight ?? 65
        return recs.reduce(0) { $0 + $1.exercise.estimatedRoutineKcal(perSetGoal: $1.goal, weightKg: weight) }
    }
    private var estMinutes: Int { max(5, recs.count * 4) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 상단 요약 칩
                HStack(spacing: 10) {
                    infoChip("clock", "약 \(estMinutes)분", "운동 시간")
                    infoChip("square.stack.3d.up.fill", "\(totalSets)세트", "총 세트")
                    infoChip("flame.fill", "\(totalKcal)", "kcal")
                }

                Text("총 \(recs.count)개 운동").font(.subheadline.weight(.bold)).foregroundColor(.secondary)
                    .padding(.top, 4)

                ForEach(Array(recs.enumerated()), id: \.element.id) { idx, rec in
                    row(index: idx + 1, rec: rec)
                }
            }
            .padding()
        }
        .navigationTitle("오늘의 추천 운동")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                store.startRoutine(recs)
            } label: {
                Label("시작하기", systemImage: "play.fill")
            }
            .buttonStyle(EnergyButtonStyle())
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private func row(index: Int, rec: ExerciseRecommendation) -> some View {
        HStack(spacing: 14) {
            Text("\(index)")
                .font(.subheadline.weight(.black)).foregroundColor(.secondary)
                .frame(width: 18)
            BodyHighlightView(zones: rec.exercise.muscleZones)
                .frame(width: 34, height: 60)
                .padding(.horizontal, 8)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(rec.exercise.rawValue).font(.headline).foregroundColor(Theme.ink)
                Text(rec.exercise.targetLabel).font(.caption2.weight(.bold)).foregroundColor(Theme.accent)
                Text(rec.prescription).font(.caption).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 14)
    }

    private func infoChip(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.subheadline).foregroundColor(Theme.accent)
            Text(value).font(.subheadline.weight(.black)).foregroundColor(Theme.ink)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }
}

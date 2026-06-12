import SwiftUI

/// 운동 시작 전 가이드 — 시작 자세 / 동작 / 호흡 + 주의 팁. 카메라 켜기 전에 자세를 익힌다.
struct ExerciseGuideView: View {
    @EnvironmentObject private var store: AppStore
    let exercise: ExerciseType
    let goal: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 헤더 — 바디맵으로 자극 부위 표시
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 16) {
                        BodyHighlightView(zones: exercise.muscleZones)
                            .frame(width: 70, height: 126)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exercise.rawValue).font(.title2.weight(.heavy)).foregroundColor(Theme.ink)
                            Text("자극 부위").font(.caption).foregroundColor(.secondary)
                            Text(MuscleZone.label(for: exercise.muscleZones))
                                .font(.subheadline.weight(.bold)).foregroundColor(.red.opacity(0.85))
                        }
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        infoPill("난이도", exercise.difficulty)
                        infoPill("오늘 목표", "\(goal)\(exercise.goalUnit)")
                    }
                }
                .card()

                // 가이드 스텝
                Text("이렇게 따라 하세요").sectionTitle()
                ForEach(Array(exercise.guideSteps.enumerated()), id: \.element.id) { idx, gstep in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle().fill(Theme.accentSoft).frame(width: 44, height: 44)
                            Text("\(idx + 1)").font(.headline.weight(.black)).foregroundColor(Theme.accent)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Label(gstep.title, systemImage: gstep.icon)
                                .font(.headline).foregroundColor(Theme.ink)
                            Text(gstep.detail).font(.subheadline).foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .card(padding: 16)
                }

                // 팁
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill").foregroundColor(.orange)
                    Text(exercise.tip).font(.subheadline).foregroundColor(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding()
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .navigationTitle("운동 준비")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                store.path.append(.session(exercise, goal))
            } label: {
                Label("카메라 켜고 운동 시작", systemImage: "camera.fill")
            }
            .buttonStyle(EnergyButtonStyle())
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private func infoPill(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Theme.bg, in: Capsule())
    }
}

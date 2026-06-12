import SwiftUI

/// 운동 목록/선택 — 추천 외에 직접 운동을 골라 시작한다.
struct ExerciseListView: View {
    @EnvironmentObject private var store: AppStore

    /// 부위 그룹 순서 (하체 → 상체 → 코어)
    private var groups: [(title: String, items: [ExerciseType])] {
        let order = ["하체", "상체", "코어"]
        let dict = Dictionary(grouping: ExerciseType.allCases, by: { $0.groupTitle })
        return order.compactMap { key in
            guard let items = dict[key], !items.isEmpty else { return nil }
            return (key, items)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(groups, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group.title).sectionTitle()
                        ForEach(group.items) { ex in
                            Button {
                                store.path.append(.guide(ex, ex.defaultGoal))
                            } label: {
                                card(ex)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("운동 목록")
        .navigationBarTitleDisplayMode(.large)
    }

    private func card(_ ex: ExerciseType) -> some View {
        HStack(spacing: 14) {
            BodyHighlightView(zones: ex.muscleZones)
                .frame(width: 38, height: 66)
                .padding(.horizontal, 9)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(ex.rawValue).font(.headline).foregroundColor(Theme.ink)
                    Text(ex.difficulty).font(.caption2.weight(.bold))
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Theme.accentSoft, in: Capsule())
                }
                Text(ex.summary).font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label(ex.targetLabel, systemImage: "target")
                    .font(.caption2).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundColor(.secondary)
        }
        .card(padding: 16)
    }
}

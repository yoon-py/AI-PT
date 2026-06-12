import SwiftUI

/// 만보기 카드 — 오늘 걸음수 + 목표 진행 + 걷기 칼로리.
struct StepsCard: View {
    let steps: Int
    let goal: Int
    let kcal: Int
    var distanceKm: Double = 0

    private var fraction: Double {
        goal > 0 ? min(Double(steps) / Double(goal), 1) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("오늘 걸음", systemImage: "figure.walk")
                    .font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
                Spacer()
                Label("\(kcal) kcal", systemImage: "flame.fill")
                    .font(.subheadline.weight(.bold)).foregroundColor(Theme.accent)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(steps, format: .number)
                    .font(.system(size: 30, weight: .black)).foregroundColor(Theme.ink)
                Text("/ \(goal) 걸음").font(.caption).foregroundColor(.secondary)
                if distanceKm > 0 {
                    Text("· \(String(format: "%.1f", distanceKm)) km")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline)
                    Capsule().fill(Theme.accent)
                        .frame(width: max(6, geo.size.width * fraction))
                }
            }
            .frame(height: 8)
            .animation(.easeOut(duration: 0.4), value: fraction)
        }
        .card()
    }
}

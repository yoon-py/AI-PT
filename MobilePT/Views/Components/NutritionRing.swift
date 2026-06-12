import SwiftUI

/// 칼로리 링 — 섭취량을 "소비(기초대사량+운동)" 대비로 채운다.
/// 운동을 많이 하면 소비가 커져 링이 덜 차므로, 운동↔식단 연동이 시각적으로 드러난다.
struct CalorieRing: View {
    let intake: Int
    let burn: Int
    let tint: Color
    var size: CGFloat = 170
    var lineWidth: CGFloat = 16

    private var fraction: Double {
        burn > 0 ? min(Double(intake) / Double(burn), 1) : (intake > 0 ? 1 : 0)
    }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.hairline, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("섭취").font(.caption2).foregroundColor(.secondary)
                Text("\(intake)")
                    .font(.system(size: size * 0.2, weight: .black))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("/ \(burn) 소비").font(.caption2).foregroundColor(.secondary)
            }
            .padding(.horizontal, lineWidth + 6)
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.45), value: fraction)
    }
}

/// 칼로리 수지 게이지 — 섭취가 "소비(균형)" 기준으로 어디에 걸쳐있는지 가로 막대로 보여준다.
/// 숫자 라벨은 바깥(등식)이 담당하고, 여기선 막대 + 균형 마커만.
struct CalorieBalanceBar: View {
    let intake: Int
    let burn: Int
    let tint: Color

    var body: some View {
        // 소비(균형)를 막대의 ~70% 지점에 두어 적자/흑자 양쪽이 보이게
        let maxVal = max(Double(burn) * 1.4, Double(intake) * 1.05, 1)
        let intakeFrac = min(Double(intake) / maxVal, 1)
        let burnFrac = min(Double(burn) / maxVal, 1)

        return GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.hairline).frame(height: 12)
                Capsule().fill(tint)
                    .frame(width: max(8, w * intakeFrac), height: 12)
                // 소비(균형) 마커
                Rectangle().fill(Theme.ink.opacity(0.55))
                    .frame(width: 2.5, height: 22)
                    .cornerRadius(1)
                    .offset(x: max(0, w * burnFrac - 1.25))
            }
            .frame(height: 22)
        }
        .frame(height: 22)
    }
}

/// 단백질 진행 바 — 목표(체중·목표 기반) 대비. 목표 없으면 섭취량만.
struct ProteinBar: View {
    let grams: Double
    let target: Int?

    private var fraction: Double {
        guard let t = target, t > 0 else { return 0 }
        return min(grams / Double(t), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("단백질", systemImage: "fish.fill")
                    .font(.caption.weight(.bold)).foregroundColor(Theme.ink)
                Spacer()
                if let target {
                    Text("\(Int(grams)) / \(target)g")
                        .font(.caption.weight(.bold)).foregroundColor(Theme.accent)
                } else {
                    Text("\(Int(grams))g")
                        .font(.caption.weight(.bold)).foregroundColor(Theme.accent)
                }
            }
            if target != nil {
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
        }
    }
}

/// 매크로 한 칸 (탄/단/지 그램)
struct MacroTile: View {
    let label: String
    let grams: Double
    var highlight: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Int(grams))g")
                .font(.subheadline.weight(.black))
                .foregroundColor(highlight ? Theme.accent : Theme.ink)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(highlight ? Theme.accentSoft : Theme.bg,
                    in: RoundedRectangle(cornerRadius: 12))
    }
}

/// 홈 대시보드용 작은 칼로리 링 (섭취 숫자만)
struct MiniCalorieRing: View {
    let intake: Int
    let burn: Int
    let tint: Color
    var size: CGFloat = 56

    private var fraction: Double {
        burn > 0 ? min(Double(intake) / Double(burn), 1) : (intake > 0 ? 1 : 0)
    }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.hairline, lineWidth: 6)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "fork.knife").font(.caption).foregroundColor(tint)
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.4), value: fraction)
    }
}

import SwiftUI

/// 자체 제작 인체 바디맵 — 자극되는 근육 부위를 빨갛게 칠해 보여준다.
/// (블록형 정면 실루엣. 100×180 좌표계를 프레임 크기에 맞춰 스케일)
struct BodyHighlightView: View {
    let zones: Set<MuscleZone>
    var base = Color(white: 0.84)
    var highlight = Color.red.opacity(0.82)

    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 100, sy = size.height / 180

            func part(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                      _ r: CGFloat, _ zone: MuscleZone?) {
                let rect = CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy)
                let path = Path(roundedRect: rect, cornerRadius: r * min(sx, sy))
                let on = zone.map { zones.contains($0) } ?? false
                ctx.fill(path, with: .color(on ? highlight : base))
            }

            // 머리 (항상 회색)
            part(40, 0, 20, 22, 10, nil)
            // 어깨
            part(24, 30, 21, 16, 8, .shoulders)
            part(55, 30, 21, 16, 8, .shoulders)
            // 팔
            part(13, 38, 13, 56, 6, .arms)
            part(74, 38, 13, 56, 6, .arms)
            // 가슴 (상부 몸통)
            part(33, 38, 34, 28, 9, .chest)
            // 코어 (하부 몸통)
            part(35, 65, 30, 40, 8, .core)
            // 하체 (양다리)
            part(34, 105, 14, 70, 6, .legs)
            part(52, 105, 14, 70, 6, .legs)
        }
    }
}

extension MuscleZone {
    /// 부위 집합을 표시 순서대로 "가슴 · 어깨 · 하체" 형태로
    static func label(for zones: Set<MuscleZone>) -> String {
        allCases.filter { zones.contains($0) }.map(\.rawValue).joined(separator: " · ")
    }
}

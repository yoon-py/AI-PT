import SwiftUI
import UIKit

/// 라이트/다크 모드에 따라 바뀌는 색
private func adaptive(light: UIColor, dark: UIColor) -> Color {
    Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
}

/// 앱 전역 디자인 시스템 — 민트 포인트 + 라이트/다크 적응형
enum Theme {
    // 포인트 색 (양쪽 모드 공통)
    static let accent = Color(red: 0.12, green: 0.78, blue: 0.58)    // 민트/틸 #1FC795
    static let accentSoft = Color(red: 0.12, green: 0.78, blue: 0.58).opacity(0.16)
    static let success = Color(red: 0.12, green: 0.78, blue: 0.58)
    static let onAccent = Color.white                                // 민트 위 텍스트(흰색)

    // 모드 적응형
    static let bg = adaptive(
        light: UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1),
        dark:  UIColor(red: 0.07, green: 0.075, blue: 0.09, alpha: 1))
    static let card = adaptive(
        light: .white,
        dark:  UIColor(red: 0.12, green: 0.125, blue: 0.145, alpha: 1))
    static let ink = adaptive(
        light: UIColor(red: 0.09, green: 0.10, blue: 0.12, alpha: 1),
        dark:  UIColor(white: 0.96, alpha: 1))
    static let subtle = adaptive(
        light: UIColor(white: 0.48, alpha: 1),
        dark:  UIColor(white: 0.66, alpha: 1))
    /// 옅은 구분선/비활성 채움
    static let hairline = adaptive(
        light: UIColor(white: 0, alpha: 0.06),
        dark:  UIColor(white: 1, alpha: 0.12))

    // 레이아웃
    static let pad: CGFloat = 20
    static let radius: CGFloat = 18
    static let cardRadius: CGFloat = 24
}

// MARK: - 버튼 스타일

struct EnergyButtonStyle: ButtonStyle {
    var color: Color = Theme.accent
    var textColor: Color = Theme.onAccent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.heavy))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(color, in: RoundedRectangle(cornerRadius: Theme.radius))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 공용 modifier

extension View {
    /// 표준 카드 스타일 (둥근 모서리 + 흰 카드 + 옅은 그림자)
    func card(padding: CGFloat = Theme.pad) -> some View {
        self.padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    /// 섹션 제목 (큰 볼드)
    func sectionTitle() -> some View {
        self.font(.title3.weight(.heavy)).foregroundColor(Theme.ink)
    }
}

/// 탭 화면 공통 상단 헤더 (제목 + 우측 액세서리 + 풀폭 구분선). 모든 탭이 동일한 룩을 갖도록.
struct FixedHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(Theme.ink)
                Spacer()
                trailing
            }
            .padding(.horizontal)
            .padding(.top, 14)
            .padding(.bottom, 18)
            Divider()
        }
    }
}

/// 큰 볼드 화면 제목
struct ScreenTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 30, weight: .black))
                .foregroundColor(Theme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Theme.subtle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 운동 목표 칩

/// 운동 목표 하나를 나타내는 민트 칩
struct GoalChip: View {
    let goal: FitnessGoal
    var body: some View {
        Label(goal.rawValue, systemImage: goal.icon)
            .font(.caption.weight(.bold))
            .foregroundColor(Theme.onAccent)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(Theme.accent, in: Capsule())
    }
}

// MARK: - 줄바꿈 레이아웃 (칩 여러 개 자동 줄바꿈)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxRowWidth = max(maxRowWidth, x - spacing)
        }
        let width = maxWidth == .infinity ? maxRowWidth : maxWidth
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + bounds.width && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

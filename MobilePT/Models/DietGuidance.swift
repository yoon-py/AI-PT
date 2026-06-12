import SwiftUI

/// 칼로리 수지를 "목표"에 비춰 해석한다.
/// 새 칼로리 지표를 만들지 않고, 기존 수지(섭취 − 소비)를 목표 방향으로만 읽는다.
extension FitnessGoal {
    /// 이 목표에서 칼로리 수지가 어느 방향이어야 좋은가
    enum CalorieDirection {
        case deficit   // 적자(−)가 좋음 — 감량
        case surplus   // 흑자(+)가 좋음 — 근증가
        case balance   // 0 근처가 좋음 — 유지/체력/코어
    }

    var calorieDirection: CalorieDirection {
        switch self {
        case .fatLoss:                            return .deficit
        case .muscleGain:                         return .surplus
        case .endurance, .coreStability, .maintain: return .balance
        }
    }

    /// 목표별 단백질 권장 계수 (체중 1kg당 g)
    var proteinPerKg: Double {
        switch self {
        case .muscleGain:                         return 2.0
        case .fatLoss, .endurance, .coreStability: return 1.6
        case .maintain:                           return 1.4
        }
    }
}

/// 오늘 칼로리 수지를 목표에 비춘 평가 (색 + 한 줄 코멘트)
struct DietVerdict {
    let onTrack: Bool        // 목표 방향에 맞게 가고 있는지
    let title: String        // "감량 페이스 좋아요" 등
    let detail: String       // 보조 설명
    let tint: Color

    /// 균형 목표에서 "0 근처"로 인정하는 폭(kcal)
    private static let balanceBand = 250

    static func make(net: Int, goal: FitnessGoal) -> DietVerdict {
        switch goal.calorieDirection {
        case .deficit:
            let good = net <= 0
            return DietVerdict(
                onTrack: good,
                title: good ? "감량 페이스 좋아요 💪" : "오늘은 조금 많아요",
                detail: good
                    ? "소비가 섭취보다 \(abs(net))kcal 많아요. 체지방 감량에 유리한 하루예요."
                    : "섭취가 소비보다 \(net)kcal 많아요. 가볍게 더 움직이거나 다음 끼니를 줄여볼까요?",
                tint: good ? Theme.accent : .orange
            )
        case .surplus:
            let good = net >= 0
            return DietVerdict(
                onTrack: good,
                title: good ? "근성장 연료 충분해요 🔥" : "근성장엔 조금 부족해요",
                detail: good
                    ? "섭취가 소비보다 \(net)kcal 많아요. 근육을 키우기 좋은 잉여 에너지예요."
                    : "소비가 섭취보다 \(abs(net))kcal 많아요. 근성장엔 잘 챙겨 먹는 게 중요해요.",
                tint: good ? Theme.accent : .orange
            )
        case .balance:
            let good = abs(net) <= balanceBand
            return DietVerdict(
                onTrack: good,
                title: good ? "균형이 잘 맞아요 ⚖️" : (net > 0 ? "섭취가 조금 많아요" : "섭취가 조금 적어요"),
                detail: good
                    ? "섭취와 소비가 거의 균형을 이뤘어요. 지금 페이스를 유지해요."
                    : (net > 0
                       ? "섭취가 소비보다 \(net)kcal 많아요. 가볍게 더 움직여볼까요?"
                       : "소비가 섭취보다 \(abs(net))kcal 많아요. 조금 더 챙겨 먹어도 좋아요."),
                tint: good ? Theme.accent : .orange
            )
        }
    }
}

extension InBodyResult {
    /// 목표별 일일 단백질 권장량(g) — 체중 기반 가벼운 기준선
    func proteinTarget(for goal: FitnessGoal) -> Int {
        Int((weight * goal.proteinPerKg).rounded())
    }
}

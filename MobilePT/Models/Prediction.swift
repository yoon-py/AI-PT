import Foundation

/// "인바디 예측" — 현재 체성분 + 이번 주 운동량으로, 목표 지표가 0.5kg 변하는 데
/// 며칠/몇 주가 걸릴지 추정한다. 목표(감량/근증가/유지)마다 핵심 지표·변화율·문구가 다르다.
struct InBodyPrediction {
    let current: InBodyResult
    let predicted: InBodyResult     // horizonDays 뒤 예측 체성분 (그래프용)
    let workoutsThisWeek: Int
    let goal: FitnessGoal
    let horizonDays: Int            // 목표 지표가 milestone(0.5kg)에 도달하는 기간

    var weightDelta: Double { predicted.weight - current.weight }
    var muscleDelta: Double { predicted.skeletalMuscleMass - current.skeletalMuscleMass }
    var fatDelta: Double { predicted.bodyFatMass - current.bodyFatMass }

    /// 이번 주 운동 기록이 있어 변화가 예상되는지
    var hasChange: Bool { workoutsThisWeek > 0 && horizonDays > 0 }

    /// "11일" 또는 "3주" 형태의 기간 텍스트
    var timeText: String {
        if horizonDays <= 13 { return "\(horizonDays)일" }
        return "\(Int((Double(horizonDays) / 7).rounded()))주"
    }

    /// 예측 헤드라인 — 목표별 핵심 지표 + 시간
    var headline: String {
        guard hasChange else {
            return "이번 주 운동 기록이 아직 없어요. 운동을 시작하면 며칠 뒤 변화를 예측해드릴게요!"
        }
        switch goal {
        case .muscleGain:
            return "이대로 꾸준히 하면 약 \(timeText) 뒤 골격근이 0.5kg 늘어요 💪"
        case .fatLoss:
            return "이대로 꾸준히 하면 약 \(timeText) 뒤 체지방이 0.5kg 줄어요 🔥"
        default:
            return "이대로 꾸준히 하면 약 \(timeText) 뒤 체지방이 0.5kg 줄고 근육은 유지돼요"
        }
    }

    /// 차트용 비교 데이터 (지표명, 현재값, 예측값)
    var metrics: [(name: String, current: Double, predicted: Double)] {
        [
            ("체중", current.weight, predicted.weight),
            ("골격근량", current.skeletalMuscleMass, predicted.skeletalMuscleMass),
            ("체지방량", current.bodyFatMass, predicted.bodyFatMass)
        ]
    }

    static func make(from inBody: InBodyResult, workoutsThisWeek n: Int, goal: FitnessGoal) -> InBodyPrediction {
        let w = Double(min(n, 6))   // 주당 효과는 6회에서 포화(현실적 상한)
        let milestone = 0.5         // 목표 지표 0.5kg 변화 기준

        // 목표별 주간 변화율(kg/week)
        let muscleRate: Double, fatRate: Double, weightRate: Double
        let keyRate: Double         // 목표 핵심 지표의 절대 변화율
        switch goal {
        case .muscleGain:
            muscleRate = 0.05 * w; weightRate = 0.03 * w; fatRate = -0.02 * w
            keyRate = muscleRate
        case .fatLoss:
            fatRate = -0.08 * w; weightRate = -0.07 * w; muscleRate = 0.02 * w
            keyRate = -fatRate
        default:    // 유지·체력·코어 → 리컴포지션
            fatRate = -0.04 * w; muscleRate = 0.02 * w; weightRate = -0.03 * w
            keyRate = -fatRate
        }

        // milestone 도달 기간(주 → 일)
        let weeks = keyRate > 0 ? milestone / keyRate : 0
        let horizonDays = weeks > 0 ? max(2, Int((weeks * 7).rounded())) : 0

        // 그 시점의 예측 체성분 (주간 변화율 × 경과 주수)
        var weight = inBody.weight + weightRate * weeks
        var muscle = inBody.skeletalMuscleMass + muscleRate * weeks
        var fat = inBody.bodyFatMass + fatRate * weeks
        weight = max(weight, 0); muscle = max(muscle, 0); fat = max(fat, 0)
        let bmr = inBody.bmr + (muscle - inBody.skeletalMuscleMass) * 22

        var predicted = inBody   // 키 유지 → BMI 자동 재계산
        predicted.date = Calendar.current.date(byAdding: .day, value: max(horizonDays, 1), to: Date()) ?? Date()
        predicted.weight = round1(weight)
        predicted.skeletalMuscleMass = round1(muscle)
        predicted.bodyFatMass = round1(fat)
        predicted.bmr = bmr.rounded()

        return InBodyPrediction(current: inBody, predicted: predicted,
                                workoutsThisWeek: n, goal: goal, horizonDays: horizonDays)
    }

    private static func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
}

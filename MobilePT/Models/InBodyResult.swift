import Foundation

/// 가정용(홈) 인바디 체성분 측정 결과 — 기본 지표만 제공된다.
struct InBodyResult: Equatable, Codable {
    var date: Date = Date()
    var weight: Double              // 체중 (kg)
    var height: Double              // 키 (cm)
    var skeletalMuscleMass: Double  // 골격근량 (kg)
    var bodyFatMass: Double         // 체지방량 (kg)
    var bmr: Double                 // 기초대사량 (kcal)

    // MARK: - 파생 지표

    /// BMI = 체중(kg) ÷ 키(m)²  — 키·체중으로 자동 계산
    var bmi: Double {
        let m = height / 100
        return m > 0 ? weight / (m * m) : 0
    }
    var bodyFatPercent: Double { weight > 0 ? bodyFatMass / weight * 100 : 0 }
    var muscleRatio: Double { weight > 0 ? skeletalMuscleMass / weight : 0 }

    /// 운동 목표 판정
    var fatFocus: Bool { bmi >= 25 || bodyFatPercent >= 25 }
    var muscleFocus: Bool { (bmi > 0 && bmi < 18.5) || muscleRatio < 0.40 }
    var goalLabel: String { fatFocus ? "체지방 감량" : (muscleFocus ? "근육량 증가" : "체형 유지") }

    /// 체성분 기반 운동 목표(복수) — 체성분 우선순위 + 초보자 공통 목표
    var goals: [FitnessGoal] {
        var g: [FitnessGoal] = []
        if fatFocus { g.append(.fatLoss) }
        if muscleFocus { g.append(.muscleGain) }
        if g.isEmpty { g.append(.maintain) }
        // 초보자 누구에게나 도움 되는 공통 목표
        g.append(.coreStability)
        g.append(.endurance)
        return g
    }

    // MARK: - 샘플 / 빈 값

    /// 데모용 — 과체중·체지방 다소 높음 → "체지방 감량" 추천이 뜨는 케이스 (BMI ≈ 25.5)
    static let sample = InBodyResult(
        weight: 80,
        height: 177,
        skeletalMuscleMass: 30,
        bodyFatMass: 20,
        bmr: 1650
    )

    static let empty = InBodyResult(
        weight: 0, height: 0, skeletalMuscleMass: 0, bodyFatMass: 0, bmr: 0
    )

    // MARK: - 분석

    var findings: [String] {
        var notes: [String] = []
        if bmi >= 25 {
            notes.append("BMI \(fmt(bmi)) — 비만 범위, 체지방 관리가 필요해요")
        } else if bmi >= 23 {
            notes.append("BMI \(fmt(bmi)) — 과체중 범위예요")
        } else if bmi > 0 && bmi < 18.5 {
            notes.append("BMI \(fmt(bmi)) — 저체중, 근육 보강이 필요해요")
        }
        if bodyFatPercent >= 25 {
            notes.append("체지방률 \(Int(bodyFatPercent))% — 다소 높아요")
        }
        if muscleRatio < 0.40 && weight > 0 {
            notes.append("골격근량이 체중 대비 낮아요")
        }
        if notes.isEmpty {
            notes.append("전반적으로 균형 잡힌 체성분이에요")
        }
        return notes
    }

    /// 체성분 목표 기반 운동 추천
    func recommendations() -> [ExerciseRecommendation] {
        if fatFocus {
            return [
                ExerciseRecommendation(exercise: .squat,
                    reason: "하체 큰 근육을 써서 칼로리를 태워요. 체지방 감량에 효과적이에요.",
                    prescription: "3세트 × 15회", goal: 15),
                ExerciseRecommendation(exercise: .plank,
                    reason: "코어를 단련하며 체지방을 관리해요.",
                    prescription: "3세트 × 40초", goal: 40),
                ExerciseRecommendation(exercise: .pushUp,
                    reason: "전신을 써서 활동 대사량을 높여요.",
                    prescription: "3세트 × 10회", goal: 10)
            ]
        } else if muscleFocus {
            return [
                ExerciseRecommendation(exercise: .squat,
                    reason: "골격근량이 부족해요. 스쿼트로 하체 근육을 키워요.",
                    prescription: "3세트 × 12회", goal: 12),
                ExerciseRecommendation(exercise: .pushUp,
                    reason: "상체 근육을 키워 골격근량을 늘려요.",
                    prescription: "3세트 × 10회", goal: 10),
                ExerciseRecommendation(exercise: .plank,
                    reason: "코어 안정성으로 운동 효율을 높여요.",
                    prescription: "3세트 × 30초", goal: 30)
            ]
        } else {
            return [
                ExerciseRecommendation(exercise: .squat,
                    reason: "균형 잡힌 체형 유지를 위한 하체 운동.",
                    prescription: "3세트 × 12회", goal: 12),
                ExerciseRecommendation(exercise: .pushUp,
                    reason: "상체 근력 유지 운동.",
                    prescription: "3세트 × 10회", goal: 10),
                ExerciseRecommendation(exercise: .plank,
                    reason: "코어 유지 운동.",
                    prescription: "3세트 × 40초", goal: 40)
            ]
        }
    }

    /// LLM 코치에게 넘길 사용자 신체 요약
    var coachProfileSummary: String {
        var s = "체중 \(Int(weight))kg, 키 \(Int(height))cm, 골격근량 \(fmt(skeletalMuscleMass))kg, "
        s += "체지방량 \(fmt(bodyFatMass))kg(체지방률 \(Int(bodyFatPercent))%), "
        s += "BMI \(fmt(bmi)), 기초대사량 \(Int(bmr))kcal. "
        s += "운동 목표: \(goalLabel). "
        s += "특이사항: \(findings.joined(separator: " / "))."
        return s
    }

    private func fmt(_ v: Double) -> String { String(format: "%.1f", v) }
}

/// 운동 목표 (복수 선택 가능)
enum FitnessGoal: String, CaseIterable, Hashable, Codable, Identifiable {
    case fatLoss = "체지방 감량"
    case muscleGain = "근육량 증가"
    case coreStability = "코어 강화"
    case endurance = "체력 향상"
    case maintain = "체형 유지"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fatLoss: return "flame.fill"
        case .muscleGain: return "dumbbell.fill"
        case .coreStability: return "figure.core.training"
        case .endurance: return "bolt.heart.fill"
        case .maintain: return "checkmark.seal.fill"
        }
    }

    var detail: String {
        switch self {
        case .fatLoss: return "체중을 줄이고 건강한 체형을 만들어요"
        case .muscleGain: return "근육을 키워 탄탄한 몸을 만들어요"
        case .coreStability: return "코어를 강화해 안정적인 몸통을 만들어요"
        case .endurance: return "체력과 지구력을 끌어올려요"
        case .maintain: return "지금의 균형 잡힌 체형을 유지해요"
        }
    }
}

struct ExerciseRecommendation: Identifiable {
    let id = UUID()
    let exercise: ExerciseType
    let reason: String
    let prescription: String
    /// 한 세트 목표 (스쿼트·푸쉬업은 횟수, 플랭크는 초)
    let goal: Int
}

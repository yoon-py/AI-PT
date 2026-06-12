import Foundation

/// 운동 가이드 한 단계 (시작 자세 / 동작 / 호흡)
struct GuideStep: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let detail: String
}

/// 실시간 자세 분석기 종류 — 같은 동작 패턴은 같은 분석기를 공유한다.
enum AnalyzerKind {
    case squat   // 하체 굴신
    case pushUp  // 상체 푸쉬
    case plank   // 코어 유지(정적)
}

/// 인체 바디맵에서 강조할 근육 부위 (표시 순서 = CaseIterable 순)
enum MuscleZone: String, Hashable, CaseIterable {
    case chest = "가슴"
    case shoulders = "어깨"
    case arms = "팔"
    case core = "코어"
    case legs = "하체"
}

/// 운동 종류별 분석기/설명/난이도/타겟/가이드 콘텐츠
extension ExerciseType {
    /// 어떤 분석기로 자세를 측정할지
    var analyzerKind: AnalyzerKind {
        switch self {
        case .squat, .wideSquat, .jumpSquat: return .squat
        case .pushUp, .kneePushUp, .widePushUp, .inclinePushUp: return .pushUp
        case .plank, .sidePlank: return .plank
        }
    }

    /// 목표 단위 (플랭크 계열은 초, 나머지는 회)
    var goalUnit: String { analyzerKind == .plank ? "초" : "회" }

    /// 카드 부제 (타겟 부위)
    var targetLabel: String {
        switch analyzerKind {
        case .squat: return "하체 · 코어"
        case .pushUp: return "가슴 · 팔 · 어깨"
        case .plank: return "코어 · 복부"
        }
    }

    /// 부위 칩/루틴명 계산용 (간결한 부위 묶음)
    var bodyParts: [String] {
        switch analyzerKind {
        case .squat: return ["하체", "코어"]
        case .pushUp: return ["상체", "코어"]
        case .plank: return ["코어"]
        }
    }

    /// 바디맵에서 빨갛게 강조할 근육 부위
    var muscleZones: Set<MuscleZone> {
        switch analyzerKind {
        case .squat: return [.legs, .core]
        case .pushUp: return [.chest, .arms, .shoulders, .core]
        case .plank: return [.core]
        }
    }

    /// 운동 목록 그룹명
    var groupTitle: String {
        switch analyzerKind {
        case .squat: return "하체"
        case .pushUp: return "상체"
        case .plank: return "코어"
        }
    }

    var difficulty: String {
        switch self {
        case .squat, .wideSquat, .plank, .kneePushUp, .inclinePushUp: return "초급"
        case .jumpSquat, .pushUp, .widePushUp, .sidePlank: return "중급"
        }
    }

    /// 목록·가이드에 쓰는 한 줄 설명
    var summary: String {
        switch self {
        case .squat: return "하체 큰 근육을 써서 칼로리 소모와 근력 향상에 효과적인 기본 운동"
        case .wideSquat: return "다리를 넓게 벌려 허벅지 안쪽과 엉덩이를 강하게 자극하는 스쿼트"
        case .jumpSquat: return "스쿼트에 점프를 더해 심박수를 올리고 폭발력을 키우는 운동"
        case .pushUp: return "기구 없이 상체 전체를 단련하는 대표 맨몸 운동"
        case .kneePushUp: return "무릎을 대고 부담을 줄여 초보자도 쉽게 하는 푸쉬업"
        case .widePushUp: return "손 간격을 넓혀 가슴 바깥쪽을 집중 자극하는 푸쉬업"
        case .inclinePushUp: return "상체를 높여 강도를 낮춘, 입문자에게 좋은 푸쉬업"
        case .plank: return "몸통을 버티며 코어 안정성과 자세를 잡아주는 운동"
        case .sidePlank: return "옆구리와 복부 측면을 단련하는 코어 운동"
        }
    }

    /// 직접 선택 시 기본 목표 (회 또는 초)
    var defaultGoal: Int {
        switch self {
        case .squat, .wideSquat: return 12
        case .jumpSquat, .pushUp, .widePushUp: return 10
        case .kneePushUp, .inclinePushUp: return 12
        case .plank: return 30
        case .sidePlank: return 20
        }
    }

    /// 운동 강도 (MET) — 칼로리 추정용
    var met: Double {
        switch self {
        case .squat, .wideSquat:          return 5.0
        case .jumpSquat:                  return 8.0
        case .pushUp, .widePushUp:        return 4.0
        case .kneePushUp, .inclinePushUp: return 3.8
        case .plank, .sidePlank:          return 3.0
        }
    }

    /// 반복 1회당 소요 시간(초) — 동작 + 세트 사이 휴식·페이스를 환산한 실제 체감 시간.
    /// 플랭크 계열은 count가 곧 초라 사용 안 함.
    var secondsPerRep: Double {
        switch analyzerKind {
        case .squat:  return 7.0
        case .pushUp: return 6.0
        case .plank:  return 1.0
        }
    }

    /// count(횟수, 플랭크는 초)로부터 운동 소요 시간(초) 추정
    func activeSeconds(count: Int) -> Double {
        analyzerKind == .plank ? Double(count) : Double(count) * secondsPerRep
    }

    /// MET 기반 소모 칼로리 (gross) — MET × 체중(kg) × 시간(h). 운동으로 태운 칼로리 체감용.
    func burnedKcal(count: Int, weightKg: Double) -> Int {
        let hours = activeSeconds(count: count) / 3600
        return Int((met * weightKg * hours).rounded())
    }

    /// 추천 루틴 미리보기용 추정 — 3세트 기준
    func estimatedRoutineKcal(perSetGoal goal: Int, weightKg: Double) -> Int {
        burnedKcal(count: goal * 3, weightKg: weightKg)
    }

    /// 시작 전 가이드 (시작 자세 → 동작 → 호흡)
    var guideSteps: [GuideStep] {
        switch analyzerKind {
        case .squat:
            return [
                GuideStep(title: "시작 자세", icon: "figure.stand",
                          detail: "발을 어깨너비로 벌리고 발끝은 살짝 바깥으로. 가슴을 펴고 시선은 정면을 봐요."),
                GuideStep(title: "운동 동작", icon: "arrow.down.circle",
                          detail: "엉덩이를 뒤로 빼며 허벅지가 바닥과 평행이 될 때까지 천천히 앉았다가, 발뒤꿈치로 밀며 일어나요."),
                GuideStep(title: "호흡법", icon: "wind",
                          detail: "내려갈 때 숨을 들이마시고, 올라올 때 내쉬어요.")
            ]
        case .pushUp:
            return [
                GuideStep(title: "시작 자세", icon: "figure.stand",
                          detail: "손은 어깨너비보다 약간 넓게 짚고, 머리부터 발끝까지 일직선을 만들어요."),
                GuideStep(title: "운동 동작", icon: "arrow.down.circle",
                          detail: "팔꿈치를 굽혀 가슴이 바닥에 가까워질 때까지 내려간 뒤, 밀어 올려 시작 자세로 돌아와요."),
                GuideStep(title: "호흡법", icon: "wind",
                          detail: "내려갈 때 들이마시고, 밀어 올릴 때 내쉬어요.")
            ]
        case .plank:
            return [
                GuideStep(title: "시작 자세", icon: "figure.stand",
                          detail: "팔꿈치를 어깨 바로 아래에 두고 전완으로 지지해요. 머리-엉덩이-발이 일직선이 되게."),
                GuideStep(title: "운동 동작", icon: "timer",
                          detail: "복부와 엉덩이에 힘을 주고 목표 시간 동안 자세를 그대로 유지해요."),
                GuideStep(title: "호흡법", icon: "wind",
                          detail: "멈추지 말고 천천히 규칙적으로 호흡해요.")
            ]
        }
    }

    /// 주의 팁
    var tip: String {
        switch analyzerKind {
        case .squat: return "무릎이 안쪽으로 모이지 않게 발끝 방향과 맞춰주세요."
        case .pushUp: return "허리가 꺾이거나 엉덩이가 솟지 않게 코어에 힘을 주세요."
        case .plank: return "엉덩이가 처지거나 솟지 않게 일직선을 유지하세요."
        }
    }
}

import Foundation

enum ExercisePhase: String {
    // Common
    case standing = "서있기"
    case descending = "내려가기"
    case bottom = "최저점"
    case ascending = "올라가기"
    // Push-up
    case plankPosition = "플랭크 자세"
    // Plank
    case holding = "유지 중"
}

struct ExerciseState {
    var phase: ExercisePhase = .standing
    var repCount: Int = 0
    var holdTime: TimeInterval = 0
    var currentAngles: [String: Double] = [:]
    var isFormCorrect: Bool = true
}

enum ExerciseType: String, CaseIterable, Identifiable, Codable {
    // 하체 (스쿼트 패턴)
    case squat = "스쿼트"
    case wideSquat = "와이드 스쿼트"
    case jumpSquat = "점프 스쿼트"
    // 상체 (푸쉬업 패턴)
    case pushUp = "푸쉬업"
    case kneePushUp = "무릎 푸쉬업"
    case widePushUp = "와이드 푸쉬업"
    case inclinePushUp = "인클라인 푸쉬업"
    // 코어 (플랭크 패턴)
    case plank = "플랭크"
    case sidePlank = "사이드 플랭크"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .squat, .wideSquat: return "figure.strengthtraining.functional"
        case .jumpSquat: return "figure.highintensity.intervaltraining"
        case .pushUp, .kneePushUp, .widePushUp, .inclinePushUp: return "figure.cross.training"
        case .plank, .sidePlank: return "figure.core.training"
        }
    }
}

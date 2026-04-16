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

enum ExerciseType: String, CaseIterable, Identifiable {
    case squat = "스쿼트"
    case pushUp = "푸쉬업"
    case plank = "플랭크"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .squat: return "figure.walk"
        case .pushUp: return "figure.roll"
        case .plank: return "figure.mind.and.body"
        }
    }
}

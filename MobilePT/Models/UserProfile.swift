import Foundation

/// 운동 경험 수준 (온보딩에서 선택)
enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner = "입문"
    case novice = "초급"
    case intermediate = "중급"
    case advanced = "고급"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .beginner: return "운동 자세, 루틴 등 아무것도 몰라요"
        case .novice: return "자세는 조금 알지만 무슨 운동을 할지 몰라요"
        case .intermediate: return "운동 자세를 잘 알고, 나만의 루틴이 있어요"
        case .advanced: return "운동을 직업으로 삼을 만큼 지식이 있어요"
        }
    }
}

/// 운동 시작 시점 (온보딩에서 선택)
enum StartTiming: String, Codable, CaseIterable, Identifiable {
    case now = "지금 바로 할래요"
    case tomorrow = "내일 할래요"
    case thisWeek = "이번 주에 할래요"

    var id: String { rawValue }
}

/// 온보딩에서 수집한 사용자 정보
struct UserProfile: Codable, Equatable {
    var level: ExperienceLevel = .beginner
    var primaryGoal: FitnessGoal = .fatLoss
    var weeklyGoal: Int = 4         // 주간 운동 횟수
    var startTiming: StartTiming = .now
}

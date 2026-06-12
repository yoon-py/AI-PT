import Foundation

/// 한 번의 운동 세션 기록
struct WorkoutLog: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var exercise: ExerciseType
    var count: Int      // 완료 횟수 (플랭크는 초)
    var goal: Int

    var goalReached: Bool { count >= goal }

    /// "12 / 12회" 또는 플랭크 "40 / 40초"
    var summary: String {
        "\(count) / \(goal)\(exercise.goalUnit)"
    }
}

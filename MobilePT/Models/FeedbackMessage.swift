import Foundation

enum FeedbackType {
    case correction
    case encouragement
    case repCount
    case positionWarning
    case coaching      // LLM이 생성한 코칭 문장
}

struct FeedbackMessage: Identifiable {
    let id = UUID()
    let text: String
    let type: FeedbackType
    let priority: Int
    let timestamp = Date()
}

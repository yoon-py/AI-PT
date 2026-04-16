import Foundation

enum FeedbackType {
    case correction
    case encouragement
    case repCount
    case positionWarning
}

struct FeedbackMessage: Identifiable {
    let id = UUID()
    let text: String
    let type: FeedbackType
    let priority: Int
    let timestamp = Date()
}

import Foundation

final class FeedbackEngine: ObservableObject {
    @Published var latestFeedback: FeedbackMessage?

    var muteLocalVoice = false

    private let voiceService = VoiceFeedbackService()
    private var lastFeedbackTime: [String: Date] = [:]

    private let cooldowns: [FeedbackType: TimeInterval] = [
        .correction: 3.0,
        .encouragement: 1.0,
        .repCount: 0.5,
        .positionWarning: 4.0
    ]

    func process(_ messages: [FeedbackMessage]) {
        let sorted = messages.sorted { $0.priority > $1.priority }

        for message in sorted {
            if shouldDeliver(message) {
                deliver(message)
                break
            }
        }
    }

    private func shouldDeliver(_ message: FeedbackMessage) -> Bool {
        let key = "\(message.type)-\(message.text)"
        let cooldown = cooldowns[message.type] ?? 2.0
        if let last = lastFeedbackTime[key],
           Date().timeIntervalSince(last) < cooldown {
            return false
        }
        return true
    }

    private func deliver(_ message: FeedbackMessage) {
        let key = "\(message.type)-\(message.text)"
        lastFeedbackTime[key] = Date()
        latestFeedback = message
        if !muteLocalVoice {
            voiceService.speak(message.text)
        }
    }

    func reset() {
        lastFeedbackTime.removeAll()
        latestFeedback = nil
    }
}

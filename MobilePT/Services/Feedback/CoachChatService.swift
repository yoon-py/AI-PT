import Foundation

/// 대화형 AI 코치 — 운동·식단 컨텍스트를 시스템 프롬프트로 깔고 멀티턴 대화를 이어간다.
final class CoachChatService {
    private let apiKey: String
    private let model = "gpt-4o-mini"

    var isConfigured: Bool { !apiKey.isEmpty }

    init(apiKey: String) { self.apiKey = apiKey }

    func reply(system: String, history: [ChatMessage]) async throws -> String {
        guard !apiKey.isEmpty else { throw FoodVisionError.notConfigured }

        var messages: [[String: Any]] = [["role": "system", "content": system]]
        for m in history {
            messages.append(["role": m.role == .user ? "user" : "assistant", "content": m.text])
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": 320,
            "temperature": 0.7
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw FoodVisionError.parse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

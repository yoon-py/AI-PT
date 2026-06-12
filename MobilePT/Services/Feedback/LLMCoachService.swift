import Foundation

/// 센서로 측정한 포즈 요약(각도/단계/반복/감지신호)을 LLM에 보내고,
/// 전문 트레이너처럼 추론한 짧은 코칭 한 문장을 받아온다.
/// 일정 간격으로만 호출하고, 직전과 같은 말은 거르며, 동시 요청은 막는다.
final class LLMCoachService: @unchecked Sendable {
    private let apiKey: String
    private let model = "gpt-4o-mini"
    private let exerciseType: String
    /// 인바디 체성분 요약 (있으면 코칭을 개인화)
    private let userProfile: String?

    private let urlSession = URLSession(configuration: .default)
    private let minInterval: TimeInterval = 3.0

    private let lock = NSLock()
    private var inFlight = false
    private var lastCallTime: Date = .distantPast
    private var lastLine = ""

    /// 코칭 문장이 준비되면 호출됨 (호출 스레드는 백그라운드일 수 있음).
    var onCoaching: ((String) -> Void)?

    var isConfigured: Bool { !apiKey.isEmpty }

    init(apiKey: String, exerciseType: String, userProfile: String? = nil) {
        self.apiKey = apiKey
        self.exerciseType = exerciseType
        self.userProfile = userProfile
    }

    private var systemPrompt: String {
        var prompt = """
        너는 전문 헬스 트레이너야. 사용자가 \(exerciseType) 운동 중이고,
        센서로 측정한 관절 각도·단계·반복수·감지된 신호를 텍스트로 받는다.

        규칙:
        - 한국어로, 딱 한 문장. 짧고 힘차게. (예: "무릎 더 벌려!", "좋아, 그 깊이 그대로!")
        - 받은 데이터를 근거로 가장 중요한 것 하나만 코칭해.
        - 자세가 좋으면 격려, 문제가 있으면 즉시 교정 지시.
        - 매번 같은 말 반복하지 마. 직전에 한 말과 다르게.
        - 각도 숫자를 그대로 읽지 말고, 사람 트레이너처럼 자연스럽게 말해.
        """
        if let userProfile {
            prompt += """


            사용자 인바디 체성분: \(userProfile)
            이 데이터를 코칭에 반영해. 특히 약한 부위나 좌우 불균형이 있으면
            해당 부위를 의식하도록 코칭하고, 가끔 그 이유를 짧게 곁들여줘.
            (예: "왼다리가 약하니 왼쪽에 힘 더 줘!")
            """
        }
        return prompt
    }

    func coach(context: String) {
        guard !apiKey.isEmpty,
              let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }

        // 간격 제한 + 동시 요청 차단
        lock.lock()
        let now = Date()
        if inFlight || now.timeIntervalSince(lastCallTime) < minInterval {
            lock.unlock()
            return
        }
        inFlight = true
        lastCallTime = now
        let previous = lastLine
        lock.unlock()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let userContent = previous.isEmpty
            ? context
            : "\(context)\n직전에 한 말: \"\(previous)\" — 이 말은 반복하지 마."

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ],
            "max_tokens": 40,
            "temperature": 0.8
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = urlSession.dataTask(with: request) { [weak self] data, _, error in
            guard let self else { return }
            defer {
                self.lock.lock(); self.inFlight = false; self.lock.unlock()
            }

            guard let data, error == nil else {
                print("[LLMCoach] request failed: \(error?.localizedDescription ?? "no data")")
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let text = message["content"] as? String else {
                print("[LLMCoach] unexpected response: \(String(data: data, encoding: .utf8) ?? "")")
                return
            }
            let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { return }

            self.lock.lock()
            self.lastLine = line
            self.lock.unlock()

            self.onCoaching?(line)
        }
        task.resume()
    }

    func reset() {
        lock.lock()
        lastLine = ""
        lastCallTime = .distantPast
        inFlight = false
        lock.unlock()
    }
}

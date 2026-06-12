import Foundation

/// 오늘 식단(섭취/소비/수지/단백질/먹은 음식)과 사용자 목표·체성분을 LLM에 보내
/// 전문 영양 코치처럼 구체적인 식단 코칭을 받아온다. 운동 코치의 식단 버전.
struct DietCoachInput {
    let profile: String?      // 인바디 체성분 요약
    let goal: String          // 목표 (체지방 감량 등)
    let intake: Int
    let burn: Int
    let net: Int
    let proteinG: Int
    let proteinTarget: Int?
    let foods: [String]       // 오늘 먹은 음식명
}

enum DietCoachError: Error { case notConfigured, parse }

final class DietCoachService {
    private let apiKey: String
    private let model = "gpt-4o-mini"

    var isConfigured: Bool { !apiKey.isEmpty }

    init(apiKey: String) { self.apiKey = apiKey }

    func coach(_ input: DietCoachInput) async throws -> String {
        guard !apiKey.isEmpty else { throw DietCoachError.notConfigured }

        let system = """
        너는 전문 영양 코치야. 사용자의 목표·체성분과 오늘 식단 데이터를 받고,
        딱 2~3문장의 한국어 코칭을 준다.

        규칙:
        - 목표 방향을 반드시 반영해. 감량이면 적자, 근육 증가면 흑자·고단백, 유지면 균형.
        - 남은 칼로리/단백질을 근거로 "지금 무엇을 먹으면 좋은지" 구체적 음식 1~2개를 추천해.
          (예: "단백질이 30g 부족해요. 닭가슴살이나 그릭요거트로 채워볼까요?")
        - 숫자를 그대로 나열하지 말고 코치처럼 자연스럽게. 힘차고 따뜻하게.
        - 운동으로 태운 칼로리가 있으면 "오늘 운동했으니" 같이 식단과 운동을 엮어 말해.
        """

        var lines: [String] = []
        lines.append("목표: \(input.goal)")
        if let p = input.profile { lines.append("체성분: \(p)") }
        lines.append("오늘 섭취: \(input.intake)kcal, 소비: \(input.burn)kcal (운동 포함), 수지: \(input.net)kcal")
        if let t = input.proteinTarget {
            lines.append("단백질: \(input.proteinG)g / 권장 \(t)g")
        } else {
            lines.append("단백질: \(input.proteinG)g")
        }
        lines.append("먹은 음식: \(input.foods.isEmpty ? "아직 없음" : input.foods.joined(separator: ", "))")
        let userContent = lines.joined(separator: "\n")

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": userContent]
            ],
            "max_tokens": 160,
            "temperature": 0.7
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw DietCoachError.parse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

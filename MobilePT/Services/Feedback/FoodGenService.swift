import Foundation

/// 음식 이름만으로 영양성분(1회분 기준)을 LLM으로 생성한다 — 검색에 없을 때의 "AI 생성".
final class FoodGenService {
    private let apiKey: String
    private let model = "gpt-4o-mini"

    init(apiKey: String) { self.apiKey = apiKey }

    func generate(name: String) async throws -> FoodDBItem {
        guard !apiKey.isEmpty else { throw FoodVisionError.notConfigured }

        let system = """
        너는 음식 영양 전문가야. 음식 이름을 받으면 흔한 1회분(1인분) 기준으로
        영양성분을 추정해 JSON만 출력해.
        {"name":"음식명","serving":"1회분 설명 (그램)","grams":숫자,"kcal":정수,"carbs":숫자,"protein":숫자,"fat":숫자}
        serving 예: "1인분 (300g)". 음식이 아니면 kcal 0.
        """

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": name]
            ],
            "max_tokens": 200,
            "temperature": 0.3,
            "response_format": ["type": "json_object"]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8),
              let p = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            throw FoodVisionError.parse
        }

        func dbl(_ key: String) -> Double {
            if let n = p[key] as? NSNumber { return n.doubleValue }
            return (p[key] as? Double) ?? 0
        }
        let nm = (p["name"] as? String) ?? name
        let serving = (p["serving"] as? String) ?? "1인분"
        let kcal = (p["kcal"] as? NSNumber)?.intValue ?? Int(dbl("kcal"))
        return FoodDBItem(name: nm, serving: serving, grams: dbl("grams"),
                          kcal: kcal, carbs: dbl("carbs"), protein: dbl("protein"), fat: dbl("fat"),
                          isAI: true)
    }
}

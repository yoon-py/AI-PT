import Foundation
import UIKit

/// 사진에서 인식된 음식 한 항목
struct FoodItem: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var kcal: Int
    var carbs: Double?
    var protein: Double?
    var fat: Double?
    /// 사진 내 대략적 위치 (0~1 정규화 중심좌표). 없을 수 있음.
    var x: Double?
    var y: Double?
}

/// 한 장(한 끼)의 분석 결과 — 여러 음식 항목 + 합산 지표
struct FoodAnalysis {
    var items: [FoodItem]

    /// 대표 제목 — "햄버거 외 3개"
    var title: String {
        guard let first = items.first else { return "음식" }
        return items.count > 1 ? "\(first.name) 외 \(items.count - 1)개" : first.name
    }

    var totalKcal: Int { items.reduce(0) { $0 + $1.kcal } }
    var totalCarbs: Double { items.reduce(0) { $0 + ($1.carbs ?? 0) } }
    var totalProtein: Double { items.reduce(0) { $0 + ($1.protein ?? 0) } }
    var totalFat: Double { items.reduce(0) { $0 + ($1.fat ?? 0) } }
}

enum FoodVisionError: Error {
    case notConfigured
    case badImage
    case parse
}

final class FoodVisionService {
    private let apiKey: String
    private let model = "gpt-4o-mini"

    var isConfigured: Bool { !apiKey.isEmpty }

    init(apiKey: String) { self.apiKey = apiKey }

    func analyze(image: UIImage) async throws -> FoodAnalysis {
        guard !apiKey.isEmpty else { throw FoodVisionError.notConfigured }
        guard let jpeg = image.jpegData(compressionQuality: 0.6) else { throw FoodVisionError.badImage }
        let dataURL = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let system = """
        너는 음식 사진 분석 전문가야. 사진 속 음식을 '항목별로' 구분해 분석해.
        각 음식마다: 한국어 이름(name), 추정 칼로리(kcal, 정수),
        탄수화물/단백질/지방(carbs/protein/fat, g, 숫자),
        그리고 사진에서의 대략적 중심 위치(x,y: 0~1, 좌상단이 0,0 / 우하단이 1,1)를 추정해.
        반드시 JSON만 출력:
        {"items":[{"name":"음식명","kcal":정수,"carbs":숫자,"protein":숫자,"fat":숫자,"x":0~1,"y":0~1}]}
        접시·반찬이 여러 개면 각각 항목으로 나눠. 음식이 아니면 {"items":[]}.
        """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": [
                    ["type": "text", "text": "이 사진의 음식들을 항목별로 분석해줘."],
                    ["type": "image_url", "image_url": ["url": dataURL]]
                ]]
            ],
            "max_tokens": 700,
            "temperature": 0.2,
            "response_format": ["type": "json_object"]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            throw FoodVisionError.parse
        }

        let rawItems = parsed["items"] as? [[String: Any]] ?? []
        let items: [FoodItem] = rawItems.compactMap { dict in
            func dbl(_ key: String) -> Double? {
                if let n = dict[key] as? NSNumber { return n.doubleValue }
                return dict[key] as? Double
            }
            guard let name = dict["name"] as? String, !name.isEmpty else { return nil }
            let kcal = (dict["kcal"] as? NSNumber)?.intValue ?? Int(dbl("kcal") ?? 0)
            return FoodItem(name: name, kcal: kcal,
                            carbs: dbl("carbs"), protein: dbl("protein"), fat: dbl("fat"),
                            x: dbl("x"), y: dbl("y"))
        }
        return FoodAnalysis(items: items)
    }
}

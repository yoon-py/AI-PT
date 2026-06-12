import Foundation

/// 식약처(식품안전나라) 식품영양성분 DB Open API 연동 — 음식명으로 공식 영양정보를 조회한다.
/// 서비스 I2790(식품영양성분DB). 키는 https://www.foodsafetykorea.go.kr/api/ 에서 무료 발급.
/// 키가 없으면 빈 결과를 반환해 로컬 DB만으로도 동작한다.
final class MFDSFoodService {
    private let key: String
    private let serviceId = "I2790"

    var isConfigured: Bool { !key.isEmpty }

    init(key: String) { self.key = key }

    func search(_ query: String, limit: Int = 20) async -> [FoodDBItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !q.isEmpty,
              let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://openapi.foodsafetykorea.go.kr/api/\(key)/\(serviceId)/json/1/\(limit)/DESC_KOR=\(encoded)")
        else { return [] }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let service = json[serviceId] as? [String: Any],
              let rows = service["row"] as? [[String: Any]] else {
            return []
        }
        return rows.compactMap(parse)
    }

    /// I2790 한 행 → FoodDBItem. NUTR_CONT 값은 SERVING_SIZE(기준량, 보통 100g) 기준.
    private func parse(_ r: [String: Any]) -> FoodDBItem? {
        func num(_ key: String) -> Double {
            Double((r[key] as? String ?? "").trimmingCharacters(in: .whitespaces)) ?? 0
        }
        guard let rawName = r["DESC_KOR"] as? String else { return nil }
        let name = rawName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        let kcal = Int(num("NUTR_CONT1").rounded())
        guard kcal > 0 else { return nil }

        let servingRaw = (r["SERVING_SIZE"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        let grams = Double(servingRaw.filter { $0.isNumber || $0 == "." }) ?? 0
        let serving: String
        if servingRaw.isEmpty {
            serving = "100g"
        } else if servingRaw.contains("g") || servingRaw.contains("ml") {
            serving = servingRaw
        } else {
            serving = "\(servingRaw)g"
        }

        return FoodDBItem(
            name: name,
            serving: serving,
            grams: grams > 0 ? grams : 100,
            kcal: kcal,
            carbs: num("NUTR_CONT2"),
            protein: num("NUTR_CONT3"),
            fat: num("NUTR_CONT4"),
            official: true
        )
    }
}

import Foundation

/// 음식 영양 데이터베이스 한 항목
struct FoodDBItem: Codable, Identifiable, Equatable {
    let name: String
    let serving: String      // "1회분(반마리) (400g)"
    let grams: Double
    let kcal: Int
    let carbs: Double
    let protein: Double
    let fat: Double
    var popularity: Int = 0
    var isAI: Bool = false       // AI 생성/직접 등록 표시
    var official: Bool = false   // 식약처 공식 DB 출처

    var id: String { "\(name)|\(serving)" }

    /// 출처/인기 뱃지
    var sourceBadge: String? {
        if official { return "식약처" }
        switch popularity {
        case 100_000...: return "10만회 이상"
        case 10_000...:  return "1만회 이상"
        case 5_000...:   return "5천회 이상"
        case 1_000...:   return "1천회 이상"
        default:         return nil
        }
    }

    init(name: String, serving: String, grams: Double, kcal: Int,
         carbs: Double, protein: Double, fat: Double,
         popularity: Int = 0, isAI: Bool = false, official: Bool = false) {
        self.name = name; self.serving = serving; self.grams = grams; self.kcal = kcal
        self.carbs = carbs; self.protein = protein; self.fat = fat
        self.popularity = popularity; self.isAI = isAI; self.official = official
    }

    /// 시드 JSON에 popularity/isAI가 없어도 안전하게 디코딩
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        serving = try c.decode(String.self, forKey: .serving)
        grams = try c.decode(Double.self, forKey: .grams)
        kcal = try c.decode(Int.self, forKey: .kcal)
        carbs = try c.decode(Double.self, forKey: .carbs)
        protein = try c.decode(Double.self, forKey: .protein)
        fat = try c.decode(Double.self, forKey: .fat)
        popularity = (try? c.decode(Int.self, forKey: .popularity)) ?? 0
        isAI = (try? c.decode(Bool.self, forKey: .isAI)) ?? false
        official = (try? c.decode(Bool.self, forKey: .official)) ?? false
    }

    /// 기록용 FoodLog 변환
    func toFoodLog(meal: MealType) -> FoodLog {
        FoodLog(date: Date(), name: name, kcal: kcal,
                carbs: carbs, protein: protein, fat: fat, meal: meal)
    }
}

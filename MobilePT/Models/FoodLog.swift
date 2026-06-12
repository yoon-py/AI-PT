import Foundation

/// 끼니 구분 — 식단을 시간대별로 묶어 보여준다.
enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "아침"
    case lunch = "점심"
    case dinner = "저녁"
    case snack = "간식"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "cup.and.saucer.fill"
        }
    }

    /// 표시 순서 (아침 → 간식)
    static var ordered: [MealType] { [.breakfast, .lunch, .dinner, .snack] }

    /// 현재 시각으로 끼니 자동 추정 (기록 시 기본 선택값)
    static var current: MealType {
        switch Calendar.current.component(.hour, from: Date()) {
        case 4..<11:  return .breakfast
        case 11..<15: return .lunch
        case 15..<18: return .snack
        case 18..<23: return .dinner
        default:      return .snack
        }
    }
}

/// 한 끼(또는 한 음식) 기록 — AI 분석 또는 수동 입력
struct FoodLog: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var name: String
    var kcal: Int
    var carbs: Double?     // 탄수화물 (g)
    var protein: Double?   // 단백질 (g)
    var fat: Double?       // 지방 (g)
    var meal: MealType = .snack
    var imageFileName: String?   // 음식 사진 파일명 (FoodImageStore)

    init(id: UUID = UUID(), date: Date, name: String, kcal: Int,
         carbs: Double? = nil, protein: Double? = nil, fat: Double? = nil,
         meal: MealType = .snack, imageFileName: String? = nil) {
        self.id = id
        self.date = date
        self.name = name
        self.kcal = kcal
        self.carbs = carbs
        self.protein = protein
        self.fat = fat
        self.meal = meal
        self.imageFileName = imageFileName
    }

    /// 기존 기록(끼니 필드 없음)과 호환되도록 방어적으로 디코딩
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        date = try c.decode(Date.self, forKey: .date)
        name = try c.decode(String.self, forKey: .name)
        kcal = try c.decode(Int.self, forKey: .kcal)
        carbs = try? c.decode(Double.self, forKey: .carbs)
        protein = try? c.decode(Double.self, forKey: .protein)
        fat = try? c.decode(Double.self, forKey: .fat)
        meal = (try? c.decode(MealType.self, forKey: .meal)) ?? .snack
        imageFileName = try? c.decode(String.self, forKey: .imageFileName)
    }
}

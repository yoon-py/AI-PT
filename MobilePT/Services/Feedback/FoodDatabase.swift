import Foundation

/// 음식 영양 데이터베이스 — 번들 시드(foods.json) + 사용자/AI가 추가한 음식(UserDefaults)을 합쳐
/// 검색을 제공한다. 추가된 음식은 누적 저장되어 다음 검색에도 나타난다(DB가 자라남).
final class FoodDatabase: ObservableObject {
    static let shared = FoodDatabase()

    @Published private(set) var items: [FoodDBItem] = []

    private var seed: [FoodDBItem] = []
    private var custom: [FoodDBItem] = []
    private let defaults = UserDefaults.standard
    private let customKey = "food.db.custom"

    init() {
        loadSeed()
        loadCustom()
        rebuild()
    }

    // MARK: - 검색

    func search(_ query: String) -> [FoodDBItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let matches = items.filter { $0.name.localizedCaseInsensitiveContains(q) }
        return matches.sorted { a, b in
            let ap = a.name.hasPrefix(q), bp = b.name.hasPrefix(q)
            if ap != bp { return ap }                 // 접두 일치 우선
            if a.popularity != b.popularity { return a.popularity > b.popularity }
            return a.name.count < b.name.count        // 짧은 이름 우선
        }
    }

    // MARK: - 추가 (직접 등록 / AI 생성)

    func addCustom(_ item: FoodDBItem) {
        // 같은 id가 이미 있으면 갱신
        custom.removeAll { $0.id == item.id }
        custom.insert(item, at: 0)
        saveCustom()
        rebuild()
    }

    // MARK: - 내부

    private func rebuild() {
        // 사용자 추가분을 앞에, 그다음 시드
        items = custom + seed
    }

    private func loadSeed() {
        guard let url = Bundle.main.url(forResource: "foods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([FoodDBItem].self, from: data) else {
            seed = []
            return
        }
        seed = decoded
    }

    private func loadCustom() {
        guard let data = defaults.data(forKey: customKey),
              let decoded = try? JSONDecoder().decode([FoodDBItem].self, from: data) else {
            custom = []
            return
        }
        custom = decoded
    }

    private func saveCustom() {
        if let data = try? JSONEncoder().encode(custom) {
            defaults.set(data, forKey: customKey)
        }
    }
}

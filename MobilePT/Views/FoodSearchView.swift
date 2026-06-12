import SwiftUI

/// 음식 검색 — DB에서 검색해 여러 개를 골라 끼니에 한 번에 기록. 없으면 직접 등록/AI 생성.
struct FoodSearchView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var db = FoodDatabase.shared
    var meal: MealType = .current

    @State private var query = ""
    @State private var selected: [FoodDBItem] = []
    @State private var selectedMeal: MealType = .current
    @State private var generating = false
    @State private var showManual = false
    @State private var remote: [FoodDBItem] = []     // 식약처 공식 DB 결과
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    private var openAIKey: String {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            ?? Secrets.openAIAPIKey
    }
    private var mfdsKey: String {
        ProcessInfo.processInfo.environment["FOODSAFETY_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "FOODSAFETY_KEY") as? String
            ?? Secrets.foodSafetyKoreaKey
    }

    /// 로컬 DB + 식약처 공식 DB 병합 (이름 중복은 로컬 우선)
    private var results: [FoodDBItem] {
        let local = db.search(query)
        let names = Set(local.map { $0.name })
        return local + remote.filter { !names.contains($0.name) }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { item in
                        row(item)
                        Divider().padding(.leading, 16)
                    }
                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        notFoundCard
                    }
                }
            }
            bottomBar
        }
        .background(Theme.bg.ignoresSafeArea())
        .task { selectedMeal = meal; focused = true }
        .onChange(of: query) { _ in scheduleRemoteSearch() }
        .sheet(isPresented: $showManual) {
            FoodItemEditView(item: nil, onSave: { fi in addManual(fi) })
        }
    }

    // MARK: - 검색바

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("음식 검색", text: $query)
                    .focused($focused)
                    .autocorrectionDisabled()
                if searching {
                    ProgressView().scaleEffect(0.8)
                } else if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))

            Button("취소") { dismiss() }
                .font(.subheadline).foregroundColor(Theme.ink)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: - 결과 행

    private func row(_ item: FoodDBItem) -> some View {
        let isSelected = selected.contains { $0.id == item.id }
        return Button {
            toggle(item)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        highlighted(item.name)
                            .font(.subheadline.weight(.semibold)).foregroundColor(Theme.ink)
                        Image(systemName: item.isAI ? "sparkles" : "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundColor(item.isAI ? .orange : Color(red: 0.27, green: 0.53, blue: 0.96))
                    }
                    Text(item.serving).font(.caption).foregroundColor(.secondary)
                    if let badge = item.sourceBadge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(item.official ? Color(red: 0.27, green: 0.53, blue: 0.96) : Theme.accent)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background((item.official ? Color(red: 0.27, green: 0.53, blue: 0.96) : Theme.accent).opacity(0.14),
                                        in: Capsule())
                    }
                }
                Spacer()
                Text("\(item.kcal)kcal").font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(isSelected ? Theme.accent : Color(.systemGray3))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func highlighted(_ name: String) -> Text {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, let range = name.range(of: q, options: .caseInsensitive) else {
            return Text(name)
        }
        return Text(String(name[..<range.lowerBound]))
            + Text(String(name[range])).foregroundColor(Theme.accent)
            + Text(String(name[range.upperBound...]))
    }

    // MARK: - 못 찾았을 때

    private var notFoundCard: some View {
        VStack(spacing: 12) {
            Text("찾는 음식이 없나요?").font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
            HStack(spacing: 12) {
                fallbackButton("square.and.pencil", "직접 등록", "영양성분") { showManual = true }
                fallbackButton("sparkles", "AI 생성", generating ? "생성 중…" : "1초 만에") {
                    generate()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .padding(.top, 8)
    }

    private func fallbackButton(_ icon: String, _ title: String, _ sub: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(sub).font(.caption2).foregroundColor(.secondary)
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(generating)
    }

    // MARK: - 하단 (끼니 + 기록)

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(MealType.ordered) { m in
                    Button { selectedMeal = m } label: { Label(m.rawValue, systemImage: m.icon) }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedMeal.rawValue).font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
                    Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            }

            Button { record() } label: {
                Text(selected.isEmpty ? "음식을 선택하세요" : "\(selected.count)개 기록하기")
                    .font(.headline.weight(.bold)).foregroundColor(Theme.onAccent)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(selected.isEmpty ? Color(.systemGray3) : Theme.accent,
                                in: RoundedRectangle(cornerRadius: Theme.radius))
            }
            .disabled(selected.isEmpty)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    // MARK: - 액션

    private func toggle(_ item: FoodDBItem) {
        if let i = selected.firstIndex(where: { $0.id == item.id }) {
            selected.remove(at: i)
        } else {
            selected.append(item)
        }
    }

    private func scheduleRemoteSearch() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !mfdsKey.isEmpty else { remote = []; searching = false; return }
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)   // 디바운스
            if Task.isCancelled { return }
            searching = true
            let items = await MFDSFoodService(key: mfdsKey).search(q)
            if Task.isCancelled { return }
            remote = items
            searching = false
        }
    }

    private func record() {
        for item in selected {
            store.logFood(item.toFoodLog(meal: selectedMeal))
            // 공식/AI/직접 등록 음식은 로컬 DB에 캐시 → 다음 검색에 바로 등장
            if item.official || item.isAI { db.addCustom(item) }
        }
        store.resetDietDateToToday()
        store.selectedTab = 2
        dismiss()
    }

    private func addManual(_ fi: FoodItem) {
        let item = FoodDBItem(name: fi.name, serving: "직접 등록", grams: 0,
                              kcal: fi.kcal, carbs: fi.carbs ?? 0,
                              protein: fi.protein ?? 0, fat: fi.fat ?? 0, isAI: true)
        db.addCustom(item)
        selected.append(item)
    }

    private func generate() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !generating else { return }
        generating = true
        Task { @MainActor in
            defer { generating = false }
            if let item = try? await FoodGenService(apiKey: openAIKey).generate(name: q) {
                db.addCustom(item)
                selected.append(item)
            }
        }
    }
}

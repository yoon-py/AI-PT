import SwiftUI

/// 음식 사진 분석 결과 — 사진 위 음식별 라벨 + 총열량 + 탄단지 + 끼니/시간 + 저장.
struct FoodResultView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    var meal: MealType = .current
    /// 카메라에서 이미 끝낸 분석 결과 (있으면 재분석하지 않음)
    var prefilled: FoodAnalysis? = nil
    var prefillFailed: Bool = false

    @State private var items: [FoodItem] = []
    @State private var selectedMeal: MealType = .current
    @State private var loading = true
    @State private var editingItem: FoodItem?
    @State private var showAddItem = false

    // 매크로 색
    private let carbColor = Color(red: 0.58, green: 0.45, blue: 0.92)
    private let proteinColor = Color(red: 0.27, green: 0.53, blue: 0.96)
    private let fatColor = Color(red: 0.30, green: 0.80, blue: 0.74)

    // 합산
    private var totalKcal: Int { items.reduce(0) { $0 + $1.kcal } }
    private var totalCarbs: Double { items.reduce(0) { $0 + ($1.carbs ?? 0) } }
    private var totalProtein: Double { items.reduce(0) { $0 + ($1.protein ?? 0) } }
    private var totalFat: Double { items.reduce(0) { $0 + ($1.fat ?? 0) } }

    private var title: String {
        guard let first = items.first else { return "음식 기록" }
        return items.count > 1 ? "\(first.name) 외 \(items.count - 1)개" : first.name
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    photoSection
                    nutritionSection
                    Divider().padding(.horizontal)
                    mealTimeSection
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(dateString).font(.caption2).foregroundColor(.secondary)
                        Text(title).font(.headline.weight(.bold)).foregroundColor(Theme.ink)
                            .lineLimit(1)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { bottomButtons }
        }
        .task {
            selectedMeal = meal
            if let prefilled {
                items = prefilled.items
                loading = false
            } else if prefillFailed {
                loading = false
            } else {
                await analyze()
            }
        }
        .sheet(item: $editingItem) { item in
            FoodItemEditView(
                item: item,
                onSave: { updated in
                    if let i = items.firstIndex(where: { $0.id == updated.id }) { items[i] = updated }
                },
                onDelete: { items.removeAll { $0.id == item.id } }
            )
        }
        .sheet(isPresented: $showAddItem) {
            FoodItemEditView(item: nil, onSave: { items.append($0) })
        }
    }

    // MARK: - 사진 + 음식 라벨

    private var photoSection: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                Image(uiImage: image)
                    .resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                // 음식별 라벨 핀
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    FoodLabelPill(name: item.name) { editingItem = item }
                        .position(pillPosition(item, index: idx, in: geo.size))
                }

                if loading {
                    Color.black.opacity(0.4)
                    ProgressView().tint(.white)
                }

                // 컨트롤 오버레이
                VStack {
                    HStack {
                        Spacer()
                        circleButton("plus") { showAddItem = true }
                    }
                    Spacer()
                    HStack {
                        circleButton("trash") { dismiss() }
                        Spacer()
                        Text("1/1")
                            .font(.caption.weight(.semibold)).foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.black.opacity(0.5), in: Capsule())
                    }
                }
                .padding(12)
            }
        }
        .frame(height: 300)
    }

    private func circleButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold)).foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(.black.opacity(0.5), in: Circle())
        }
    }

    private func pillPosition(_ item: FoodItem, index: Int, in size: CGSize) -> CGPoint {
        if let x = item.x, let y = item.y {
            return CGPoint(x: size.width * min(max(x, 0.12), 0.88),
                           y: size.height * min(max(y, 0.12), 0.85))
        }
        // 위치 정보 없으면 격자로 분산 배치
        let col = index % 2
        let rowI = index / 2
        let x = items.count == 1 ? 0.5 : (0.30 + Double(col) * 0.40)
        let y = 0.28 + Double(rowI) * 0.20
        return CGPoint(x: size.width * x, y: size.height * min(y, 0.82))
    }

    // MARK: - 영양 요약

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("총 열량").font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(totalKcal, format: .number)
                        .font(.system(size: 30, weight: .black)).foregroundColor(Theme.ink)
                    Text("kcal").font(.subheadline.weight(.bold)).foregroundColor(.secondary)
                }
            }

            HStack(spacing: 16) {
                macroStat("탄", totalCarbs, carbColor)
                macroStat("단", totalProtein, proteinColor)
                macroStat("지", totalFat, fatColor)
                Spacer()
            }

            macroBar
        }
        .padding()
    }

    private func macroStat(_ label: String, _ grams: Double, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text("\(label) \(fmt(grams))g")
                .font(.subheadline.weight(.semibold)).foregroundColor(Theme.ink)
        }
    }

    private var macroBar: some View {
        let c = totalCarbs * 4, p = totalProtein * 4, f = totalFat * 9
        let sum = max(c + p + f, 1)
        return GeometryReader { geo in
            HStack(spacing: 3) {
                macroSegment(geo.size.width, c / sum, carbColor)
                macroSegment(geo.size.width, p / sum, proteinColor)
                macroSegment(geo.size.width, f / sum, fatColor)
            }
        }
        .frame(height: 26)
    }

    private func macroSegment(_ total: CGFloat, _ frac: Double, _ color: Color) -> some View {
        let width = max(0, total * CGFloat(frac) - 3)
        return Text(frac >= 0.08 ? "\(Int((frac * 100).rounded()))%" : "")
            .font(.caption2.weight(.bold)).foregroundColor(.white)
            .frame(width: width, height: 26)
            .background(color, in: RoundedRectangle(cornerRadius: 7))
    }

    // MARK: - 끼니 + 시간

    private var mealTimeSection: some View {
        HStack {
            Menu {
                ForEach(MealType.ordered) { m in
                    Button { selectedMeal = m } label: {
                        Label(m.rawValue, systemImage: m.icon)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedMeal.rawValue).font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
                    Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12))
            }
            Spacer()
            Text(timeString).font(.subheadline).foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - 하단 버튼

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button { showAddItem = true } label: {
                Text("음식 추가")
                    .font(.headline.weight(.bold)).foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: Theme.radius))
            }
            Button { save() } label: {
                Text("수정 완료")
                    .font(.headline.weight(.bold)).foregroundColor(Theme.onAccent)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(canSave ? Theme.accent : Color(.systemGray3),
                               in: RoundedRectangle(cornerRadius: Theme.radius))
            }
            .disabled(!canSave)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - 로직

    private var canSave: Bool { totalKcal > 0 }

    private var dateString: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "M월 d일"
        return f.string(from: Date())
    }
    private var timeString: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "a h:mm"
        return f.string(from: Date())
    }
    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    private func analyze() async {
        loading = true
        let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            ?? Secrets.openAIAPIKey
        if let result = try? await FoodVisionService(apiKey: key).analyze(image: image) {
            items = result.items
        }
        loading = false
    }

    private func save() {
        let food = FoodLog(
            date: Date(),
            name: title,
            kcal: totalKcal,
            carbs: totalCarbs > 0 ? totalCarbs : nil,
            protein: totalProtein > 0 ? totalProtein : nil,
            fat: totalFat > 0 ? totalFat : nil,
            meal: selectedMeal,
            imageFileName: FoodImageStore.save(image)
        )
        store.logFood(food)
        store.resetDietDateToToday()
        store.selectedTab = 2
        dismiss()
    }
}

/// 사진 위 음식 라벨 핀
struct FoodLabelPill: View {
    let name: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(name).font(.caption.weight(.semibold))
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(.black.opacity(0.58), in: Capsule())
        }
    }
}

import SwiftUI

/// 식단 탭 — 날짜별 칼로리 링(목표 기반) + 매크로 + AI 식단 코치 + 끼니별 기록.
struct DietView: View {
    @EnvironmentObject private var store: AppStore

    // 음식 추가 플로우
    @State private var showChooser = false
    @State private var showCamera = false
    @State private var showSearch = false
    @State private var pendingResult: CapturedFoodImage?
    @State private var resultItem: CapturedFoodImage?
    @State private var addMeal: MealType = .current

    // AI 식단 코치
    @State private var coaching: String?
    @State private var coachLoading = false
    @State private var coachError = false

    private var date: Date { store.dietDate }

    private var openAIKey: String {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            ?? Secrets.openAIAPIKey
    }

    var body: some View {
        VStack(spacing: 0) {
            FixedHeader(title: "식단")
            dateNav
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    balanceCard
                    macrosCard
                    if store.isDietDateToday { coachCard }
                    mealsSection
                }
                .padding()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { store.loadSteps(for: date); store.loadActiveEnergy(for: date) }
        .onChange(of: store.dietDate) { _ in
            store.loadSteps(for: store.dietDate)
            store.loadActiveEnergy(for: store.dietDate)
        }
        .overlay {
            if showChooser {
                FoodAddOptions(
                    onCamera: { withAnimation { showChooser = false }; showCamera = true },
                    onSearch: { withAnimation { showChooser = false }; showSearch = true },
                    onDismiss: { withAnimation { showChooser = false } }
                )
            }
        }
        .fullScreenCover(isPresented: $showCamera, onDismiss: routeAfterCamera) {
            FoodCameraView(onResult: { image, analysis, failed in
                pendingResult = CapturedFoodImage(image: image, analysis: analysis, failed: failed)
            })
        }
        .sheet(item: $resultItem) { item in
            FoodResultView(image: item.image, meal: addMeal,
                           prefilled: item.analysis, prefillFailed: item.failed)
                .environmentObject(store)
        }
        .sheet(isPresented: $showSearch) {
            FoodSearchView(meal: addMeal).environmentObject(store)
        }
    }

    /// 카메라 종료 후 — 분석 결과가 있으면 결과 화면으로
    /// (fullScreenCover 닫힘 직후 시트를 바로 띄우면 빈 화면이 나므로 다음 런루프로 미룸)
    private func routeAfterCamera() {
        guard let r = pendingResult else { return }
        pendingResult = nil
        DispatchQueue.main.async {
            resultItem = r
        }
    }

    // MARK: - 날짜 네비게이션

    private var dateNav: some View {
        HStack {
            navButton("chevron.left") { store.shiftDietDate(by: -1) }
            Spacer()
            VStack(spacing: 2) {
                Text(dateTitle).font(.headline.weight(.bold)).foregroundColor(Theme.ink)
                if !store.isDietDateToday {
                    Button("오늘로") { store.resetDietDateToToday() }
                        .font(.caption2.weight(.bold)).foregroundColor(Theme.accent)
                }
            }
            Spacer()
            navButton("chevron.right", disabled: !store.canGoNextDietDate) { store.shiftDietDate(by: 1) }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func navButton(_ icon: String, disabled: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundColor(disabled ? Color.secondary.opacity(0.35) : Theme.ink)
                .frame(width: 40, height: 40)
                .background(Theme.card, in: Circle())
        }
        .disabled(disabled)
    }

    private var dateTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "오늘" }
        if cal.isDateInYesterday(date) { return "어제" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: date)
    }

    // MARK: - 칼로리 수지 카드 (목표 기반 색·코멘트)

    private var balanceCard: some View {
        let intake = store.intakeKcal(on: date)
        let burn = store.burnKcal(on: date)
        let net = store.netKcal(on: date)
        let workout = store.workoutKcal(on: date)
        let walking = store.walkingKcal(on: date)
        let active = store.activeBurn(on: date)
        let usesHealth = store.usesHealthEnergy(on: date)
        let verdict = store.dietVerdict(on: date)
        return VStack(spacing: 16) {
            HStack {
                Text("오늘의 칼로리 수지").font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
                Spacer()
                GoalChip(goal: store.dietGoal)
            }

            HStack(alignment: .firstTextBaseline) {
                Text("수지").font(.subheadline.weight(.bold)).foregroundColor(.secondary)
                Spacer()
                Text("\(signedString(net)) kcal").font(.title3.weight(.black)).foregroundColor(verdict.tint)
            }

            CalorieBalanceBar(intake: intake, burn: burn, tint: verdict.tint)

            Text(verdict.title)
                .font(.subheadline.weight(.bold)).foregroundColor(verdict.tint)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verdict.detail)
                .font(.caption).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(spacing: 10) {
                breakdown("기초대사", "\(store.bmrKcal)")
                if usesHealth {
                    breakdown("활동", "\(active)")
                } else {
                    breakdown("운동", "\(workout)")
                    breakdown("걷기", "\(walking)")
                }
                breakdown("섭취", "\(intake)")
                breakdown("수지", signedString(net))
            }

            if usesHealth {
                Label("Apple 건강 활동 \(active)kcal 반영 · 더 정확해요",
                      systemImage: "heart.fill")
                    .font(.caption2.weight(.medium)).foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if active > 0 {
                Label(activeBurnNote(workout: workout, walking: walking),
                      systemImage: "figure.run")
                    .font(.caption2.weight(.medium)).foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .card()
    }

    private func signedString(_ v: Int) -> String { v > 0 ? "+\(v)" : "\(v)" }


    private func activeBurnNote(workout: Int, walking: Int) -> String {
        if workout > 0 && walking > 0 {
            return "운동 \(workout) + 걷기 \(walking)kcal를 더 썼어요. 그만큼 여유가 생겼어요!"
        } else if workout > 0 {
            return "오늘 운동으로 \(workout)kcal를 더 썼어요. 그만큼 여유가 생겼어요!"
        } else {
            return "걷기로 \(walking)kcal를 더 썼어요. 그만큼 여유가 생겼어요!"
        }
    }

    private func breakdown(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 영양소 (탄단지)

    private var macrosCard: some View {
        let m = store.macros(on: date)
        return VStack(alignment: .leading, spacing: 14) {
            Text("영양소").font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
            HStack(spacing: 10) {
                MacroTile(label: "탄수화물", grams: m.carbs)
                MacroTile(label: "단백질", grams: m.protein, highlight: true)
                MacroTile(label: "지방", grams: m.fat)
            }
            ProteinBar(grams: m.protein, target: store.proteinTarget)
        }
        .card()
    }

    // MARK: - AI 식단 코치

    private var coachCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundColor(Theme.accent)
                Text("AI 식단 코치").font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
            }

            if coachLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("코치가 오늘 식단을 살펴보고 있어요…")
                        .font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            } else if let coaching {
                Text(coaching)
                    .font(.subheadline).foregroundColor(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button { fetchCoaching() } label: {
                    Label("다시 받기", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.bold)).foregroundColor(Theme.accent)
                }
            } else if coachError {
                Text("코칭을 불러오지 못했어요. 다시 시도해 주세요.")
                    .font(.caption).foregroundColor(.secondary)
                Button { fetchCoaching() } label: {
                    Label("다시 시도", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.bold)).foregroundColor(Theme.accent)
                }
            } else {
                Text("오늘 먹은 것과 목표를 보고 무엇을 더 먹으면 좋을지 코칭해드려요.")
                    .font(.caption).foregroundColor(.secondary)
                Button { fetchCoaching() } label: {
                    Text("오늘 식단 코칭 받기")
                        .font(.subheadline.weight(.bold)).foregroundColor(Theme.onAccent)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func fetchCoaching() {
        coachLoading = true
        coachError = false
        let m = store.macros(on: date)
        let input = DietCoachInput(
            profile: store.inBody?.coachProfileSummary,
            goal: store.dietGoal.rawValue,
            intake: store.intakeKcal(on: date),
            burn: store.burnKcal(on: date),
            net: store.netKcal(on: date),
            proteinG: Int(m.protein),
            proteinTarget: store.proteinTarget,
            foods: store.foods(on: date).map { $0.name }
        )
        let service = DietCoachService(apiKey: openAIKey)
        Task { @MainActor in
            do {
                coaching = try await service.coach(input)
            } catch {
                coachError = true
            }
            coachLoading = false
        }
    }

    // MARK: - 끼니별 기록

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(MealType.ordered) { meal in
                mealCard(meal)
            }
        }
    }

    private func mealCard(_ meal: MealType) -> some View {
        let foods = store.foods(on: date, meal: meal)
        let kcal = foods.reduce(0) { $0 + $1.kcal }
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: meal.icon)
                    .foregroundColor(Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                Text(meal.rawValue).font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
                if kcal > 0 {
                    Text("\(kcal) kcal").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    addMeal = meal
                    withAnimation { showChooser = true }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3).foregroundColor(Theme.accent)
                }
            }
            .padding(.vertical, 12).padding(.horizontal, 14)

            if !foods.isEmpty {
                Divider().padding(.leading, 14)
                ForEach(foods) { food in
                    foodRow(food)
                }
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func foodRow(_ food: FoodLog) -> some View {
        HStack(spacing: 12) {
            if let img = FoodImageStore.load(food.imageFileName) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "fork.knife")
                    .foregroundColor(Theme.accent)
                    .frame(width: 42, height: 42)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name).font(.subheadline.weight(.medium)).foregroundColor(Theme.ink)
                Text(time(food.date)).font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            Text("\(food.kcal) kcal").font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) { store.deleteFood(food.id) } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    private func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
        return f.string(from: date)
    }
}

import SwiftUI

/// 홈 — "오늘 나 잘하고 있나?" 한눈에. 통합 점수 + 에너지 + 식단/운동 카드.
struct HomeDashboardView: View {
    @EnvironmentObject private var store: AppStore

    private enum CardLayout {
        static let analysisContentHeight: CGFloat = 134
        static let workoutContentHeight: CGFloat = 132
        static let dietContentHeight: CGFloat = 166
    }

    // 음식 추가 플로우
    @State private var showChooser = false
    @State private var showCamera = false
    @State private var showSearch = false
    @State private var pendingResult: CapturedFoodImage?
    @State private var resultItem: CapturedFoodImage?
    @State private var addMeal: MealType = .current
    @State private var showCoach = false

    private let carbColor = Color(red: 0.58, green: 0.45, blue: 0.92)
    private let proteinColor = Color(red: 0.27, green: 0.53, blue: 0.96)
    private let fatColor = Color(red: 0.30, green: 0.80, blue: 0.74)

    var body: some View {
        ZStack(alignment: .top) {
            Theme.bg.ignoresSafeArea()
            Theme.accentSoft
                .frame(height: 340)
                .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(spacing: 0) {
                    topBand
                    VStack(spacing: 20) {
                        analysisCard.padding(.top, -50)   // 요일 스트립에 반쯤 걸침 (카드 중간까지 초록)
                        workoutCard
                        dietCard
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 28)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottomTrailing) { coachFAB }
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
        .fullScreenCover(isPresented: $showCoach) {
            AICoachView().environmentObject(store)
        }
        .fullScreenCover(isPresented: $store.showCelebration) {
            CelebrationView().environmentObject(store)
        }
    }

    private func routeAfterCamera() {
        guard let r = pendingResult else { return }
        pendingResult = nil
        DispatchQueue.main.async { resultItem = r }
    }

    // MARK: - AI 코치 FAB

    private var coachFAB: some View {
        Button { showCoach = true } label: {
            Image("CatCoach")
                .resizable().scaledToFit()
                .frame(width: 46, height: 46)
                .padding(9)
                .background(
                    Circle().fill(Theme.card)
                        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
                )
                .overlay(Circle().stroke(Theme.accent.opacity(0.25), lineWidth: 1.5))
        }
        .padding(.trailing, 20).padding(.bottom, 20)
    }

    // MARK: - 헤더 (플로우 + 연속 + 요일 스트립)

    private var streakBadge: some View {
        let streak = store.dailyStreak
        return HStack(spacing: 4) {
            Text("🔥").font(.subheadline)
                .grayscale(streak == 0 ? 1 : 0).opacity(streak == 0 ? 0.4 : 1)
            if streak > 0 {
                Text("\(streak)").font(.subheadline.weight(.heavy)).foregroundColor(Theme.accent)
            }
        }
        .padding(.horizontal, streak > 0 ? 12 : 9).padding(.vertical, 6)
        .background(streak > 0 ? Theme.card : Theme.hairline, in: Capsule())
    }

    /// 상단 밴드 — 플로우 + 연속 + 요일 스트립 (분석 카드가 여기에 반쯤 걸침)
    private var topBand: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Text("Flow").font(.system(size: 29, weight: .bold)).foregroundColor(Theme.ink)
                Spacer()
                streakBadge
            }
            weekStrip
        }
        .padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 80)
        .frame(maxWidth: .infinity)
    }

    private var weekStrip: some View {
        let cal = store.weekCalendarForView
        let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let labels = ["월", "화", "수", "목", "금", "토", "일"]
        let workoutDays = Set(store.workoutLogs.map { cal.startOfDay(for: $0.date) })
        let todayStart = cal.startOfDay(for: Date())
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                let day = cal.date(byAdding: .day, value: i, to: start) ?? start
                let dayStart = cal.startOfDay(for: day)
                let completed = workoutDays.contains(dayStart)
                let isToday = dayStart == todayStart
                let isFuture = dayStart > todayStart
                VStack(spacing: 8) {
                    Text(labels[i]).font(.caption.weight(.medium))
                        .foregroundColor(isToday ? .white : (completed ? Theme.ink.opacity(0.75) : .secondary))
                    ZStack {
                        if completed {
                            Circle().fill(Theme.accent).frame(width: 36, height: 36)
                            Text("\(cal.component(.day, from: day))").font(.subheadline.weight(.bold)).foregroundColor(.white)
                        } else if isToday {
                            Circle().fill(.white).frame(width: 36, height: 36)
                            Text("\(cal.component(.day, from: day))").font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
                        } else {
                            Circle().fill(Theme.hairline).frame(width: 36, height: 36)
                            Text("\(cal.component(.day, from: day))").font(.subheadline.weight(.bold))
                                .foregroundColor(isFuture ? Color.secondary.opacity(0.4) : Theme.ink.opacity(0.6))
                        }
                    }
                    .frame(width: 38, height: 38)
                }
                .padding(.vertical, 8).padding(.horizontal, 6)
                .background(isToday ? Color(white: 0.45) : Color.clear, in: RoundedRectangle(cornerRadius: 20))
                .frame(maxWidth: .infinity)
            }
        }
    }


    // MARK: - 운동 카드

    private var workoutCard: some View {
        let recs = store.recommendations()
        let weight = store.inBody?.weight ?? 65
        let kcal = recs.reduce(0) { $0 + $1.exercise.estimatedRoutineKcal(perSetGoal: $1.goal, weightKg: weight) }
        let minutes = max(5, recs.count * 4)
        return VStack(spacing: 16) {
            HStack {
                summaryStat("clock", "\(minutes)분", "운동 시간")
                summaryDivider
                summaryStat("dumbbell.fill", "\(recs.count)개", "운동")
                summaryDivider
                summaryStat("flame.fill", "\(kcal)", "kcal")
            }
            Button { store.openRoutinePreview() } label: {
                Text("운동 시작")
            }
            .buttonStyle(EnergyButtonStyle())
            .disabled(recs.isEmpty)
        }
        .frame(height: CardLayout.workoutContentHeight)
        .card()
    }

    // MARK: - 식단 카드 (끼니 썸네일)

    private var dietCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(store.todayIntakeKcal, format: .number)
                    .font(.title3.weight(.black)).foregroundColor(Theme.ink)
                Text("kcal").font(.subheadline.weight(.bold)).foregroundColor(.secondary)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(MealType.ordered) { meal in mealSlot(meal) }
            }
        }
        .frame(height: CardLayout.dietContentHeight, alignment: .top)
        .card()
    }

    private func mealSlot(_ meal: MealType) -> some View {
        let kcal = store.mealKcal(meal, on: Date())
        let imageName = store.mealImageName(meal, on: Date())
        return Button {
            addMeal = meal
            withAnimation { showChooser = true }
        } label: {
            VStack(spacing: 6) {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if let img = FoodImageStore.load(imageName) {
                            Image(uiImage: img).resizable().scaledToFill()
                        } else {
                            Image(systemName: kcal > 0 ? meal.icon : "plus")
                                .font(.subheadline)
                                .foregroundColor(kcal > 0 ? Theme.accent : .secondary)
                        }
                    }
                    .background(Theme.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(meal.rawValue).font(.caption2.weight(.medium)).foregroundColor(Theme.ink)
                Text(kcal > 0 ? "\(kcal.formatted()) kcal" : "추가")
                    .font(.caption2).foregroundColor(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 카드 디스패치 (드래그 순서)

    @ViewBuilder
    private func cardFor(_ card: HomeCard) -> some View {
        switch card {
        case .analysis: analysisCard
        case .workout:  workoutCard
        }
    }

    // MARK: - 분석 카드 (AI 오늘 행동 조언) — 요일 스트립에 반쯤 걸침

    private var analysisCard: some View {
        let verdict = store.dietVerdict(on: Date())
        return HStack(spacing: 18) {
            calorieGauge(intake: store.todayIntakeKcal, burn: store.todayBurnKcal, tint: verdict.tint)

            VStack(alignment: .center, spacing: 10) {
                Text(store.homeCalorieAdviceTitle)
                    .font(.title3.weight(.black))
                    .foregroundColor(verdict.tint)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text(store.homeCalorieAdviceDetail)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Theme.subtle)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: CardLayout.analysisContentHeight,
            maxHeight: CardLayout.analysisContentHeight,
            alignment: .leading
        )
        .card()
        .contentShape(Rectangle())
        .onTapGesture { store.selectedTab = 3 }
    }

    private func calorieGauge(intake: Int, burn: Int, tint: Color) -> some View {
        let progress = burn > 0 ? min(max(Double(intake) / Double(burn), 0), 1) : 0
        return ZStack {
            Circle()
                .stroke(Theme.hairline, style: StrokeStyle(lineWidth: 13, lineCap: .round))

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(tint, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text("섭취")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Theme.subtle)

                Text(intake.formatted())
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text("/ \(burn.formatted()) 소비")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.subtle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 12)
        }
        .frame(width: 134, height: 134)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("섭취 \(intake)킬로칼로리, 소비 \(burn)킬로칼로리, 수지 \(signed(intake - burn))킬로칼로리")
    }

    private func summaryStat(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundColor(Theme.accent)
            Text(value).font(.headline.weight(.black)).foregroundColor(Theme.ink)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDivider: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: 40)
    }

    private func signed(_ v: Int) -> String { v > 0 ? "+\(v)" : "\(v)" }
}

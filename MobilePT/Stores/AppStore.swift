import SwiftUI

/// 화면 이동 경로
enum Route: Hashable {
    case inBodyInput          // 인바디 입력/업데이트
    case analysis             // 체성분 분석 상세
    case exerciseList         // 운동 목록/선택
    case routinePreview       // 추천 운동 미리보기 (루틴 목록)
    case guide(ExerciseType, Int)     // 운동 시작 전 가이드 (운동, 목표)
    case rest(ExerciseType, Int)      // 운동 사이 휴식 (다음 운동, 목표)
    case session(ExerciseType, Int)   // 운동, 목표(횟수/초)
    case results(ExerciseType, Int)   // 운동, 완료 횟수
    case routineComplete(Int)         // 루틴 완료 (완료한 운동 수)
}

/// 화면 모드
enum Appearance: String, CaseIterable {
    case system, light, dark
}

/// 홈 탭 카드 (드래그로 순서 변경)
enum HomeCard: String, CaseIterable, Identifiable {
    case analysis, workout
    var id: String { rawValue }
}

/// 앱 전역 상태 — 인바디 데이터·운동 기록을 영구 저장하고 내비게이션을 관리
@MainActor
final class AppStore: ObservableObject {
    @Published var path: [Route] = []
    /// 하단 탭 선택 (0:운동, 1:분석, 2:기록, 3:프로필)
    @Published var selectedTab: Int = 0
    @Published private(set) var inBody: InBodyResult?
    @Published private(set) var inBodyHistory: [InBodyResult] = []
    @Published private(set) var workoutLogs: [WorkoutLog] = []
    @Published private(set) var foodLogs: [FoodLog] = []
    @Published private(set) var userProfile: UserProfile?
    /// 온보딩(대화형 질문 → 인바디 → 플랜 생성)을 끝냈는지
    @Published private(set) var didCompleteOnboarding = false

    /// 식단 탭에서 보고 있는 날짜 (날짜 네비게이션)
    @Published var dietDate: Date = Calendar.current.startOfDay(for: Date())

    /// 홈 카드 순서 (드래그로 변경, 영구 저장)
    @Published var homeCardOrder: [HomeCard] = HomeCard.allCases {
        didSet { defaults.set(homeCardOrder.map(\.rawValue), forKey: homeOrderKey) }
    }
    private let homeOrderKey = "home.cardOrder"

    func moveHomeCards(from source: IndexSet, to dest: Int) {
        homeCardOrder.move(fromOffsets: source, toOffset: dest)
    }

    /// 오늘의 AI 행동 조언 (하루 1회 LLM 생성 후 캐시)
    @Published private(set) var dailyAdvice: String?
    private let adviceTextKey = "daily.advice.text.v2"
    private let adviceDateKey = "daily.advice.date.v2"

    /// 날짜별(자정 기준) 만보기 측정값 — 걸음수 + 실측 거리
    @Published private(set) var activityByDay: [Date: WalkData] = [:]
    /// 하루 목표 걸음수
    let stepGoal = 10000
    private let pedometer = PedometerService()

    /// 날짜별 Apple 건강 액티브 에너지(kcal). 측정값 있으면 소비 계산에 우선 사용.
    @Published private(set) var activeEnergyByDay: [Date: Int] = [:]
    private let health = HealthKitService.shared

    /// 오늘 운동 완료 축하 화면 표시 트리거 (하루 1회)
    @Published var showCelebration = false

    /// 화면 모드 (라이트/다크/시스템)
    @Published var appearance: Appearance = .light {
        didSet { defaults.set(appearance.rawValue, forKey: appearanceKey) }
    }

    /// SwiftUI preferredColorScheme 값
    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// 현재 진행 중인 루틴(추천 운동 순차 진행)
    @Published private(set) var routine: [ExerciseRecommendation] = []
    @Published private(set) var routineIndex = 0
    var inRoutine: Bool { !routine.isEmpty }

    private let defaults = UserDefaults.standard
    private let inBodyKey = "inBody.current"
    private let historyKey = "inBody.history"
    private let logsKey = "workout.logs"
    private let foodKey = "food.logs"
    private let profileKey = "user.profile"
    private let onboardingKey = "onboarding.completed"
    private let appearanceKey = "appearance"
    private let celebrationKey = "celebration.lastDay"

    init() { load() }

    // MARK: - 파생 상태

    var hasInBody: Bool { inBody != nil }

    /// 마지막 측정 후 경과일
    var daysSinceLastInBody: Int? {
        guard let date = inBody?.date else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day
    }

    /// 주간 업데이트 권장 여부 (7일 이상 경과)
    var inBodyUpdateDue: Bool {
        guard let days = daysSinceLastInBody else { return true }
        return days >= 7
    }

    func recommendations() -> [ExerciseRecommendation] {
        inBody?.recommendations() ?? []
    }

    var recentLogs: [WorkoutLog] { Array(workoutLogs.prefix(5)) }

    /// 최근 7일 운동 횟수
    var workoutsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return workoutLogs.filter { $0.date >= weekAgo }.count
    }

    // MARK: - 주간 모멘텀 (스트릭) — 월요일 시작, 주간 목표 회수 기준

    /// 사용자가 정한 주간 목표 횟수 (온보딩, 기본 3회)
    var weeklyGoalTarget: Int { userProfile?.weeklyGoal ?? 3 }

    /// 월요일 시작 달력
    private var weekCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2   // 월요일
        return c
    }

    /// 뷰(주간 스트립)에서 쓰는 월요일 시작 달력
    var weekCalendarForView: Calendar { weekCalendar }

    /// 특정 주(offset주 전)의 운동한 "날" 수 (하루 여러 번 해도 1)
    func completedDays(weeksAgo offset: Int) -> Int {
        let cal = weekCalendar
        guard let thisStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start,
              let weekStart = cal.date(byAdding: .weekOfYear, value: -offset, to: thisStart),
              let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) else { return 0 }
        let days = Set(workoutLogs.map { cal.startOfDay(for: $0.date) }
            .filter { $0 >= weekStart && $0 < weekEnd })
        return days.count
    }

    /// 이번 주 완료 일수
    var thisWeekCompleted: Int { completedDays(weeksAgo: 0) }

    /// 연속 운동 일수 — 오늘 했으면 오늘 포함, 오늘 아직이면 어제까지 기준. 둘 다 없으면 0.
    var dailyStreak: Int {
        let cal = Calendar.current
        let days = Set(workoutLogs.map { cal.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }
        let today = cal.startOfDay(for: Date())
        var cursor: Date
        if days.contains(today) {
            cursor = today
        } else if let yesterday = cal.date(byAdding: .day, value: -1, to: today), days.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// 주간 목표를 채운 주가 연속 몇 주인지 (이번 주는 달성 시에만 포함, 미달 시 진행 중으로 보고 안 깸)
    var weeklyStreak: Int {
        let goal = weeklyGoalTarget
        var streak = 0
        if completedDays(weeksAgo: 0) >= goal { streak += 1 }
        var offset = 1
        while completedDays(weeksAgo: offset) >= goal {
            streak += 1
            offset += 1
            if offset > 520 { break }   // 안전장치 (최대 10년)
        }
        return streak
    }

    var totalWorkouts: Int { workoutLogs.count }

    /// 목표 달성한 세션 수
    var goalReachedCount: Int { workoutLogs.filter { $0.goalReached }.count }

    /// 목표 달성률(0~1)
    var goalReachedRate: Double {
        totalWorkouts > 0 ? Double(goalReachedCount) / Double(totalWorkouts) : 0
    }

    /// 인바디 예측 (현재 인바디 + 이번 주 운동량 + 목표 기반)
    func prediction() -> InBodyPrediction? {
        guard let inBody else { return nil }
        return .make(from: inBody, workoutsThisWeek: workoutsThisWeek, goal: dietGoal)
    }

    // MARK: - 변경

    /// 인바디 측정값 저장 (히스토리에 누적 → 주간 추이 추적)
    func saveInBody(_ result: InBodyResult) {
        inBody = result
        inBodyHistory.append(result)
        persist()
    }

    /// 온보딩 답변 저장
    func saveOnboarding(_ profile: UserProfile) {
        userProfile = profile
        persist()
    }

    /// 온보딩 완료 처리 (플랜 카드 → 시작하기)
    func completeOnboarding() {
        didCompleteOnboarding = true
        persist()
    }

    func logWorkout(exercise: ExerciseType, count: Int, goal: Int) {
        let log = WorkoutLog(date: Date(), exercise: exercise, count: count, goal: goal)
        workoutLogs.insert(log, at: 0)
        persist()
        // Apple 건강에 운동 기록 + 액티브 에너지 갱신
        let weight = inBody?.weight ?? 65
        health.saveWorkout(kcal: exercise.burnedKcal(count: count, weightKg: weight),
                           durationSec: exercise.activeSeconds(count: count))
        loadActiveEnergy(for: Date())
    }

    // MARK: - 식단 / 칼로리 수지

    func logFood(_ food: FoodLog) {
        foodLogs.insert(food, at: 0)
        persist()
    }

    func deleteFood(_ id: UUID) {
        if let f = foodLogs.first(where: { $0.id == id }) {
            FoodImageStore.delete(f.imageFileName)
        }
        foodLogs.removeAll { $0.id == id }
        persist()
    }

    /// 오늘 먹은 음식
    var todayFoods: [FoodLog] {
        let cal = Calendar.current
        return foodLogs.filter { cal.isDateInToday($0.date) }
    }

    /// 오늘 섭취 칼로리
    var todayIntakeKcal: Int { todayFoods.reduce(0) { $0 + $1.kcal } }

    /// 기초대사량(일일)
    var bmrKcal: Int { Int(inBody?.bmr ?? 0) }

    /// 오늘 운동으로 태운 칼로리 (MET 기반 추정)
    var todayWorkoutKcal: Int { workoutKcal(on: Date()) }

    /// 오늘 소비 칼로리 = 기초대사량 + 활동(운동+걷기 또는 건강 측정값)
    var todayBurnKcal: Int { burnKcal(on: Date()) }

    /// 오늘 칼로리 수지 (섭취 - 소비)
    var todayNetKcal: Int { todayIntakeKcal - todayBurnKcal }

    // MARK: - 만보기 / 걷기 칼로리

    /// 특정 날짜 측정값 (없으면 0)
    func activity(on date: Date) -> WalkData {
        activityByDay[Calendar.current.startOfDay(for: date)] ?? .zero
    }

    /// 특정 날짜 걸음수
    func steps(on date: Date) -> Int { activity(on: date).steps }

    /// 특정 날짜 이동 거리(km) — 실측 없으면 키 기반 보폭으로 추정
    func distanceKm(on date: Date) -> Double {
        let a = activity(on: date)
        if let d = a.distanceMeters, d > 0 { return d / 1000 }
        let strideM = (inBody?.height ?? 170) * 0.415 / 100   // 보폭 ≈ 키 × 0.415
        return Double(a.steps) * strideM / 1000
    }

    var todaySteps: Int { steps(on: Date()) }

    /// 걷기 칼로리 — 실측 거리 × 체중 기반 순(net) 보행 에너지(0.5 kcal/kg/km).
    /// 기초대사량은 하루치를 별도 계산하므로 이중계산을 피하려 추가분(net)만 더한다.
    func walkingKcal(on date: Date) -> Int {
        let weight = inBody?.weight ?? 65
        return Int((weight * distanceKm(on: date) * 0.5).rounded())
    }

    /// 만보기 시작 — 오늘 걸음/거리 실시간 추적
    func startStepTracking() {
        guard PedometerService.isAvailable else { return }
        pedometer.startLiveUpdates { [weak self] walk in
            self?.setActivity(walk, for: Date())
        }
    }

    /// 특정 날짜 측정값 비동기 조회 후 반영 (날짜 네비게이션용)
    func loadSteps(for date: Date) {
        guard PedometerService.isAvailable else { return }
        Task { @MainActor in
            let walk = await pedometer.walk(on: date)
            setActivity(walk, for: date)
        }
    }

    private func setActivity(_ walk: WalkData, for date: Date) {
        activityByDay[Calendar.current.startOfDay(for: date)] = walk
    }

    // MARK: - Apple 건강 (HealthKit)

    /// 권한 요청 + 오늘 액티브 에너지 로드 (앱 시작 시)
    func startHealthSync() {
        guard health.isAvailable else { return }
        Task { @MainActor in
            guard await health.requestAuthorization() else { return }
            await refreshActiveEnergy(for: Date())
        }
    }

    /// 특정 날짜 액티브 에너지 로드 (날짜 네비게이션용)
    func loadActiveEnergy(for date: Date) {
        guard health.isAvailable else { return }
        Task { @MainActor in await refreshActiveEnergy(for: date) }
    }

    @MainActor
    private func refreshActiveEnergy(for date: Date) async {
        if let kcal = await health.activeEnergy(on: date) {
            activeEnergyByDay[Calendar.current.startOfDay(for: date)] = kcal
        }
    }

    // MARK: - 날짜별 식단 조회 (식단 탭 날짜 네비게이션)

    /// 특정 날짜에 먹은 음식 (최신순)
    func foods(on date: Date) -> [FoodLog] {
        let cal = Calendar.current
        return foodLogs.filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    /// 특정 날짜·끼니의 음식
    func foods(on date: Date, meal: MealType) -> [FoodLog] {
        foods(on: date).filter { $0.meal == meal }
    }

    func intakeKcal(on date: Date) -> Int { foods(on: date).reduce(0) { $0 + $1.kcal } }

    /// 특정 날짜의 탄단지 합계(g)
    func macros(on date: Date) -> (carbs: Double, protein: Double, fat: Double) {
        foods(on: date).reduce(into: (0.0, 0.0, 0.0)) { acc, f in
            acc.0 += f.carbs ?? 0
            acc.1 += f.protein ?? 0
            acc.2 += f.fat ?? 0
        }
    }

    /// 탄단지 칼로리 비율(%) — 합이 0이면 모두 0
    func macroPercents(on date: Date) -> (carbs: Int, protein: Int, fat: Int) {
        let m = macros(on: date)
        let c = m.carbs * 4, p = m.protein * 4, f = m.fat * 9
        let sum = c + p + f
        guard sum > 0 else { return (0, 0, 0) }
        return (Int((c / sum * 100).rounded()),
                Int((p / sum * 100).rounded()),
                Int((f / sum * 100).rounded()))
    }

    /// 특정 끼니 섭취 칼로리
    func mealKcal(_ meal: MealType, on date: Date) -> Int {
        foods(on: date, meal: meal).reduce(0) { $0 + $1.kcal }
    }

    /// 특정 끼니 대표 썸네일 파일명 (사진 있는 가장 최근 기록)
    func mealImageName(_ meal: MealType, on date: Date) -> String? {
        foods(on: date, meal: meal).first { $0.imageFileName != nil }?.imageFileName
    }

    /// 특정 날짜 운동 소모 칼로리 (MET 기반: (MET−1)×체중×시간)
    func workoutKcal(on date: Date) -> Int {
        let cal = Calendar.current
        let weight = inBody?.weight ?? 65
        return workoutLogs
            .filter { cal.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.exercise.burnedKcal(count: $1.count, weightKg: weight) }
    }

    /// 특정 날짜 활동 소비 — Apple 건강 측정값(액티브 에너지) 우선, 없으면 운동(MET)+걷기 추정
    func activeBurn(on date: Date) -> Int {
        if let hk = activeEnergyByDay[Calendar.current.startOfDay(for: date)], hk > 0 {
            return hk
        }
        return workoutKcal(on: date) + walkingKcal(on: date)
    }

    /// 해당 날짜 소비가 건강 앱 측정값을 쓰는지
    func usesHealthEnergy(on date: Date) -> Bool {
        (activeEnergyByDay[Calendar.current.startOfDay(for: date)] ?? 0) > 0
    }

    /// 특정 날짜 소비 칼로리 = 기초대사량 + 활동
    func burnKcal(on date: Date) -> Int { bmrKcal + activeBurn(on: date) }

    /// 특정 날짜 칼로리 수지 (섭취 - 소비)
    func netKcal(on date: Date) -> Int { intakeKcal(on: date) - burnKcal(on: date) }

    // MARK: - 날짜 네비게이션

    var isDietDateToday: Bool { Calendar.current.isDateInToday(dietDate) }

    /// 미래로는 못 가도록 (오늘이 상한)
    var canGoNextDietDate: Bool { !isDietDateToday }

    func shiftDietDate(by days: Int) {
        let cal = Calendar.current
        guard let d = cal.date(byAdding: .day, value: days, to: dietDate) else { return }
        let day = cal.startOfDay(for: d)
        guard day <= cal.startOfDay(for: Date()) else { return }
        dietDate = day
    }

    func resetDietDateToToday() {
        dietDate = Calendar.current.startOfDay(for: Date())
    }

    // MARK: - 목표 기반 식단 해석 (새 칼로리 지표 없이 수지를 목표로 읽음)

    /// 식단 평가 기준이 되는 사용자 목표
    var dietGoal: FitnessGoal {
        userProfile?.primaryGoal ?? inBody?.goals.first ?? .maintain
    }

    /// 특정 날짜 수지를 목표에 비춘 평가
    func dietVerdict(on date: Date) -> DietVerdict {
        DietVerdict.make(net: netKcal(on: date), goal: dietGoal)
    }

    /// 일일 단백질 권장량(g) — 체중·목표 기반 가벼운 기준선 (없으면 nil)
    var proteinTarget: Int? {
        guard let inBody else { return nil }
        return inBody.proteinTarget(for: dietGoal)
    }

    /// 균형(소비) 대비 남은 여유를 목표에 맞게 표현 (가로막대 캡션)
    func balanceCaption(on date: Date) -> String {
        let room = burnKcal(on: date) - intakeKcal(on: date)   // 양수면 적자 여유
        switch dietGoal.calorieDirection {
        case .deficit, .balance:
            return room > 0 ? "\(room)kcal 더 먹어도 돼요" : "\(-room)kcal 초과했어요"
        case .surplus:
            return room > 0 ? "근성장엔 \(room)kcal 더 먹어요" : "+\(-room)kcal 흑자 좋아요"
        }
    }

    /// 홈 첫 카드용 목표별 수지 제목. 배지 없이도 목표 기준 해석이 보이게 짧게 쓴다.
    var homeCalorieAdviceTitle: String {
        if todayIntakeKcal == 0 {
            return "아직 섭취 기록이 없어요"
        }

        let net = todayNetKcal
        switch dietGoal.calorieDirection {
        case .deficit:
            return net <= 0 ? "감량 페이스 좋아요" : "오늘은 조금 많아요"
        case .surplus:
            return net >= 0 ? "근성장 연료 충분해요" : "근성장엔 조금 부족해요"
        case .balance:
            if abs(net) <= 250 { return "균형이 잘 맞아요" }
            return net > 0 ? "섭취가 조금 많아요" : "섭취가 조금 적어요"
        }
    }

    /// 홈 첫 카드용 목표별 수지 설명.
    var homeCalorieAdviceDetail: String {
        if todayIntakeKcal == 0 {
            return "첫 끼를 기록하면 목표에 맞춰 수지를 읽어드릴게요."
        }
        return dietVerdict(on: Date()).detail
    }

    // MARK: - 오늘 통합 점수 (운동 + 식단을 한 숫자로 — 올인원 차별 지표)

    /// 0~100. 운동 40 + 수지 목표부합 30 + 단백질 20 + 걸음 10
    var todayScore: Int {
        var s = 0.0
        if didWorkoutToday { s += 40 }
        if todayIntakeKcal > 0 && dietVerdict(on: Date()).onTrack { s += 30 }
        if let t = proteinTarget, t > 0 {
            s += 20 * min(macros(on: Date()).protein / Double(t), 1)
        }
        if stepGoal > 0 {
            s += 10 * min(Double(todaySteps) / Double(stepGoal), 1)
        }
        return Int(s.rounded())
    }

    var todayScoreLabel: String {
        switch todayScore {
        case 80...:    return "완벽한 하루예요! 🔥"
        case 60..<80:  return "잘하고 있어요 💪"
        case 30..<60:  return "조금만 더 힘내요"
        case 1..<30:   return "오늘을 채워가요"
        default:       return "오늘을 시작해봐요"
        }
    }

    /// 운동↔식단 교차 넛지 (가장 중요한 것 하나)
    var todayNudge: String? {
        let prot = macros(on: Date()).protein
        if didWorkoutToday, let t = proteinTarget, t > 0, Int(prot) < t * 3 / 4 {
            return "운동했으니 단백질을 더 채우면 완벽해요"
        }
        if !didWorkoutToday {
            return "오늘 아직 운동 전이에요. 가볍게 한 세트 시작해볼까요?"
        }
        if todayIntakeKcal > 0 && !dietVerdict(on: Date()).onTrack {
            return dietGoal.calorieDirection == .surplus
                ? "근성장엔 잘 먹는 게 중요해요. 한 끼 더 채워볼까요?"
                : "오늘은 조금 더 움직이면 수지가 좋아져요"
        }
        if todaySteps < stepGoal / 2 {
            return "조금 더 걸으면 목표에 가까워져요"
        }
        return nil
    }

    // MARK: - 오늘의 AI 행동 조언 (LLM, 하루 1회 캐시)

    private var openAIKey: String {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            ?? Secrets.openAIAPIKey
    }

    /// 규칙 기반 폴백 조언 (즉시·항상)
    private var ruleBasedAdvice: String {
        todayNudge ?? "오늘도 목표를 향해 한 걸음 나아가요!"
    }

    /// LLM에 보낼 오늘 상태 요약
    private var adviceContext: String {
        let m = macros(on: Date())
        var s = "목표: \(dietGoal.rawValue). "
        s += "오늘 운동: \(didWorkoutToday ? "완료(\(todayWorkoutKcal)kcal 소모)" : "아직 안 함"). "
        s += "섭취 \(todayIntakeKcal)kcal, 소비 \(todayBurnKcal)kcal, 수지 \(todayNetKcal)kcal. "
        s += "단백질 \(Int(m.protein))g"
        if let t = proteinTarget { s += "/권장 \(t)g" }
        s += ". 걸음 \(todaySteps)."
        return s
    }

    /// 오늘 조언 갱신 — 오늘 캐시 있으면 사용, 없으면 즉시 규칙 기반 + LLM 비동기 생성
    func refreshDailyAdvice() {
        let today = Calendar.current.startOfDay(for: Date())
        if let saved = defaults.string(forKey: adviceTextKey),
           let date = defaults.object(forKey: adviceDateKey) as? Date,
           Calendar.current.isDate(date, inSameDayAs: today) {
            dailyAdvice = saved
            return
        }
        // 즉시 규칙 기반으로 채움
        if dailyAdvice == nil { dailyAdvice = ruleBasedAdvice }
        guard !openAIKey.isEmpty else { dailyAdvice = ruleBasedAdvice; return }

        let key = openAIKey
        let context = adviceContext
        let system = """
        너는 운동·식단을 함께 보는 전문 코치야. 사용자의 오늘 데이터를 보고
        오늘 상태를 짚고, 무엇을 어떻게 하면 좋은지 2~3문장으로 구체적으로 조언해.
        운동과 식단을 연결해서(예: 운동 많이 했으면 단백질 보충), 가장 중요한 행동 1~2개를 콕 집어줘.
        근거가 되는 숫자(수지·단백질 등)를 자연스럽게 곁들이면 더 좋아. 한국어, 힘차고 따뜻하게.
        이모지 1개까지. 따옴표 없이 문장만 출력.
        """
        Task { @MainActor in
            if let line = try? await CoachChatService(apiKey: key)
                .reply(system: system, history: [ChatMessage(role: .user, text: context)]) {
                let clean = line.trimmingCharacters(in: CharacterSet(charactersIn: " \n\"'"))
                if !clean.isEmpty {
                    dailyAdvice = clean
                    defaults.set(clean, forKey: adviceTextKey)
                    defaults.set(today, forKey: adviceDateKey)
                }
            }
        }
    }

    // MARK: - 루틴 (추천 운동 순차 진행)

    /// 추천 운동들을 순서대로 진행하는 루틴 시작 → 첫 운동 가이드로
    func startRoutine(_ recs: [ExerciseRecommendation]) {
        guard let first = recs.first else { return }
        routine = recs
        routineIndex = 0
        path = [.guide(first.exercise, first.goal)]
    }

    /// 휴식 화면에서 다음 운동 가이드로 진행
    func proceedToGuide(_ ex: ExerciseType, goal: Int) {
        path = [.guide(ex, goal)]
    }

    /// 현재 운동 종료 시: 기록 저장 후 다음 운동 가이드로, 마지막이면 루틴 완료 화면으로
    func completeCurrentAndAdvance(reps: Int) {
        if routineIndex < routine.count {
            let cur = routine[routineIndex]
            logWorkout(exercise: cur.exercise, count: reps, goal: cur.goal)
        }
        if routineIndex < routine.count - 1 {
            routineIndex += 1
            let next = routine[routineIndex]
            path = [.rest(next.exercise, next.goal)]   // 다음 운동 전 휴식
        } else {
            let count = routine.count
            routine = []
            routineIndex = 0
            path = [.routineComplete(count)]
        }
    }

    /// 운동 탭 홈으로 (세션/결과 종료 후)
    func goHome() {
        path = []
        selectedTab = 0
        routine = []
        routineIndex = 0
        maybeCelebrate()
    }

    /// 오늘 운동했는지
    var didWorkoutToday: Bool {
        let cal = Calendar.current
        return workoutLogs.contains { cal.isDateInToday($0.date) }
    }

    /// 오늘 처음 완료했으면(하루 1회) 축하 화면 트리거
    private func maybeCelebrate() {
        guard didWorkoutToday else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let last = (defaults.object(forKey: celebrationKey) as? Date)
            .map { Calendar.current.startOfDay(for: $0) }
        guard last != today else { return }
        defaults.set(today, forKey: celebrationKey)
        // 홈 내비게이션이 안정된 뒤 표시
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            self.showCelebration = true
        }
    }

    /// 운동 탭으로 전환 (분석 화면 등에서 "운동하러 가기")
    func goToWorkout() {
        selectedTab = 1
        path = []
    }

    /// 홈에서 운동 탭으로 이동 (탭 인덱스 1)
    func openWorkoutTab() { selectedTab = 1; path = [] }
    /// 홈에서 운동 탭 + 추천 루틴 미리보기로 딥링크
    func openRoutinePreview() { selectedTab = 1; path = [.routinePreview] }
    /// 홈에서 운동 탭 + 직접 고르기로 딥링크
    func openExerciseList() { selectedTab = 1; path = [.exerciseList] }

    // MARK: - 영속화

    private func persist() {
        let enc = JSONEncoder()
        if let inBody { defaults.set(try? enc.encode(inBody), forKey: inBodyKey) }
        defaults.set(try? enc.encode(inBodyHistory), forKey: historyKey)
        defaults.set(try? enc.encode(workoutLogs), forKey: logsKey)
        defaults.set(try? enc.encode(foodLogs), forKey: foodKey)
        if let userProfile { defaults.set(try? enc.encode(userProfile), forKey: profileKey) }
        defaults.set(didCompleteOnboarding, forKey: onboardingKey)
    }

    private func load() {
        let dec = JSONDecoder()
        if let data = defaults.data(forKey: inBodyKey) {
            inBody = try? dec.decode(InBodyResult.self, from: data)
        }
        if let data = defaults.data(forKey: historyKey),
           let h = try? dec.decode([InBodyResult].self, from: data) {
            inBodyHistory = h
        }
        if let data = defaults.data(forKey: logsKey),
           let l = try? dec.decode([WorkoutLog].self, from: data) {
            workoutLogs = l
        }
        if let data = defaults.data(forKey: foodKey),
           let f = try? dec.decode([FoodLog].self, from: data) {
            foodLogs = f
        }
        if let data = defaults.data(forKey: profileKey),
           let p = try? dec.decode(UserProfile.self, from: data) {
            userProfile = p
        }
        if let s = defaults.string(forKey: appearanceKey), let a = Appearance(rawValue: s) {
            appearance = a
        }
        if let raw = defaults.array(forKey: homeOrderKey) as? [String] {
            let cards = raw.compactMap { HomeCard(rawValue: $0) }
            if Set(cards) == Set(HomeCard.allCases) { homeCardOrder = cards }
        }
        didCompleteOnboarding = defaults.bool(forKey: onboardingKey)
        // 기존 사용자 마이그레이션: 인바디가 이미 있으면 온보딩 통과로 간주
        if !didCompleteOnboarding && inBody != nil {
            didCompleteOnboarding = true
        }
    }
}

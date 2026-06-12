import SwiftUI

/// 대화형 온보딩 — 질문(수준/목표/주간횟수/시작시점) → 인바디 입력 → 플랜 생성 → 완성 카드.
struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore

    private enum Step: Int, CaseIterable {
        case intro, level, goal, frequency, timing, inbody, generating, plan
    }

    @State private var step: Step = .intro

    // 답변
    @State private var level: ExperienceLevel?
    @State private var goal: FitnessGoal?
    @State private var weekly = 4
    @State private var timing: StartTiming?

    // 인바디 입력
    @State private var weight = ""
    @State private var height = ""
    @State private var muscle = ""
    @State private var fatMass = ""
    @State private var bmr = ""

    @State private var genProgress: Double = 0

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            switch step {
            case .intro:      introView
            case .level:      levelView
            case .goal:       goalView
            case .frequency:  frequencyView
            case .timing:     timingView
            case .inbody:     inbodyView
            case .generating: generatingView
            case .plan:       planView
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: - 0. 인트로

    private var introView: some View {
        VStack(spacing: 24) {
            Spacer()
            coachAvatar(size: 110)
            Text("안녕하세요!\n만나서 반가워요.")
                .font(.title2.weight(.heavy))
                .foregroundColor(Theme.ink)
                .multilineTextAlignment(.center)
            Text("회원님께 꼭 맞는 운동을 추천하기 위해\n몇 가지 질문을 드릴게요.")
                .font(.subheadline)
                .foregroundColor(Theme.subtle)
                .multilineTextAlignment(.center)
            Spacer()
            Button("좋아요") { go(.level) }
                .buttonStyle(EnergyButtonStyle())
        }
        .padding(24)
    }

    // MARK: - 1. 운동 수준

    private var levelView: some View {
        chrome(title: "운동 수준이 어떻게 되시나요?",
               subtitle: "맞춤 운동 추천에 필요해요. 외부에 공개되지 않아요.",
               canNext: level != nil, onNext: { go(.goal) }) {
            VStack(spacing: 10) {
                ForEach(ExperienceLevel.allCases) { lv in
                    OptionRow(title: lv.rawValue, detail: lv.detail,
                              selected: level == lv,
                              comment: level == lv ? levelComment(lv) : nil) {
                        level = lv
                    }
                }
            }
        }
    }

    private func levelComment(_ lv: ExperienceLevel) -> String {
        switch lv {
        case .beginner, .novice: return "제가 적절한 운동 플랜을 잘 추천해 드릴게요!"
        case .intermediate, .advanced: return "좋아요! 수준에 맞게 강도를 올려드릴게요."
        }
    }

    // MARK: - 2. 목표

    private var goalView: some View {
        chrome(title: "가장 중요한 목표는 무엇인가요?",
               subtitle: "체성분과 함께 운동 추천에 반영돼요.",
               canNext: goal != nil, onNext: { go(.frequency) }) {
            VStack(spacing: 10) {
                ForEach([FitnessGoal.fatLoss, .muscleGain, .endurance, .maintain]) { g in
                    OptionRow(title: g.rawValue, detail: g.detail, icon: g.icon,
                              selected: goal == g,
                              comment: goal == g ? "\(g.rawValue), 멋진 목표예요. 같이 만들어가요!" : nil) {
                        goal = g
                    }
                }
            }
        }
    }

    // MARK: - 3. 주간 횟수

    private var frequencyView: some View {
        chrome(title: "일주일에 몇 번 운동하실 예정인가요?",
               subtitle: "수준과 목표에 맞춰 추천한 운동 횟수예요.",
               canNext: true, onNext: { go(.timing) }) {
            VStack(spacing: 10) {
                ForEach([2, 3, 4, 5, 6], id: \.self) { n in
                    OptionRow(title: "\(n)회",
                              badge: (n == 4 || n == 5) ? "추천" : nil,
                              selected: weekly == n,
                              comment: weekly == n ? "일주일에 \(n)번이나 운동한다니, 대단해요!" : nil) {
                        weekly = n
                    }
                }
            }
        }
    }

    // MARK: - 4. 시작 시점

    private var timingView: some View {
        chrome(title: "언제부터 운동할 예정이세요?",
               subtitle: "오늘·내일 시작한 사람들의 목표 달성률이 6배 더 높아요!",
               canNext: timing != nil, onNext: { go(.inbody) }) {
            VStack(spacing: 10) {
                ForEach(StartTiming.allCases) { t in
                    OptionRow(title: t.rawValue,
                              selected: timing == t,
                              comment: timing == t && t == .now ? "지금 시작하는 게 최고예요! 바로 가봐요." : nil) {
                        timing = t
                    }
                }
            }
        }
    }

    // MARK: - 5. 인바디 입력

    private var inbodyView: some View {
        chrome(title: "인바디 데이터를 입력해 주세요",
               subtitle: "체성분에 딱 맞는 운동을 추천해드려요.",
               canNext: inbodyValid, onNext: { startGenerating() }) {
            VStack(spacing: 14) {
                Button { loadSample() } label: {
                    Label("샘플 데이터 불러오기", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                }
                field("체중", "kg", $weight)
                field("키", "cm", $height)
                field("골격근량", "kg", $muscle)
                field("체지방량", "kg", $fatMass)
                field("기초대사량", "kcal", $bmr)
                Text("BMI는 키·체중으로 자동 계산돼요.")
                    .font(.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var inbodyValid: Bool { Double(weight) != nil && Double(height) != nil && Double(fatMass) != nil }

    private func field(_ label: String, _ unit: String, _ binding: Binding<String>) -> some View {
        HStack {
            Text(label).font(.subheadline.weight(.medium)).foregroundColor(Theme.ink)
            Spacer()
            TextField("0", text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            if !unit.isEmpty {
                Text(unit).font(.caption).foregroundColor(.secondary).frame(width: 36, alignment: .leading)
            } else {
                Spacer().frame(width: 36)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func loadSample() {
        let s = InBodyResult.sample
        weight = String(Int(s.weight))
        height = String(Int(s.height))
        muscle = String(format: "%.1f", s.skeletalMuscleMass)
        fatMass = String(format: "%.1f", s.bodyFatMass)
        bmr = String(Int(s.bmr))
    }

    // MARK: - 6. 플랜 생성 로딩

    private var generatingView: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("회원님을 위한\n맞춤 플랜을 구성중이에요")
                .font(.title.weight(.heavy))
                .foregroundColor(Theme.ink)
                .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .stroke(Theme.accentSoft, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: genProgress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(genProgress * 100))%")
                    .font(.system(size: 44, weight: .black))
                    .foregroundColor(Theme.ink)
            }
            .frame(width: 200, height: 200)

            Text(genStatus)
                .font(.subheadline)
                .foregroundColor(Theme.subtle)
            Spacer()
        }
        .padding(24)
        .task {
            genProgress = 0
            // 약 2.2초에 걸쳐 0 → 100%
            for i in 1...100 {
                try? await Task.sleep(nanoseconds: 22_000_000)
                genProgress = Double(i) / 100
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            go(.plan)
        }
    }

    private var genStatus: String {
        switch genProgress {
        case ..<0.34: return "체성분 데이터를 분석하고 있어요"
        case ..<0.7:  return "골격근량·체지방을 운동에 매칭하고 있어요"
        default:      return "맞춤 운동을 고르는 중이에요"
        }
    }

    // MARK: - 7. 플랜 완성 카드

    private var planView: some View {
        let inBody = store.inBody ?? .empty
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("내게 꼭 맞는 맞춤 운동\n플랜이 준비됐어요!")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(Theme.ink)
                        .padding(.top, 12)

                    // 플랜 카드
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 12) {
                            coachAvatar(size: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AI 맞춤 플랜").font(.caption).foregroundColor(.secondary)
                                Text(goal?.rawValue ?? inBody.goalLabel)
                                    .font(.title3.weight(.heavy)).foregroundColor(Theme.ink)
                            }
                            Spacer()
                        }

                        Divider()

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                            planMetric("추천 수준", level?.rawValue ?? "초급")
                            planMetric("주간 횟수", "주 \(weekly)회")
                            planMetric("키", "\(Int(inBody.height))cm")
                            planMetric("체중", "\(Int(inBody.weight))kg")
                            planMetric("골격근량", String(format: "%.1fkg", inBody.skeletalMuscleMass))
                            planMetric("체지방률", "\(Int(inBody.bodyFatPercent))%")
                        }
                    }
                    .card()

                    // 목표 칩
                    FlowLayout(spacing: 8) {
                        ForEach(inBody.goals, id: \.self) { g in GoalChip(goal: g) }
                    }

                    // 식단도 함께 — 운동+식단 통합 첫인상
                    dietGuideCard(inBody)
                }
                .padding()
            }
            Button("시작하기") { store.completeOnboarding() }
                .buttonStyle(EnergyButtonStyle())
                .padding()
        }
    }

    private func planMetric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 17, weight: .black)).foregroundColor(Theme.ink)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 플랜 카드 하단 — 운동뿐 아니라 식단도 함께 관리한다는 통합 안내
    @ViewBuilder
    private func dietGuideCard(_ inBody: InBodyResult) -> some View {
        let g = goal ?? inBody.goals.first ?? .maintain
        let protein = inBody.proteinTarget(for: g)
        let direction: String = {
            switch g.calorieDirection {
            case .deficit: return "칼로리는 살짝 적자로"
            case .surplus: return "칼로리는 살짝 흑자로"
            case .balance: return "칼로리는 균형 있게"
            }
        }()
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "fork.knife").foregroundColor(Theme.accent)
                Text("식단도 함께 관리해요").font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
            }
            Text("\(g.rawValue) 목표에 맞춰 \(direction), 단백질은 하루 \(protein)g을 권장해요. 먹은 음식을 기록하면 매일 코칭해드려요.")
                .font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - 공용 chrome (진행바 + 제목 + 옵션 + 다음 버튼)

    @ViewBuilder
    private func chrome<Content: View>(title: String, subtitle: String, canNext: Bool,
                                       onNext: @escaping () -> Void,
                                       @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            // 상단: 뒤로 + 진행바
            HStack(spacing: 12) {
                Button { back() } label: {
                    Image(systemName: "chevron.left").font(.title3.weight(.semibold)).foregroundColor(Theme.ink)
                }
                ProgressView(value: progressFraction)
                    .tint(Theme.accent)
            }
            .padding(.horizontal).padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.title2.weight(.heavy)).foregroundColor(Theme.ink)
                    Text(subtitle).font(.subheadline).foregroundColor(Theme.subtle)
                    content().padding(.top, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }

            Button("다음", action: onNext)
                .buttonStyle(EnergyButtonStyle(color: canNext ? Theme.accent : Color(.systemGray3)))
                .disabled(!canNext)
                .padding()
        }
    }

    private var progressFraction: Double {
        let total = Double(Step.inbody.rawValue)   // level..inbody 기준
        return min(1, Double(step.rawValue) / total)
    }

    // MARK: - 캐릭터 아바타

    private func coachAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle().fill(Theme.accentSoft).frame(width: size, height: size)
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: size * 0.45))
                .foregroundColor(Theme.accent)
        }
    }

    // MARK: - 단계 이동

    private func go(_ s: Step) {
        withAnimation { step = s }
    }

    private func back() {
        guard let prev = Step(rawValue: step.rawValue - 1), prev != .intro || step == .level else {
            go(.intro); return
        }
        go(prev)
    }

    private func startGenerating() {
        // 인바디 + 온보딩 답변 저장 후 플랜 생성 연출로
        let result = InBodyResult(
            weight: Double(weight) ?? 0,
            height: Double(height) ?? 0,
            skeletalMuscleMass: Double(muscle) ?? 0,
            bodyFatMass: Double(fatMass) ?? 0,
            bmr: Double(bmr) ?? 0
        )
        store.saveInBody(result)
        store.saveOnboarding(UserProfile(
            level: level ?? .beginner,
            primaryGoal: goal ?? .fatLoss,
            weeklyGoal: weekly,
            startTiming: timing ?? .now
        ))
        go(.generating)
    }
}

// MARK: - 선택 옵션 행

private struct OptionRow: View {
    let title: String
    var detail: String? = nil
    var icon: String? = nil
    var badge: String? = nil
    let selected: Bool
    var comment: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    if let icon {
                        Image(systemName: icon).foregroundColor(selected ? Theme.accent : .secondary)
                    }
                    Text(title).font(.headline).foregroundColor(Theme.ink)
                    if let badge {
                        Text(badge).font(.caption2.weight(.bold))
                            .foregroundColor(Theme.onAccent)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Theme.accent, in: Capsule())
                    }
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.accent)
                    }
                }
                if let detail {
                    Text(detail).font(.caption).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if selected, let comment {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.caption).foregroundColor(Theme.accent)
                        Text(comment).font(.caption.weight(.medium)).foregroundColor(Theme.accent)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? Theme.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

/// 대화형 AI 코치 — 오늘 운동·식단을 먼저 요약하고, 자유롭게 대화한다.
struct AICoachView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var sending = false
    @FocusState private var inputFocused: Bool

    private let suggestions = ["오늘 식단 평가해줘", "운동 추천해줘", "단백질 뭐로 채울까?", "내일 뭐 먹을까?"]

    private var openAIKey: String {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            ?? Secrets.openAIAPIKey
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        summaryCard
                        ForEach(messages) { msg in bubble(msg) }
                        if sending { typingBubble }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: sending) { _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
            suggestionRow
            inputBar
        }
        .background(Theme.bg.ignoresSafeArea())
        .task { if messages.isEmpty { await opening() } }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.title3.weight(.semibold)).foregroundColor(Theme.ink)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundColor(Theme.accent)
                Text("AI 코치").font(.headline.weight(.bold)).foregroundColor(Theme.ink)
            }
            Spacer()
            Image(systemName: "chevron.left").opacity(0)   // 좌우 균형
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - 오늘 요약 카드

    private var summaryCard: some View {
        let m = store.macros(on: Date())
        let pct = store.macroPercents(on: Date())
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                coachAvatar
                VStack(alignment: .leading, spacing: 1) {
                    Text("T 코치").font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
                    Text("오늘의 운동·식단을 봤어요").font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
            }
            HStack(alignment: .firstTextBaseline) {
                Text("오늘 점수").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("\(store.todayScore)점").font(.title3.weight(.black)).foregroundColor(Theme.accent)
            }
            HStack {
                Text("섭취 \(store.todayIntakeKcal) · 소비 \(store.todayBurnKcal) kcal")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
            }
            HStack(spacing: 12) {
                macroDot("탄", m.carbs, pct.carbs, Color(red: 0.58, green: 0.45, blue: 0.92))
                macroDot("단", m.protein, pct.protein, Color(red: 0.27, green: 0.53, blue: 0.96))
                macroDot("지", m.fat, pct.fat, Color(red: 0.30, green: 0.80, blue: 0.74))
                Spacer()
            }
            FlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag).font(.caption2.weight(.semibold)).foregroundColor(Theme.accent)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Theme.accentSoft, in: Capsule())
                }
            }
        }
        .card()
    }

    private func macroDot(_ label: String, _ g: Double, _ pct: Int, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label) \(Int(g))g").font(.caption.weight(.semibold)).foregroundColor(Theme.ink)
            Text("\(pct)%").font(.caption2).foregroundColor(.secondary)
        }
    }

    private var tags: [String] {
        var t: [String] = []
        if store.didWorkoutToday { t.append("운동 완료 💪") }
        if let target = store.proteinTarget, Int(store.macros(on: Date()).protein) >= target { t.append("단백질 풍부") }
        let v = store.dietVerdict(on: Date())
        if store.todayIntakeKcal > 0 { t.append(v.onTrack ? "수지 좋아요 👍" : "수지 주의") }
        if t.isEmpty { t.append("오늘을 채워봐요") }
        return t
    }

    // MARK: - 말풍선

    private func bubble(_ msg: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if msg.role == .assistant {
                coachAvatar.frame(width: 28, height: 28)
                Text(msg.text)
                    .font(.subheadline).foregroundColor(Theme.ink)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                Spacer(minLength: 24)
            } else {
                Spacer(minLength: 24)
                Text(msg.text)
                    .font(.subheadline).foregroundColor(Theme.onAccent)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var typingBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            coachAvatar.frame(width: 28, height: 28)
            ThreeDotsLoader().padding(.horizontal, 14).padding(.vertical, 12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
            Spacer(minLength: 24)
        }
    }

    private var coachAvatar: some View {
        ZStack {
            Circle().fill(Theme.accentSoft)
            Image(systemName: "sparkles").font(.caption).foregroundColor(Theme.accent)
        }
        .frame(width: 34, height: 34)
    }

    // MARK: - 추천 질문 + 입력

    private var suggestionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Button { send(s) } label: {
                        Text(s).font(.caption.weight(.semibold)).foregroundColor(Theme.ink)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Theme.card, in: Capsule())
                    }
                    .disabled(sending)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("무엇이든 물어보세요", text: $input)
                .focused($inputFocused)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.card, in: Capsule())
            Button { send(input) } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundColor(canSend ? Theme.accent : Color(.systemGray3))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool { !input.trimmingCharacters(in: .whitespaces).isEmpty && !sending }

    // MARK: - 로직

    private func systemPrompt() -> String {
        let m = store.macros(on: Date())
        let net = store.todayNetKcal
        var ctx = "오늘 점수 \(store.todayScore)점. "
        ctx += "섭취 \(store.todayIntakeKcal)kcal, 소비 \(store.todayBurnKcal)kcal(운동·걸음 포함), 수지 \(net)kcal. "
        ctx += "단백질 \(Int(m.protein))g"
        if let t = store.proteinTarget { ctx += " / 권장 \(t)g" }
        ctx += ". 오늘 운동 \(store.didWorkoutToday ? "완료" : "아직 안 함"), 걸음 \(store.todaySteps). "
        if let inBody = store.inBody { ctx += "체성분: \(inBody.coachProfileSummary) " }
        ctx += "목표: \(store.dietGoal.rawValue)."

        return """
        너는 'T 코치', 운동과 식단을 함께 봐주는 전문 헬스 트레이너 겸 영양 코치야.
        한국어로 따뜻하고 힘차게, 짧고 실용적으로 코칭해. 한 번에 3~4문장 이내.
        운동과 식단을 연결해서 조언하고(예: 운동 많이 한 날은 단백질·탄수 보충, 칼로리 흑자면 가볍게 더 움직이기),
        필요하면 구체적인 음식이나 운동을 1~2개 추천해. 데이터에 근거해 말하고, 모르면 솔직히 말해.

        [사용자 오늘 상태]
        \(ctx)
        """
    }

    private func opening() async {
        sending = true
        let service = CoachChatService(apiKey: openAIKey)
        let seed = [ChatMessage(role: .user, text: "오늘 내 운동과 식단을 보고 먼저 짧게 인사하며 코칭 한마디 해줘. 그리고 무엇을 도와줄 수 있는지 알려줘.")]
        if let line = try? await service.reply(system: systemPrompt(), history: seed) {
            messages.append(ChatMessage(role: .assistant, text: line))
        } else {
            messages.append(ChatMessage(role: .assistant,
                text: "안녕하세요! 오늘 운동과 식단을 함께 봐드릴게요. 식단 평가, 운동 추천, 뭘 먹을지까지 무엇이든 물어보세요 💪"))
        }
        sending = false
    }

    private func send(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !sending else { return }
        input = ""
        inputFocused = false
        messages.append(ChatMessage(role: .user, text: q))
        sending = true
        let history = messages
        let service = CoachChatService(apiKey: openAIKey)
        Task { @MainActor in
            if let line = try? await service.reply(system: systemPrompt(), history: history) {
                messages.append(ChatMessage(role: .assistant, text: line))
            } else {
                messages.append(ChatMessage(role: .assistant,
                    text: "지금은 답하기 어려워요. 잠시 후 다시 시도해 주세요."))
            }
            sending = false
        }
    }
}

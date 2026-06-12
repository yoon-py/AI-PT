import SwiftUI
import Charts

/// 예측 그래프용 2점 데이터 (현재 → 예측)
private struct PredPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

/// 분석 탭 — 내 체성분 + 다음 인바디 예측 + 활동 + 정보 (프로필 통합)
struct AnalysisView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let inBody = store.inBody ?? .empty
        VStack(spacing: 0) {
            FixedHeader(title: "분석")
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profileHeader(inBody)
                    bodyCard(inBody)

                    if let p = store.prediction() {
                        predictionHeader(p)
                        metricGraph("체중", "kg", p.current.weight, p.predicted.weight,
                                    upIsGood: p.current.muscleFocus)
                        metricGraph("골격근량", "kg", p.current.skeletalMuscleMass, p.predicted.skeletalMuscleMass,
                                    upIsGood: true)
                        metricGraph("체지방량", "kg", p.current.bodyFatMass, p.predicted.bodyFatMass,
                                    upIsGood: false)
                        metricGraph("체지방률", "%", p.current.bodyFatPercent, p.predicted.bodyFatPercent,
                                    upIsGood: false)
                    }
                    findingsCard
                    activitySection
                    updateLink
                    aboutSection
                }
                .padding()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - 프로필 헤더 (목표)

    private func profileHeader(_ inBody: InBodyResult) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.accentSoft).frame(width: 64, height: 64)
                Image(systemName: "person.fill").font(.system(size: 30)).foregroundColor(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("나의 운동 목표").font(.caption).foregroundColor(.secondary)
                FlowLayout(spacing: 8) {
                    ForEach(inBody.goals, id: \.self) { goal in GoalChip(goal: goal) }
                }
            }
            Spacer()
        }
        .card()
    }

    // MARK: - 내 체성분

    private func bodyCard(_ inBody: InBodyResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("내 체성분").sectionTitle()
                Spacer()
                if let days = store.daysSinceLastInBody {
                    Text(days == 0 ? "오늘 측정" : "\(days)일 전")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metric("체중", String(format: "%.1f", inBody.weight), "kg")
                metric("키", String(format: "%.0f", inBody.height), "cm")
                metric("골격근량", String(format: "%.1f", inBody.skeletalMuscleMass), "kg")
                metric("체지방률", "\(Int(inBody.bodyFatPercent))", "%")
                metric("BMI", String(format: "%.1f", inBody.bmi), "")
                metric("기초대사량", "\(Int(inBody.bmr))", "kcal")
            }
        }
    }

    // MARK: - 예측 헤더

    private func predictionHeader(_ p: InBodyPrediction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(p.headline)
                .font(.subheadline.weight(.medium)).foregroundColor(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(p.hasChange
                 ? "이번 주 운동 \(p.workoutsThisWeek)회 기준 · 약 \(p.timeText) 뒤 예상치"
                 : "운동을 시작하면 예측이 채워져요")
                .font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 지표별 현재→예측 그래프

    private func metricGraph(_ title: String, _ unit: String,
                             _ current: Double, _ predicted: Double, upIsGood: Bool) -> some View {
        let delta = predicted - current
        let noChange = abs(delta) < 0.05
        let improved = !noChange && ((delta > 0) == upIsGood)
        let color: Color = noChange ? Theme.subtle : (improved ? Theme.accent : .orange)
        let points = [PredPoint(label: "현재", value: current),
                      PredPoint(label: "예측", value: predicted)]
        let lo = min(current, predicted), hi = max(current, predicted)
        let pad = max(0.6, (hi - lo) * 0.8)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
                Spacer()
                Text(deltaText(delta, unit: unit, noChange: noChange))
                    .font(.caption.weight(.bold)).foregroundColor(color)
            }
            Chart(points) { pt in
                LineMark(x: .value("시점", pt.label), y: .value(unit, pt.value))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                PointMark(x: .value("시점", pt.label), y: .value(unit, pt.value))
                    .foregroundStyle(color)
                    .symbolSize(120)
                    .annotation(position: .top) {
                        Text(valueText(pt.value, unit))
                            .font(.caption2.weight(.bold)).foregroundColor(Theme.ink)
                    }
            }
            .chartYScale(domain: (lo - pad)...(hi + pad))
            .chartYAxis(.hidden)
            .frame(height: 96)
        }
        .card(padding: 16)
    }

    private func deltaText(_ delta: Double, unit: String, noChange: Bool) -> String {
        if noChange { return "변화 예측 없음" }
        let sign = delta > 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.1f", abs(delta)))\(unit)"
    }

    private func valueText(_ v: Double, _ unit: String) -> String {
        unit == "%" ? "\(Int(v.rounded()))%" : String(format: "%.1f", v)
    }

    // MARK: - 분석 결과

    private var findingsCard: some View {
        let inBody = store.inBody ?? .empty
        return VStack(alignment: .leading, spacing: 12) {
            Text("분석 결과").sectionTitle()
            ForEach(inBody.findings, id: \.self) { finding in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundColor(Theme.accent)
                    Text(finding).font(.subheadline)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - 활동 요약

    private var activitySection: some View {
        HStack(spacing: 12) {
            stat("총 운동", "\(store.totalWorkouts)회")
            stat("이번 주", "\(store.workoutsThisWeek)회")
            stat("목표 달성", "\(store.goalReachedCount)회")
        }
    }

    // MARK: - 인바디 업데이트

    private var updateLink: some View {
        NavigationLink {
            InBodyInputView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise.circle.fill").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("인바디 업데이트").fontWeight(.bold)
                    Text(store.inBodyUpdateDue ? "측정한 지 일주일이 지났어요" : "새 측정값으로 갱신하기")
                        .font(.caption).opacity(0.9)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundColor(store.inBodyUpdateDue ? Theme.onAccent : Theme.ink)
            .padding()
            .background(store.inBodyUpdateDue ? Theme.accent : Theme.card,
                        in: RoundedRectangle(cornerRadius: Theme.radius))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 앱 정보

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("앱 정보").sectionTitle()
            infoRow("버전", "1.0.0")
            infoRow("AI 코치", "OpenAI")
            infoRow("자세 분석", "MediaPipe Pose")
        }
        .card()
    }

    // MARK: - 공용 타일

    private func metric(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 22, weight: .black)).foregroundColor(Theme.ink)
                if !unit.isEmpty {
                    Text(unit).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .black)).foregroundColor(Theme.ink)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.medium)).foregroundColor(Theme.ink)
        }
    }
}

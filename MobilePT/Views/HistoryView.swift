import SwiftUI

/// 기록 탭 — 운동 통계 + 전체 히스토리 + 인바디 측정 이력
struct HistoryView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            FixedHeader(title: "기록")
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    WorkoutCalendarView(workoutDays: workoutDays)
                    statsSection
                    workoutSection
                    inBodySection
                }
                .padding()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// 운동 기록이 있는 날짜(자정 기준)
    private var workoutDays: Set<Date> {
        let cal = Calendar.current
        return Set(store.workoutLogs.map { cal.startOfDay(for: $0.date) })
    }

    // MARK: - 통계 요약

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard("이번 주", "\(store.workoutsThisWeek)", "회")
            statCard("총 운동", "\(store.totalWorkouts)", "회")
            statCard("목표 달성", "\(Int(store.goalReachedRate * 100))", "%")
        }
    }

    private func statCard(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 26, weight: .black)).foregroundColor(Theme.accent)
                Text(unit).font(.caption).foregroundColor(.secondary)
            }
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 운동 히스토리

    @ViewBuilder
    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("운동 히스토리").sectionTitle()
            if store.workoutLogs.isEmpty {
                emptyRow("아직 운동 기록이 없어요", "운동 탭에서 첫 운동을 시작해보세요")
            } else {
                ForEach(store.workoutLogs) { log in
                    HStack(spacing: 12) {
                        Image(systemName: log.exercise.icon)
                            .font(.title3).foregroundColor(Theme.accent)
                            .frame(width: 44, height: 44)
                            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.exercise.rawValue).font(.subheadline.weight(.semibold))
                            Text(fullDate(log.date)).font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(log.summary).font(.subheadline.weight(.bold))
                                .foregroundColor(Theme.ink)
                            if log.goalReached {
                                Label("달성", systemImage: "checkmark.seal.fill")
                                    .font(.caption2).foregroundColor(Theme.success)
                            }
                        }
                    }
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    // MARK: - 인바디 측정 이력

    @ViewBuilder
    private var inBodySection: some View {
        if store.inBodyHistory.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                Text("인바디 측정 이력").sectionTitle()
                ForEach(Array(store.inBodyHistory.enumerated().reversed()), id: \.offset) { _, m in
                    HStack {
                        Image(systemName: "scalemass.fill").foregroundColor(Theme.accent)
                        Text(fullDate(m.date)).font(.subheadline)
                        Spacer()
                        Text("\(String(format: "%.1f", m.weight))kg · 근육 \(String(format: "%.1f", m.skeletalMuscleMass))kg")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func emptyRow(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(subtitle).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func fullDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E) a h:mm"
        return f.string(from: date)
    }
}

// MARK: - 운동 캘린더 (완료한 날 🔥 표시)

private struct WorkoutCalendarView: View {
    let workoutDays: Set<Date>

    private let cal = Calendar(identifier: .gregorian)
    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    @State private var month: Date = {
        let c = Calendar(identifier: .gregorian)
        return c.date(from: c.dateComponents([.year, .month], from: Date())) ?? Date()
    }()

    var body: some View {
        VStack(spacing: 16) {
            header
            weekdayRow
            grid
        }
        .card()
    }

    // 헤더: < 2026.06. >  ...  오늘
    private var header: some View {
        HStack(spacing: 14) {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left").font(.headline).foregroundColor(Theme.ink)
            }
            Text(monthTitle).font(.headline.weight(.bold)).foregroundColor(Theme.ink)
            Button { shift(1) } label: {
                Image(systemName: "chevron.right").font(.headline).foregroundColor(Theme.ink)
            }
            Spacer()
            Button("오늘") { month = startOfMonth(Date()) }
                .font(.caption.weight(.bold))
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Theme.accentSoft, in: Capsule())
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { idx, day in
                Text(day)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(idx == 0 ? .red.opacity(0.7) : (idx == 6 ? .blue.opacity(0.7) : .secondary))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                if let day = cell {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 46)
                }
            }
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let date = cal.date(byAdding: .day, value: day - 1, to: month) ?? month
        let completed = workoutDays.contains(cal.startOfDay(for: date))
        let isToday = cal.isDateInToday(date)
        return ZStack {
            if isToday {
                Circle().stroke(Theme.accent, lineWidth: 2).frame(width: 40, height: 40)
            }
            if completed {
                VStack(spacing: 0) {
                    Text("\(day)").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.ink)
                    Text("🔥").font(.system(size: 17))
                }
            } else {
                Text("\(day)")
                    .font(.system(size: 16, weight: isToday ? .bold : .regular))
                    .foregroundColor(isToday ? Theme.accent : Theme.ink)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
    }

    // MARK: - 계산

    /// 첫 칸 = 1일 요일만큼 빈칸 + 1...말일
    private var cells: [Int?] {
        let weekday = cal.component(.weekday, from: month) // 1=일
        let leading = weekday - 1
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        return Array(repeating: nil, count: leading) + (1...count).map { Optional($0) }
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM."
        return f.string(from: month)
    }

    private func startOfMonth(_ date: Date) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    private func shift(_ n: Int) {
        if let m = cal.date(byAdding: .month, value: n, to: month) {
            month = m
        }
    }
}

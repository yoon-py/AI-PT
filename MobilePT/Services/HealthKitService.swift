import Foundation
import HealthKit

/// Apple 건강(HealthKit) 연동 — 액티브 에너지/걸음 읽기 + 운동 쓰기.
/// 권한이 없거나 데이터가 없으면 nil/무동작으로 폴백한다.
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let workoutType = HKObjectType.workoutType()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// 권한 요청 (읽기: 액티브 에너지·걸음 / 쓰기: 액티브 에너지·운동)
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let read: Set<HKObjectType> = [activeEnergyType, stepType]
        let share: Set<HKSampleType> = [activeEnergyType, workoutType]
        do {
            try await store.requestAuthorization(toShare: share, read: read)
            return true
        } catch {
            return false
        }
    }

    /// 특정 날짜 액티브 에너지 합계(kcal). 측정값 없으면 nil.
    func activeEnergy(on date: Date) async -> Int? {
        guard isAvailable else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = min(Date(), cal.date(byAdding: .day, value: 1, to: start) ?? start)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: activeEnergyType,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, _ in
                guard let sum = stats?.sumQuantity() else { cont.resume(returning: nil); return }
                cont.resume(returning: Int(sum.doubleValue(for: .kilocalorie()).rounded()))
            }
            store.execute(q)
        }
    }

    /// 완료한 운동을 건강 앱에 기록 (운동 + 소모 칼로리)
    func saveWorkout(kcal: Int, durationSec: Double) {
        guard isAvailable, kcal > 0 else { return }
        let end = Date()
        let duration = max(durationSec, 60)
        let start = end.addingTimeInterval(-duration)
        let energy = HKQuantity(unit: .kilocalorie(), doubleValue: Double(kcal))
        let workout = HKWorkout(activityType: .functionalStrengthTraining,
                                start: start, end: end,
                                duration: duration,
                                totalEnergyBurned: energy,
                                totalDistance: nil, metadata: nil)
        store.save(workout) { _, _ in }
    }
}

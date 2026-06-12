import CoreMotion
import Foundation

/// 만보기 한 구간의 측정값 — 걸음수 + 실측 이동 거리(가능할 때).
struct WalkData {
    var steps: Int
    var distanceMeters: Double?

    static let zero = WalkData(steps: 0, distanceMeters: nil)
}

/// CoreMotion 만보기 — 오늘 걸음/거리 실시간 추적 + 특정 날짜(최근 7일) 조회.
/// HealthKit 없이 동작하며, 시뮬레이터에는 센서가 없어 0을 반환한다.
final class PedometerService {
    private let pedometer = CMPedometer()

    static var isAvailable: Bool { CMPedometer.isStepCountingAvailable() }

    /// 오늘 0시부터의 걸음/거리를 실시간으로 받는다 (메인 스레드 콜백).
    func startLiveUpdates(_ handler: @escaping (WalkData) -> Void) {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let start = Calendar.current.startOfDay(for: Date())
        pedometer.startUpdates(from: start) { data, _ in
            guard let data else { return }
            let walk = WalkData(steps: data.numberOfSteps.intValue,
                                distanceMeters: data.distance?.doubleValue)
            DispatchQueue.main.async { handler(walk) }
        }
    }

    func stop() { pedometer.stopUpdates() }

    /// 특정 날짜의 걸음/거리 조회 (CMPedometer는 최근 7일까지만 보관). 실패 시 0.
    func walk(on date: Date) async -> WalkData {
        guard CMPedometer.isStepCountingAvailable() else { return .zero }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: start) ?? start
        let end = min(Date(), dayEnd)
        return await withCheckedContinuation { cont in
            pedometer.queryPedometerData(from: start, to: end) { data, _ in
                guard let data else { cont.resume(returning: .zero); return }
                cont.resume(returning: WalkData(steps: data.numberOfSteps.intValue,
                                                distanceMeters: data.distance?.doubleValue))
            }
        }
    }
}

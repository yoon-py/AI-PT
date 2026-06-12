import SwiftUI

/// 하단 5탭 — 홈 / 운동 / 식단 / 분석 / 프로필
struct MainTabView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            // 0) 홈 — 오늘 글랜스 대시보드
            NavigationStack {
                HomeDashboardView()
            }
            .tabItem { Label("홈", systemImage: "house.fill") }
            .tag(0)

            // 1) 운동 — 허브 + 세션/결과 플로우 (store.path 연결)
            NavigationStack(path: $store.path) {
                WorkoutView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .inBodyInput:
                            InBodyInputView()
                        case .analysis:
                            AnalysisView()
                        case .exerciseList:
                            ExerciseListView()
                        case .routinePreview:
                            RoutinePreviewView()
                        case .guide(let type, let goal):
                            ExerciseGuideView(exercise: type, goal: goal)
                        case .rest(let type, let goal):
                            RestView(nextExercise: type, goal: goal)
                        case .session(let type, let goal):
                            ExerciseSessionView(exercise: type, goal: goal, inBody: store.inBody) { reps in
                                if store.inRoutine {
                                    store.completeCurrentAndAdvance(reps: reps)
                                } else {
                                    store.logWorkout(exercise: type, count: reps, goal: goal)
                                    store.path.append(.results(type, reps))
                                }
                            }
                        case .results(let type, let reps):
                            ResultsView(exercise: type, reps: reps)
                        case .routineComplete(let count):
                            RoutineCompleteView(exerciseCount: count)
                        }
                    }
            }
            .tabItem { Label("운동", systemImage: "figure.run") }
            .tag(1)

            // 2) 식단 — 칼로리 수지 + 음식 기록
            NavigationStack {
                DietView()
            }
            .tabItem { Label("식단", systemImage: "fork.knife") }
            .tag(2)

            // 3) 분석 — 내 체성분 + 예측 + 활동 + 정보 (프로필 통합)
            NavigationStack {
                AnalysisView()
            }
            .tabItem { Label("분석", systemImage: "chart.bar.fill") }
            .tag(3)
        }
    }
}

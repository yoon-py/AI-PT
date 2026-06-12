import SwiftUI

struct ContentView: View {
    @StateObject private var store = AppStore()

    var body: some View {
        Group {
            if store.didCompleteOnboarding {
                MainTabView()
            } else {
                // 첫 실행 → 대화형 온보딩 (질문 → 인바디 → 플랜 생성)
                OnboardingView()
            }
        }
        .tint(Theme.accent)
        .environmentObject(store)
        .preferredColorScheme(store.colorScheme)
        .onAppear {
            store.startStepTracking()
            store.startHealthSync()
        }
    }
}

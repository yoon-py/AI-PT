import SwiftUI

/// 촬영/선택 + 분석 결과를 함께 담아 결과 화면으로 전달.
struct CapturedFoodImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let analysis: FoodAnalysis?
    let failed: Bool
}

/// 커스텀 음식 카메라 — 라이브 프리뷰 + 셔터 + 앨범 + 플래시.
/// 촬영하면 사진을 그대로 깔고 그 위에서 AI 분석 단계를 순차로 보여준다.
struct FoodCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = FoodCameraController()

    /// 분석까지 끝낸 결과 전달 (이미지, 분석값 또는 nil, 실패 여부)
    var onResult: (UIImage, FoodAnalysis?, Bool) -> Void

    @State private var showLibrary = false
    @State private var captured: UIImage?       // 분석 중 깔리는 사진
    @State private var statusIndex = 0
    @State private var statusTask: Task<Void, Never>?
    @State private var work: Task<Void, Never>?

    private let statuses = [
        "음식 종류를 알아내고 있어요",
        "섭취량을 추정하고 있어요",
        "칼로리를 계산 중이에요",
        "기타 영양소를 추정하고 있어요"
    ]

    private var isAnalyzing: Bool { captured != nil }

    private var openAIKey: String {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            ?? Secrets.openAIAPIKey
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let captured {
                Image(uiImage: captured)
                    .resizable().scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.5).ignoresSafeArea())
            } else if camera.permissionDenied {
                permissionView
            } else {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            }

            // 가운데 분석 단계 표시
            if isAnalyzing {
                VStack(spacing: 20) {
                    Text(statuses[statusIndex])
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .id(statusIndex)
                        .transition(.opacity)
                    ThreeDotsLoader()
                }
                .padding(.horizontal, 32)
            }

            // 컨트롤
            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
            }
        }
        .statusBarHidden(true)
        .onAppear { camera.start() }
        .onDisappear { camera.stop(); statusTask?.cancel(); work?.cancel() }
        .sheet(isPresented: $showLibrary) {
            CameraPicker(sourceType: .photoLibrary) { image in analyze(image) }
                .ignoresSafeArea()
        }
    }

    // MARK: - 상단 (플래시 / 닫기)

    private var topBar: some View {
        HStack {
            Button { camera.flashOn.toggle() } label: {
                Image(systemName: camera.flashOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(camera.flashOn ? .yellow : .white)
                    .frame(width: 44, height: 44)
            }
            .opacity(isAnalyzing ? 0 : 1)
            Spacer()
            Button { cancel() } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - 하단 (앨범 / 셔터)

    private var bottomBar: some View {
        HStack {
            Button { showLibrary = true } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
            }
            .opacity(isAnalyzing ? 0.4 : 1)
            .disabled(isAnalyzing)

            Spacer()

            Button { camera.capture { analyze($0) } } label: {
                ZStack {
                    Circle()
                        .stroke(AngularGradient(colors: [Theme.accent, .cyan, .purple, Theme.accent],
                                                center: .center),
                                lineWidth: 5)
                        .frame(width: 80, height: 80)
                    Circle().fill(.white).frame(width: 66, height: 66)
                }
            }
            .opacity(isAnalyzing ? 0.4 : 1)
            .disabled(isAnalyzing || camera.permissionDenied)

            Spacer()

            Color.clear.frame(width: 54, height: 54)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    // MARK: - 권한 거부

    private var permissionView: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill").font(.largeTitle).foregroundColor(.white.opacity(0.7))
            Text("카메라 접근이 필요해요")
                .font(.headline).foregroundColor(.white)
            Text("설정에서 카메라 권한을 허용하면 음식 사진을 찍을 수 있어요.\n앨범에서 선택은 지금도 가능해요.")
                .font(.caption).foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - 촬영/선택 → 분석

    private func analyze(_ image: UIImage) {
        showLibrary = false
        camera.stop()
        captured = image
        startStatusCycling()

        work = Task {
            let start = Date()
            let service = FoodVisionService(apiKey: openAIKey)
            var result: FoodAnalysis?
            var failed = false
            do { result = try await service.analyze(image: image) }
            catch { failed = true }

            // 단계 연출을 위한 최소 표시 시간 보장
            let elapsed = Date().timeIntervalSince(start)
            let minShow: TimeInterval = 2.6
            if elapsed < minShow {
                try? await Task.sleep(nanoseconds: UInt64((minShow - elapsed) * 1_000_000_000))
            }
            if Task.isCancelled { return }
            await MainActor.run {
                statusTask?.cancel()
                onResult(image, result, failed)
                dismiss()
            }
        }
    }

    private func startStatusCycling() {
        statusIndex = 0
        statusTask = Task { @MainActor in
            var i = 0
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.35)) {
                    statusIndex = min(i, statuses.count - 1)
                }
                try? await Task.sleep(nanoseconds: 1_300_000_000)
                i += 1
            }
        }
    }

    private func cancel() {
        statusTask?.cancel()
        work?.cancel()
        camera.stop()
        dismiss()
    }
}

/// 컬러 3점 로더 — 순차로 통통 튀는 인디케이터.
struct ThreeDotsLoader: View {
    @State private var phase = 0
    private let colors: [Color] = [
        Color(red: 1.0, green: 0.42, blue: 0.42),   // 핑크/레드
        Color(red: 1.0, green: 0.84, blue: 0.25),   // 옐로
        Color(red: 0.40, green: 0.90, blue: 0.90)   // 시안
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(colors[i])
                    .frame(width: 13, height: 13)
                    .scaleEffect(phase == i ? 1.35 : 0.8)
                    .opacity(phase == i ? 1 : 0.55)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000)
                withAnimation(.easeInOut(duration: 0.3)) { phase = (phase + 1) % 3 }
            }
        }
    }
}

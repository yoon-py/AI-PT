import SwiftUI

/// 음식 추가 방법 선택 — "사진 찍기 / 음식 검색" 두 버튼을 나란히 띄운다.
struct FoodAddOptions: View {
    let onCamera: () -> Void
    let onSearch: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 14) {
                Capsule().fill(Theme.hairline).frame(width: 40, height: 5).padding(.top, 10)
                Text("음식 추가").font(.headline.weight(.bold)).foregroundColor(Theme.ink)
                HStack(spacing: 14) {
                    optionCard("camera.fill", "사진 찍기", "AI 분석", onCamera)
                    optionCard("magnifyingglass", "음식 검색", "DB에서 찾기", onSearch)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func optionCard(_ icon: String, _ title: String, _ sub: String,
                            _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2).foregroundColor(Theme.accent)
                    .frame(width: 58, height: 58)
                    .background(Theme.accentSoft, in: Circle())
                Text(title).font(.subheadline.weight(.bold)).foregroundColor(Theme.ink)
                Text(sub).font(.caption2).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

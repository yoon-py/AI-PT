import SwiftUI

/// 음식 항목 하나를 추가/편집하는 시트 (결과 화면에서 라벨 탭 또는 "음식 추가").
struct FoodItemEditView: View {
    @Environment(\.dismiss) private var dismiss
    var item: FoodItem?                 // nil이면 추가
    var onSave: (FoodItem) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var name = ""
    @State private var kcalText = ""
    @State private var carbsText = ""
    @State private var proteinText = ""
    @State private var fatText = ""

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Int(kcalText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    row("음식명") {
                        TextField("예: 흰쌀밥", text: $name).multilineTextAlignment(.trailing)
                    }
                    numberRow("칼로리", "kcal", $kcalText)

                    Text("영양소 (선택)")
                        .font(.caption).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                    numberRow("탄수화물", "g", $carbsText)
                    numberRow("단백질", "g", $proteinText)
                    numberRow("지방", "g", $fatText)

                    if let onDelete {
                        Button(role: .destructive) { onDelete(); dismiss() } label: {
                            Label("이 음식 삭제", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
            }
            .navigationTitle(item == nil ? "음식 추가" : "음식 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button(item == nil ? "추가" : "저장") { save() }
                    .buttonStyle(EnergyButtonStyle(color: canSave ? Theme.accent : Color(.systemGray3)))
                    .disabled(!canSave)
                    .padding()
                    .background(.ultraThinMaterial)
            }
        }
        .task { populate() }
    }

    private func populate() {
        guard let item else { return }
        name = item.name
        kcalText = String(item.kcal)
        carbsText = item.carbs.map { String(Int($0)) } ?? ""
        proteinText = item.protein.map { String(Int($0)) } ?? ""
        fatText = item.fat.map { String(Int($0)) } ?? ""
    }

    private func save() {
        let result = FoodItem(
            id: item?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            kcal: Int(kcalText) ?? 0,
            carbs: Double(carbsText),
            protein: Double(proteinText),
            fat: Double(fatText),
            x: item?.x,
            y: item?.y
        )
        onSave(result)
        dismiss()
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).font(.subheadline.weight(.medium)).foregroundColor(Theme.ink)
            Spacer()
            content()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func numberRow(_ label: String, _ unit: String, _ binding: Binding<String>) -> some View {
        row(label) {
            HStack(spacing: 4) {
                TextField("0", text: binding)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                Text(unit).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

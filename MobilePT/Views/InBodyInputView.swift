import SwiftUI

struct InBodyInputView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var weight = ""
    @State private var height = ""
    @State private var muscle = ""
    @State private var fatMass = ""
    @State private var bmr = ""

    var body: some View {
        Form {
            Section {
                Button {
                    loadSample()
                } label: {
                    Label("샘플 데이터 불러오기", systemImage: "sparkles")
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.accent)
                }
            } footer: {
                Text("인바디 결과지가 없으면 샘플로 체험해보세요.")
            }

            Section {
                inputRow("체중", "kg", $weight)
                inputRow("키", "cm", $height)
                inputRow("골격근량", "kg", $muscle)
                inputRow("체지방량", "kg", $fatMass)
                inputRow("기초대사량", "kcal", $bmr)
            } header: {
                Text("체성분")
            } footer: {
                Text("BMI는 키·체중으로 자동 계산돼요.")
            }
        }
        .navigationTitle("인바디 입력")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button("저장하기") {
                save()
                dismiss()
            }
            .buttonStyle(EnergyButtonStyle(color: canContinue ? Theme.accent : Color(.systemGray3)))
            .disabled(!canContinue)
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private var canContinue: Bool {
        Double(weight) != nil && Double(height) != nil && Double(fatMass) != nil
    }

    private func inputRow(_ label: String, _ unit: String, _ binding: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            if !unit.isEmpty {
                Text(unit).foregroundColor(.secondary).frame(width: 36, alignment: .leading)
            } else {
                Spacer().frame(width: 36)
            }
        }
    }

    private func loadSample() {
        let s = InBodyResult.sample
        weight = String(Int(s.weight))
        height = String(Int(s.height))
        muscle = String(format: "%.1f", s.skeletalMuscleMass)
        fatMass = String(format: "%.1f", s.bodyFatMass)
        bmr = String(Int(s.bmr))
    }

    private func save() {
        let result = InBodyResult(
            weight: Double(weight) ?? 0,
            height: Double(height) ?? 0,
            skeletalMuscleMass: Double(muscle) ?? 0,
            bodyFatMass: Double(fatMass) ?? 0,
            bmr: Double(bmr) ?? 0
        )
        store.saveInBody(result)
    }
}

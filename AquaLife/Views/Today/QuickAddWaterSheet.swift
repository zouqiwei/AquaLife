import SwiftUI

struct QuickAddWaterSheet: View {
    let onAdd: (Double, Date, String?, WaterDrinkType) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""
    @State private var noteText = ""
    @State private var timestamp = Date()
    @State private var drinkType: WaterDrinkType = .water
    @FocusState private var isFocused: Bool

    private var parsedAmount: Double? {
        Double(inputText)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                    // Icon + title
                    VStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.waterGradient)
                        Text("自定义饮水量")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(.top, 24)

                    // Input
                    VStack(spacing: 8) {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            TextField("0", text: $inputText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.primary)
                                .frame(maxWidth: 200)
                                .focused($isFocused)
                            Text("ml")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        Rectangle()
                            .fill(AppTheme.primary.opacity(0.4))
                            .frame(height: 1)
                            .padding(.horizontal, 40)
                    }

                    // Presets
                    HStack(spacing: 10) {
                        ForEach([100, 200, 300, 400], id: \.self) { ml in
                            Button("\(ml)ml") {
                                inputText = "\(ml)"
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.primary.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }

                    HStack {
                        Text("饮品类型")
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Picker("", selection: $drinkType) {
                            ForEach(WaterDrinkType.allCases) { type in
                                Label(type.title, systemImage: type.systemImage).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppTheme.primary)
                    }
                    .padding(14)
                    .background(AppTheme.ringTrackColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 28)

                    DatePicker("记录时间", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                        .foregroundColor(AppTheme.textPrimary)
                        .tint(AppTheme.primary)
                        .padding(14)
                        .background(AppTheme.ringTrackColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 28)

                    TextField("备注（可选）", text: $noteText)
                        .textInputAutocapitalization(.never)
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(14)
                        .background(AppTheme.ringTrackColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 28)

                    Spacer()

                    // Confirm button
                    Button {
                        if let amount = parsedAmount, amount > 0 {
                            let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                            onAdd(amount, timestamp, note.isEmpty ? nil : note, drinkType)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("添加记录")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            parsedAmount != nil && parsedAmount! > 0
                            ? AnyShapeStyle(AppTheme.waterGradient)
                            : AnyShapeStyle(Color.gray.opacity(0.4))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(parsedAmount == nil || parsedAmount! <= 0)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .onAppear { isFocused = true }
    }
}

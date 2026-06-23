import SwiftUI

struct QuickAddWaterSheet: View {
    let onAdd: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""
    @FocusState private var isFocused: Bool

    private var parsedAmount: Double? {
        Double(inputText)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 32) {
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

                    Spacer()

                    // Confirm button
                    Button {
                        if let amount = parsedAmount, amount > 0 {
                            onAdd(amount)
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

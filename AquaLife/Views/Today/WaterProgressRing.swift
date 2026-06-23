import SwiftUI

struct WaterProgressRing: View {
    let current: Double
    let goal: Double

    private var progress: Double {
        min(current / goal, 1.0)
    }

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(AppTheme.ringTrackColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))

            // Progress arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [AppTheme.primaryDark, AppTheme.primary, AppTheme.secondary],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: AppTheme.primary.opacity(0.6), radius: 8, x: 0, y: 0)

            // Inner content
            VStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.waterGradient)

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                Text(progress >= 1.0 ? "🎉 达标！" : "继续加油")
                    .font(.system(size: 12))
                    .foregroundColor(progress >= 1.0 ? AppTheme.secondary : AppTheme.textSecondary)
            }

            // Water bubbles animation
            if progress > 0 {
                ForEach(0..<3, id: \.self) { i in
                    BubbleParticle(delay: Double(i) * 0.8)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.6)) {
                animatedProgress = newValue
            }
        }
    }
}

struct BubbleParticle: View {
    let delay: Double
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 0

    var body: some View {
        Circle()
            .fill(AppTheme.primary.opacity(0.4))
            .frame(width: 6, height: 6)
            .offset(x: CGFloat.random(in: -30...30), y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: false)
                        .delay(delay)
                ) {
                    opacity = 0
                    offset = -60
                }
                withAnimation(
                    Animation.easeIn(duration: 0.3)
                        .delay(delay)
                ) {
                    opacity = 0.6
                }
            }
    }
}

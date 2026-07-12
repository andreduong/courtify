import SwiftUI

struct SplashScreenView: View {
    let onContinue: () -> Void

    private let widgetImages = [
        "chart.bar.fill",
        "calendar",
        "trophy.fill",
        "tennisball.fill",
        "bell.badge.fill",
        "star.fill",
    ]

    var body: some View {
        ZStack {
            ThemeManager.midnightGreen.ignoresSafeArea()

            // Blurred widget collage
            GeometryReader { geo in
                ForEach(Array(widgetImages.enumerated()), id: \.offset) { index, symbol in
                    let positions: [(CGFloat, CGFloat, CGFloat)] = [
                        (0.15, 0.12, 0.9),
                        (0.72, 0.08, 1.1),
                        (0.08, 0.38, 0.85),
                        (0.78, 0.35, 1.0),
                        (0.25, 0.62, 0.95),
                        (0.68, 0.58, 1.05),
                    ]
                    let pos = positions[index % positions.count]

                    WidgetPreviewCard(symbol: symbol)
                        .frame(width: geo.size.width * 0.38, height: geo.size.width * 0.38)
                        .rotationEffect(.degrees(Double(index % 2 == 0 ? -8 : 8)))
                        .position(
                            x: geo.size.width * pos.0,
                            y: geo.size.height * pos.1
                        )
                        .scaleEffect(pos.2)
                        .blur(radius: 6)
                        .opacity(0.55)
                }
            }
            .allowsHitTesting(false)

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "tennisball.fill")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeManager.opticYellow)
                        .shadow(color: ThemeManager.emeraldGreen.opacity(0.6), radius: 20)

                    Text("Courtify")
                        .font(ThemeManager.roundedFont(.largeTitle, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Your courtside companion for live scores, stats, and Grand Slam drama.")
                        .font(ThemeManager.roundedFont(.body))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Button(action: onContinue) {
                    Text("Join Courtify")
                        .courtifyPrimaryButtonLabel(cornerRadius: 16, verticalPadding: 18)
                }
                .courtifyButton(.primary)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

private struct WidgetPreviewCard: View {
    let symbol: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(ThemeManager.opticYellow)

            RoundedRectangle(cornerRadius: 4)
                .fill(.white.opacity(0.2))
                .frame(height: 8)
                .padding(.horizontal, 12)

            RoundedRectangle(cornerRadius: 4)
                .fill(.white.opacity(0.12))
                .frame(height: 8)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassCard(cornerRadius: 24, padding: 16)
    }
}

#Preview {
    SplashScreenView(onContinue: {})
        .courtifyBackground()
}

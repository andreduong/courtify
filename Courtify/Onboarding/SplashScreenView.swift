import SwiftUI

struct SplashScreenView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            ThemeManager.midnightGreen.ignoresSafeArea()

            MarqueeWidgetBackground()
                .allowsHitTesting(false)
                .ignoresSafeArea()

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
        .onAppear {
            BundledImageCache.warmOnboardingAssets()
        }
    }
}

/// GPU-friendly infinite marquee: one pre-blurred sprite strip + transform-only animation.
/// Avoids per-frame blur/material work that caused jank on the splash screen.
private struct MarqueeWidgetBackground: View {
    private let rowCount = 4
    private let cardSize: CGFloat = 130
    private let stripWidth: CGFloat = 1440
    private let duration: Double = 28

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 24) {
                ForEach(0..<rowCount, id: \.self) { row in
                    MarqueeWidgetRow(
                        cardSize: cardSize,
                        stripWidth: stripWidth,
                        duration: duration + Double(row) * 4,
                        startOffset: CGFloat(row) * 72
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -geo.size.height * 0.05)
            .opacity(0.55)
        }
    }
}

private struct MarqueeWidgetRow: View {
    let cardSize: CGFloat
    let stripWidth: CGFloat
    let duration: Double
    let startOffset: CGFloat

    @State private var animate = false

    private var travelDistance: CGFloat { stripWidth }

    var body: some View {
        HStack(spacing: 0) {
            marqueeStrip
            marqueeStrip
        }
        .offset(x: (animate ? -travelDistance : 0) + startOffset)
        .onAppear {
            animate = false
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
        .frame(height: cardSize)
        .clipped()
    }

    private var marqueeStrip: some View {
        CachedBundledImage(name: "marquee-widget-strip", contentMode: .fill)
            .frame(width: stripWidth, height: cardSize)
            .clipped()
    }
}

#Preview {
    SplashScreenView(onContinue: {})
}

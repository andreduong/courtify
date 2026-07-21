import SwiftUI

/// Universal splash / loading / transition screen — starry backdrop, logo, wordmark, spinner.
/// Use for app bootstrap, onboarding hand-offs, and any future loading gate.
struct CourtifyLoadingScreen: View {
    var logoSize: CGFloat = 128

    var body: some View {
        ZStack {
            CourtifyStarryBackground()

            VStack(spacing: 16) {
                CourtifyLogoMark(size: logoSize)

                Text("Courtify")
                    .font(ThemeManager.roundedFont(.largeTitle, weight: .bold))
                    .foregroundStyle(.white)

                ProgressView()
                    .tint(ThemeManager.opticYellow)
                    .scaleEffect(1.1)
                    .padding(.top, 4)
            }
        }
        .onAppear {
            BundledImageCache.warmOnboardingAssets()
        }
    }
}

/// Starry night backdrop from onboarding celebration — shared by loading / transition surfaces.
struct CourtifyStarryBackground: View {
    var body: some View {
        ZStack {
            ThemeManager.oledBlack.ignoresSafeArea()

            Canvas { context, size in
                for index in 0..<90 {
                    let x = CGFloat((index * 73) % Int(size.width))
                    let y = CGFloat((index * 131) % Int(size.height))
                    let radius = CGFloat((index % 3) + 1) * 0.55
                    let rect = CGRect(x: x, y: y, width: radius, height: radius)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(Double((index % 5) + 2) / 12))
                    )
                }
            }
            .ignoresSafeArea()

            CourtifyAmbientGlow(
                primary: ThemeManager.emeraldGreen,
                secondary: ThemeManager.opticYellow,
                intensity: 0.7,
                anchor: .bottom
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.15), .clear, .black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

#Preview {
    CourtifyLoadingScreen()
}

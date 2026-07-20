import SwiftUI

struct SplashScreenView: View {
    let onContinue: () -> Void
    @ObservedObject private var appearance = AppAppearanceStore.shared

    var body: some View {
        ZStack {
            appearance.canvasColor.ignoresSafeArea()

            CourtifyMarqueeBackground()
                .allowsHitTesting(false)
                .ignoresSafeArea()

            // Match paywall: quiet the marquee so copy sits clearly on top.
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    CourtifyLogoMark(size: 72)

                    Text("Courtify")
                        .font(ThemeManager.roundedFont(.largeTitle, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.75), radius: 14, y: 2)
                        .shadow(color: .black.opacity(0.45), radius: 4, y: 1)

                    Text("Your courtside companion for live scores, stats, and Grand Slam drama.")
                        .font(ThemeManager.roundedFont(.body, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .shadow(color: .black.opacity(0.75), radius: 14, y: 2)
                        .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
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

#Preview {
    SplashScreenView(onContinue: {})
}

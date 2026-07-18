import SwiftUI

struct SplashScreenView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            ThemeManager.midnightGreen.ignoresSafeArea()

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
                    Image(systemName: "tennisball.fill")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeManager.opticYellow)
                        .shadow(color: ThemeManager.emeraldGreen.opacity(0.6), radius: 20)
                        .shadow(color: .black.opacity(0.55), radius: 10, y: 2)

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

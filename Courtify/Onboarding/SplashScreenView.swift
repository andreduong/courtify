import SwiftUI

struct SplashScreenView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            ThemeManager.midnightGreen.ignoresSafeArea()

            CourtifyMarqueeBackground()
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

#Preview {
    SplashScreenView(onContinue: {})
}

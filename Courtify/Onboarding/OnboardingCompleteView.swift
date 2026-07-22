import SwiftUI

struct OnboardingCompleteView: View {
    let favoritePlayerName: String?
    var referralUnlocked: Bool = false
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            CourtifyStarryBackground()

            VStack(spacing: 0) {
                Spacer()

                CourtifyLogoMark(size: 128)
                    .padding(.bottom, 56)

                Spacer()

                VStack(spacing: 14) {
                    Text(referralUnlocked ? "You're in!" : "You're All Set!")
                        .font(ThemeManager.roundedFont(.title, weight: .bold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(ThemeManager.roundedFont(.body))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                }
                .padding(.bottom, 36)

                Button(action: onContinue) {
                    Text("Get Started")
                        .courtifyPrimaryButtonLabel(verticalPadding: 18)
                }
                .courtifyButton(.primary)
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            BundledImageCache.warmOnboardingAssets()
        }
    }

    private var subtitle: String {
        if referralUnlocked {
            return "Premium unlocked — enjoy the full Courtify experience tailored to your picks."
        }
        if let favoritePlayerName, !favoritePlayerName.isEmpty {
            return "Great choice! We've saved \(favoritePlayerName) as your favorite player.\nGet ready for a personalised experience tailored just for you."
        }
        return "Great choice! We've saved your preferences.\nGet ready for a personalised experience tailored just for you."
    }
}

#Preview("Skip") {
    OnboardingCompleteView(favoritePlayerName: "Jannik Sinner", onContinue: {})
}

#Preview("Referral") {
    OnboardingCompleteView(favoritePlayerName: "Jannik Sinner", referralUnlocked: true, onContinue: {})
}

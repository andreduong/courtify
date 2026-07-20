import SwiftUI

struct OnboardingCompleteView: View {
    let favoritePlayerName: String?
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            OnboardingCelebrationBackground()

            VStack(spacing: 0) {
                Spacer()

                CourtifyLogoMark(size: 128)
                    .padding(.bottom, 56)

                Spacer()

                VStack(spacing: 14) {
                    Text("You're All Set!")
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
                        .font(ThemeManager.roundedFont(.headline, weight: .bold))
                        .foregroundStyle(ThemeManager.midnightGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .clipShape(Capsule())
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
        if let favoritePlayerName, !favoritePlayerName.isEmpty {
            return "Great choice! We've saved \(favoritePlayerName) as your favorite player.\nGet ready for a personalised experience tailored just for you."
        }
        return "Great choice! We've saved your preferences.\nGet ready for a personalised experience tailored just for you."
    }
}

private struct OnboardingCelebrationBackground: View {
    var body: some View {
        ZStack {
            ThemeManager.midnightGreen.ignoresSafeArea()

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

            RadialGradient(
                colors: [
                    ThemeManager.emeraldGreen.opacity(0.55),
                    ThemeManager.opticYellow.opacity(0.12),
                    .clear,
                ],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 420
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
    OnboardingCompleteView(favoritePlayerName: "Jannik Sinner", onContinue: {})
}

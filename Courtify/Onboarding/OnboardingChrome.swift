import SwiftUI

enum OnboardingProgress {
    static let totalSteps = 7

    static func stepIndex(for path: [OnboardingStep]) -> Int {
        guard let last = path.last else { return 0 }
        switch last {
        case .splash: return 0
        case .tourPreference: return 1
        case .favoritePlayers: return 2
        case .favoriteGrandSlam: return 3
        case .notifications: return 4
        case .referralCode: return 5
        case .paywall: return 6
        }
    }

    static func progress(for path: [OnboardingStep]) -> Double {
        Double(stepIndex(for: path)) / Double(totalSteps - 1)
    }
}

struct OnboardingChrome: View {
    let progress: Double
    let showsBackButton: Bool
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(progress: progress)

            if showsBackButton {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text("Back")
                                .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                    }
                    .courtifyButton(.ghost)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(CourtifyMotion.screen, value: showsBackButton)
        .animation(CourtifyMotion.screen, value: progress)
    }
}

private struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.12))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ThemeManager.opticYellow, ThemeManager.emeraldGreen],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geo.size.width * progress, progress > 0 ? 6 : 0))
            }
        }
        .frame(height: 2)
        .padding(.horizontal, 0)
    }
}

#Preview {
    ZStack {
        ThemeManager.midnightGreen.ignoresSafeArea()
        VStack {
            OnboardingChrome(progress: 0.6, showsBackButton: true, onBack: {})
            Spacer()
        }
    }
}

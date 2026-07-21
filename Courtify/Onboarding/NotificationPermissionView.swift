import SwiftUI

struct NotificationPermissionView: View {
    let favoritePlayerID: String
    let favoriteGrandSlam: String

    let onContinue: () -> Void

    @State private var isRequesting = false
    @State private var enableSuccessPulse = false

    private var playerName: String {
        TennisPlayer.displayName(for: favoritePlayerID) ?? "your favorite player"
    }

    private var tournamentName: String {
        GrandSlam(rawValue: favoriteGrandSlam)?.rawValue ?? "your favorite tournament"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Never miss a match")
                    .font(ThemeManager.roundedFont(.title, weight: .bold))
                    .foregroundStyle(.white)

                Text("Get alerts when \(playerName) plays and when \(tournamentName) is underway.")
                    .font(ThemeManager.roundedFont(.subheadline))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.top, 8)

            VStack(spacing: 12) {
                NotificationBenefitRow(
                    icon: "bell.badge.fill",
                    title: "Live match alerts",
                    subtitle: "Know the moment your player steps on court."
                )
                NotificationBenefitRow(
                    icon: "trophy.fill",
                    title: "Tournament updates",
                    subtitle: "Follow every round of \(tournamentName)."
                )
                NotificationBenefitRow(
                    icon: "sparkles",
                    title: "Personalized for you",
                    subtitle: "Only what matters based on your picks."
                )
            }

            Spacer()

            Button {
                enableSuccessPulse.toggle()
                Task { await enableNotifications() }
            } label: {
                Group {
                    if isRequesting {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("Enable Notifications")
                    }
                }
                .courtifyPrimaryButtonLabel(verticalPadding: 18)
            }
            .courtifyButton(.primary, enabled: !isRequesting)
            .sensoryFeedback(.success, trigger: enableSuccessPulse)

            Button(action: onContinue) {
                Text("Not now")
                    .font(ThemeManager.roundedFont(.headline, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .courtifyButton(.ghost)
            .disabled(isRequesting)
        }
        .padding(24)
    }

    private func enableNotifications() async {
        isRequesting = true
        defer { isRequesting = false }

        _ = await OfferNotificationManager.requestAuthorizationFromUser()
        onContinue()
    }
}

private struct NotificationBenefitRow: View {
    let icon: String
    let title: String
    let subtitle: String

    private let cornerRadius: CGFloat = 18

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(ThemeManager.brandYellow)
                .shadow(color: ThemeManager.brandYellow, radius: 4)
                .frame(width: 44, height: 44)
                .background(ThemeManager.brandYellow.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(ThemeManager.roundedFont(.headline, weight: .semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(ThemeManager.roundedFont(.caption))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        }
    }
}

#Preview {
    NotificationPermissionView(
        favoritePlayerID: "sinner",
        favoriteGrandSlam: GrandSlam.wimbledon.rawValue,
        onContinue: {}
    )
    .courtifyBackground()
}

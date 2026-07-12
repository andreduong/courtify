import SwiftUI

struct NotificationPermissionView: View {
    let favoritePlayerID: String
    let favoriteGrandSlam: String

    let onContinue: () -> Void

    @State private var isRequesting = false

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

            VStack(spacing: 14) {
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
                Task { await enableNotifications() }
            } label: {
                Group {
                    if isRequesting {
                        ProgressView()
                            .tint(ThemeManager.midnightGreen)
                    } else {
                        Text("Enable Notifications")
                    }
                }
                .courtifyPrimaryButtonLabel(cornerRadius: 16, verticalPadding: 18)
            }
            .courtifyButton(.primary, enabled: !isRequesting)

            Button(action: onContinue) {
                Text("Not now")
                    .courtifySecondaryButtonLabel(cornerRadius: 16)
            }
            .courtifyButton(.secondary)
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

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(ThemeManager.opticYellow)
                .frame(width: 40, height: 40)
                .background(ThemeManager.opticYellow.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ThemeManager.roundedFont(.headline, weight: .semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(ThemeManager.roundedFont(.caption))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
        .glassCard(cornerRadius: 16, padding: 16)
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

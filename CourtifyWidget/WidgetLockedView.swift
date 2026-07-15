import SwiftUI
import WidgetKit

struct WidgetLockedView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WidgetTheme.emeraldGreen.opacity(0.35), WidgetTheme.midnightGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetTheme.opticYellow)

                Text("Premium Widget")
                    .font(WidgetTheme.roundedFont(.headline, weight: .bold))
                    .foregroundStyle(.white)

                Text("Press to unlock.")
                    .font(WidgetTheme.roundedFont(.caption))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(12)
        }
        .courtifyWidgetCanvas()
        .widgetURL(CourtifyDeepLinks.paywallURL)
    }
}

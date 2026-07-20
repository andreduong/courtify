import SwiftUI
import WidgetKit

/// Home-screen locked Premium state — same CTA as Lock Screen accessories, no stamp.
struct WidgetLockedView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ZStack {
            WidgetTheme.midnightGreen

            Group {
                switch family {
                case .systemSmall:
                    compactLockedContent
                default:
                    wideLockedContent
                }
            }
            .padding(WidgetTheme.contentInset)
        }
        .courtifyWidgetCanvas(stamp: .none)
        .widgetURL(CourtifyDeepLinks.paywallURL)
    }

    private var compactLockedContent: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
            VStack(spacing: 2) {
                Text("Subscribe to")
                    .font(WidgetTheme.roundedFont(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                CourtifyWordmark(size: 18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var wideLockedContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))

            VStack(alignment: .leading, spacing: 2) {
                Text("Subscribe to")
                    .font(WidgetTheme.roundedFont(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                CourtifyWordmark(size: 20)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

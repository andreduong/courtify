import SwiftUI

/// Lock Screen accessory locked states — shared by WidgetKit and the in-app gallery.
struct LockScreenLockedCircular: View {
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
            Text("COURTIFY")
                .font(.system(size: 6.5, weight: .black, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

struct LockScreenLockedRectangular: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))

            VStack(alignment: .leading, spacing: 0) {
                Text("Subscribe to")
                    .font(WidgetTheme.roundedFont(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                CourtifyWordmark(size: 15)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}

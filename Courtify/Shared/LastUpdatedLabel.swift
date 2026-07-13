import SwiftUI

struct LastUpdatedLabel: View {
    let date: Date?
    var prefix: String = "Last updated"

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        if let date {
            Text("\(prefix) \(Self.formatter.string(from: date))")
                .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        } else {
            Text("Pull down to refresh")
                .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}

struct PullToRefreshHint: View {
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.circle")
                .font(.title2)
                .foregroundStyle(ThemeManager.opticYellow.opacity(0.8))
            Text(message)
                .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

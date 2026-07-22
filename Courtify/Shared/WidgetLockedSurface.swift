import SwiftUI
import WidgetKit

/// Layout buckets for the Premium locked widget — shared by WidgetKit and the
/// in-app gallery so paywalled previews match the real home-screen widget.
enum WidgetLockedLayout {
    case compact
    case wide
    case hero

    static func from(family: WidgetFamily) -> WidgetLockedLayout {
        switch family {
        case .systemSmall: return .compact
        case .systemLarge: return .hero
        default: return .wide
        }
    }

    static func from(catalogSize: CourtifyWidgetCatalog.Size) -> WidgetLockedLayout {
        switch catalogSize {
        case .small: return .compact
        case .medium: return .wide
        case .large: return .hero
        }
    }
}

/// OLED black + neon-grid locked state with a white Subscribe capsule.
struct WidgetLockedSurface: View {
    var layout: WidgetLockedLayout

    private static let oledBlack = Color(hex: 0x0B0B0D)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x16161A), Self.oledBlack],
                startPoint: .top,
                endPoint: .bottom
            )

            NeonGridOverlay(line: WidgetTheme.opticYellow)
                .opacity(0.8)

            LinearGradient(
                colors: [Color.white.opacity(0.20), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.16)
            )
            .blendMode(.plusLighter)
            .opacity(0.55)

            Group {
                switch layout {
                case .compact:
                    compactLockedContent
                case .wide:
                    wideLockedContent
                case .hero:
                    largeLockedContent
                }
            }
            .padding(WidgetTheme.contentInset)
        }
    }

    private var compactLockedContent: some View {
        VStack(spacing: 10) {
            lockBadge(size: 30, glyph: 12)

            VStack(spacing: 2) {
                Text("Unlock with")
                    .font(WidgetTheme.roundedFont(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                CourtifyWordmark(size: 15)
            }

            subscribePill(fontSize: 12, horizontalPadding: 18, verticalPadding: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var wideLockedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                lockBadge(size: 30, glyph: 12)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Unlock this widget with")
                        .font(WidgetTheme.roundedFont(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                    CourtifyWordmark(size: 17)
                }

                Spacer(minLength: 0)
            }

            subscribePill(fontSize: 13, horizontalPadding: 0, verticalPadding: 8, fullWidth: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var largeLockedContent: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            lockBadge(size: 44, glyph: 18)

            VStack(spacing: 3) {
                Text("Unlock this widget with")
                    .font(WidgetTheme.roundedFont(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                CourtifyWordmark(size: 22)
            }

            subscribePill(fontSize: 14, horizontalPadding: 34, verticalPadding: 9)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func lockBadge(size: CGFloat, glyph: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
            Circle()
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            Image(systemName: "lock.fill")
                .font(.system(size: glyph, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(width: size, height: size)
    }

    private func subscribePill(
        fontSize: CGFloat,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat,
        fullWidth: Bool = false
    ) -> some View {
        Text("Subscribe")
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(Self.oledBlack)
            .padding(.horizontal, fullWidth ? 0 : horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background {
                Capsule().fill(Color.white)
            }
            .shadow(color: WidgetTheme.opticYellow.opacity(0.25), radius: 10)
    }
}

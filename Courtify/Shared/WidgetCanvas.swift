import SwiftUI

/// Corner / edge placement for the home-screen “made by courtify” stamp.
/// Lock Screen accessories use `.none` — circular/rectangular have no room.
enum WidgetStampPlacement: Equatable {
    case bottomLeading
    case bottomTrailing
    case bottomCenter
    case none

    var alignment: Alignment {
        switch self {
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        case .bottomCenter: return .bottom
        case .none: return .bottomTrailing
        }
    }
}

/// Tiny brand stamp for home-screen WidgetKit canvases (not in-app gallery previews).
struct WidgetMadeByStamp: View {
    var body: some View {
        Text("made by courtify")
            .font(WidgetTheme.roundedFont(size: 7.5, weight: .bold))
            .foregroundStyle(.white)
            .tracking(0.4)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.58), in: Capsule())
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct ShowsWidgetMadeByStampKey: EnvironmentKey {
    /// Off by default so in-app gallery / marquee / share stay clean.
    /// WidgetKit entry containers set `true` for home-screen canvases.
    static let defaultValue = false
}

extension EnvironmentValues {
    /// When `false`, `.courtifyWidgetCanvas` omits the watermark (in-app gallery default).
    var showsWidgetMadeByStamp: Bool {
        get { self[ShowsWidgetMadeByStampKey.self] }
        set { self[ShowsWidgetMadeByStampKey.self] = newValue }
    }
}

extension View {
    /// Enable the “made by courtify” stamp on real home-screen WidgetKit canvases.
    func courtifyHomeWidgetStampEnabled() -> some View {
        environment(\.showsWidgetMadeByStamp, true)
    }
}

extension WidgetTheme {
    /// Inset from the canvas edge (clears continuous corner masks).
    static let stampEdgeInset: CGFloat = 8
}

extension View {
    /// Fills the home-screen widget canvas edge to edge and overlays the Courtify stamp.
    /// Pass `stamp: .none` for Lock Screen accessories (too small for text).
    /// In-app gallery / share previews set `.environment(\.showsWidgetMadeByStamp, false)`.
    ///
    /// Content must use `WidgetTheme.contentInsets` (not bare `contentInset`) so copy
    /// clears the stamp while backgrounds stay full-bleed.
    ///
    /// **Rule:** every new home-screen widget view must end with `.courtifyWidgetCanvas()`
    /// (or an explicit placement). Do not hand-roll a second watermark.
    func courtifyWidgetCanvas(stamp: WidgetStampPlacement = .bottomTrailing) -> some View {
        modifier(CourtifyWidgetCanvasModifier(stamp: stamp))
    }
}

private struct CourtifyWidgetCanvasModifier: ViewModifier {
    var stamp: WidgetStampPlacement
    @Environment(\.showsWidgetMadeByStamp) private var showsStamp

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: stamp.alignment) {
                if stamp != .none, showsStamp {
                    WidgetMadeByStamp()
                        .padding(.horizontal, WidgetTheme.stampEdgeInset)
                        .padding(.bottom, WidgetTheme.stampEdgeInset)
                }
            }
    }
}

// MARK: - Gallery chrome

/// Glass lock control for Premium-gated widget gallery chrome.
struct CourtifyGlassLockBadge: View {
    var systemImage: String = "lock.fill"
    var size: CGFloat = 11

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(8)
            .background {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                    Circle()
                        .fill(.thinMaterial)
                }
            }
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5)
            }
            .accessibilityLabel("Premium")
    }
}

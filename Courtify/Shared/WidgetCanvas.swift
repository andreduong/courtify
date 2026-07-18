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

/// Tiny brand stamp for every home-screen widget (gallery + WidgetKit).
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

extension WidgetTheme {
    /// Inset from the canvas edge (clears continuous corner masks).
    static let stampEdgeInset: CGFloat = 8
}

extension View {
    /// Fills the home-screen widget canvas edge to edge and overlays the Courtify stamp.
    /// Pass `stamp: .none` for Lock Screen accessories (too small for text).
    ///
    /// Content must use `WidgetTheme.contentInsets` (not bare `contentInset`) so copy
    /// clears the stamp while backgrounds stay full-bleed.
    ///
    /// **Rule:** every new home-screen widget view must end with `.courtifyWidgetCanvas()`
    /// (or an explicit placement). Do not hand-roll a second watermark.
    func courtifyWidgetCanvas(stamp: WidgetStampPlacement = .bottomTrailing) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: stamp.alignment) {
                if stamp != .none {
                    WidgetMadeByStamp()
                        .padding(.horizontal, WidgetTheme.stampEdgeInset)
                        .padding(.bottom, WidgetTheme.stampEdgeInset)
                }
            }
    }
}

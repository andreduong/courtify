import SwiftUI

extension View {
    /// Fills the home-screen widget canvas edge to edge.
    func courtifyWidgetCanvas() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

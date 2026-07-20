import SwiftUI

/// Bundled Courtify app logo — black tile + seams fixed; only the ball tint follows **Logo ball** in Settings.
struct CourtifyLogoMark: View {
    var size: CGFloat = 120
    /// When set, shows that preset instead of the live **Logo ball** setting (e.g. picker rows).
    var preset: LogoBallPreset? = nil
    @ObservedObject private var appearance = AppAppearanceStore.shared

    private var effectivePreset: LogoBallPreset { preset ?? appearance.logoBall }
    private var cornerRadius: CGFloat { size * 0.22 }

    var body: some View {
        Group {
            if let uiImage = CourtifyLogoRenderer.image(for: effectivePreset) {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
            } else {
                Image("courtify-logo")
                    .resizable()
                    .interpolation(.high)
            }
        }
        .id(effectivePreset)
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: effectivePreset.color.opacity(0.35), radius: size * 0.14, y: size * 0.06)
        .shadow(color: .black.opacity(0.3), radius: size * 0.05, y: size * 0.02)
    }
}

#Preview {
    CourtifyLogoMark(size: 128)
        .padding()
        .background(Color.gray.opacity(0.2))
}

import SwiftUI

/// In-app Courtify mark — mirrors the home-screen icon (black tile + colored ball + seams).
struct CourtifyLogoMark: View {
    var size: CGFloat = 120
    @ObservedObject private var appearance = AppAppearanceStore.shared

    private var cornerRadius: CGFloat { size * 0.22 }
    private var ballSize: CGFloat { size * 0.78 }
    private var seamWidth: CGFloat { max(2, size * 0.055) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.black)

            Circle()
                .fill(appearance.logoBallColor)
                .frame(width: ballSize, height: ballSize)

            TennisBallSeams()
                .stroke(
                    Color.black,
                    style: StrokeStyle(lineWidth: seamWidth, lineCap: .round, lineJoin: .round)
                )
                .frame(width: ballSize, height: ballSize)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: appearance.logoBallColor.opacity(0.45), radius: size * 0.22, y: size * 0.08)
        .shadow(color: .black.opacity(0.35), radius: size * 0.06, y: size * 0.02)
    }
}

private struct TennisBallSeams: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.73, y: h * 0.07))
        path.addCurve(
            to: CGPoint(x: w * 0.73, y: h * 0.93),
            control1: CGPoint(x: w * 1.08, y: h * 0.34),
            control2: CGPoint(x: w * 1.08, y: h * 0.66)
        )

        path.move(to: CGPoint(x: w * 0.27, y: h * 0.07))
        path.addCurve(
            to: CGPoint(x: w * 0.27, y: h * 0.93),
            control1: CGPoint(x: w * -0.08, y: h * 0.34),
            control2: CGPoint(x: w * -0.08, y: h * 0.66)
        )

        return path
    }
}

#Preview {
    CourtifyLogoMark(size: 128)
        .padding()
        .background(Color.gray.opacity(0.2))
}

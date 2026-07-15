import SwiftUI

/// GPU-friendly infinite marquee used on the onboarding splash and paywall.
struct CourtifyMarqueeBackground: View {
    var opacity: Double = 0.55

    private let rowCount = 4
    private let cardSize: CGFloat = 130
    private let stripWidth: CGFloat = 1440
    private let duration: Double = 28

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 24) {
                ForEach(0..<rowCount, id: \.self) { row in
                    MarqueeWidgetRow(
                        cardSize: cardSize,
                        stripWidth: stripWidth,
                        duration: duration + Double(row) * 4,
                        startOffset: CGFloat(row) * 72
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -geo.size.height * 0.05)
            .opacity(opacity)
        }
    }
}

private struct MarqueeWidgetRow: View {
    let cardSize: CGFloat
    let stripWidth: CGFloat
    let duration: Double
    let startOffset: CGFloat

    @State private var animate = false

    private var travelDistance: CGFloat { stripWidth }

    var body: some View {
        HStack(spacing: 0) {
            marqueeStrip
            marqueeStrip
        }
        .offset(x: (animate ? -travelDistance : 0) + startOffset)
        .onAppear {
            animate = false
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
        .frame(height: cardSize)
        .clipped()
    }

    private var marqueeStrip: some View {
        CachedBundledImage(name: "marquee-widget-strip", contentMode: .fill)
            .frame(width: stripWidth, height: cardSize)
            .clipped()
    }
}

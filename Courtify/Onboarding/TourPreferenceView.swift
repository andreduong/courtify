import SwiftUI

struct TourPreferenceView: View {
    @Binding var tourPreference: TourPreference
    let onContinue: () -> Void

    @State private var confirmedPreference: TourPreference?
    @State private var successPulse = 0

    private let gridSpacing: CGFloat = 16
    private let cardHeight: CGFloat = 158
    private let cornerRadius: CGFloat = 20

    private var hasSelection: Bool { confirmedPreference != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Which tour do you follow?")
                    .font(ThemeManager.roundedFont(.title, weight: .bold))
                    .foregroundStyle(.white)

                Text("We'll tailor scores, news, and favorites to your pick.")
                    .font(ThemeManager.roundedFont(.subheadline))
                    .foregroundStyle(.white.opacity(0.65))

                Text("Hold a card to lock your pick")
                    .font(ThemeManager.roundedFont(.caption, weight: .semibold))
                    .foregroundStyle(ThemeManager.brandYellow.opacity(0.85))
                    .padding(.top, 2)
            }
            .padding(.top, 8)

            GeometryReader { geo in
                let cardWidth = max(0, (geo.size.width - gridSpacing) / 2)
                VStack(spacing: gridSpacing) {
                    HStack(spacing: gridSpacing) {
                        tourCard(.atp, width: cardWidth)
                        tourCard(.wta, width: cardWidth)
                    }

                    tourCard(.both, width: cardWidth)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(height: cardHeight * 2 + gridSpacing)

            Spacer()

            if hasSelection {
                Button(action: onContinue) {
                    Text("Continue")
                        .courtifyPrimaryButtonLabel()
                }
                .courtifyButton(.primary)
            } else {
                Text("Hold to continue")
                    .courtifyDormantButtonLabel()
            }
        }
        .padding(24)
        .sensoryFeedback(.success, trigger: successPulse)
        .courtifySelectionFeedback(confirmedPreference)
    }

    private func tourCard(_ preference: TourPreference, width: CGFloat) -> some View {
        TourPreferenceCard(
            preference: preference,
            isSelected: confirmedPreference == preference,
            cornerRadius: cornerRadius,
            onLongPressComplete: { commitSelection(preference) }
        )
        .frame(width: width, height: cardHeight)
    }

    private func commitSelection(_ preference: TourPreference) {
        CourtifyMotion.animateSelection {
            confirmedPreference = preference
            tourPreference = preference
        }
        successPulse &+= 1
    }
}

// MARK: - Card

private struct TourPreferenceCard: View {
    let preference: TourPreference
    let isSelected: Bool
    let cornerRadius: CGFloat
    let onLongPressComplete: () -> Void

    @State private var fillProgress: CGFloat = 0
    @State private var isPressing = false
    @State private var fillTask: Task<Void, Never>?
    @State private var tickPulse = 0
    @State private var showBurst = false

    private let holdDuration: TimeInterval = 0.7

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: preference.icon)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(iconColor)
                .shadow(
                    color: isSelected || fillProgress > 0.4
                        ? ThemeManager.brandYellow.opacity(0.45)
                        : .clear,
                    radius: 8
                )

            Text(preference.rawValue)
                .font(ThemeManager.roundedFont(.title3, weight: .bold))
                .foregroundStyle(.white)

            Text(preference.subtitle)
                .font(ThemeManager.roundedFont(.caption))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            // Bottom-up neon fill while holding.
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ThemeManager.brandYellow.opacity(0.55),
                                    ThemeManager.brandYellow.opacity(0.18),
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: geo.size.height * fillProgress)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .allowsHitTesting(false)
        }
        .overlay {
            if showBurst && isSelected {
                TourSelectBurst()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    isSelected || fillProgress > 0
                        ? ThemeManager.brandYellow
                        : ThemeManager.glassEdge,
                    lineWidth: isSelected || fillProgress > 0.85 ? 1.5 : ThemeManager.glassEdgeWidth
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .scaleEffect(isSelected ? CourtifyMotion.selectedScale : (isPressing ? 0.97 : 1))
        .shadow(
            color: isSelected
                ? ThemeManager.brandYellow.opacity(0.35)
                : ThemeManager.brandYellow.opacity(0.2 * fillProgress),
            radius: isSelected ? 16 : (10 * fillProgress)
        )
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginHoldIfNeeded() }
                .onEnded { _ in cancelHoldIfNeeded() }
        )
        .animation(CourtifyMotion.selection, value: isSelected)
        .animation(CourtifyMotion.press, value: isPressing)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.45), trigger: tickPulse)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Hold to select")
        .onChange(of: isSelected) { _, selected in
            if selected {
                fillProgress = 0
                isPressing = false
                triggerBurst()
            } else {
                showBurst = false
            }
        }
        .onDisappear {
            fillTask?.cancel()
            fillTask = nil
        }
    }

    private var iconColor: Color {
        if isSelected || fillProgress > 0.35 {
            return ThemeManager.brandYellow
        }
        return .white.opacity(0.7)
    }

    private func beginHoldIfNeeded() {
        guard fillTask == nil, !isSelected else { return }
        isPressing = true
        withAnimation(.linear(duration: holdDuration)) {
            fillProgress = 1
        }
        fillTask = Task { @MainActor in
            let ticks = 8
            for _ in 1...ticks {
                try? await Task.sleep(for: .milliseconds(Int(holdDuration * 1000) / ticks))
                guard !Task.isCancelled else { return }
                tickPulse &+= 1
            }
            guard !Task.isCancelled else { return }
            fillTask = nil
            isPressing = false
            fillProgress = 0
            onLongPressComplete()
        }
    }

    private func cancelHoldIfNeeded() {
        guard fillTask != nil else { return }
        fillTask?.cancel()
        fillTask = nil
        isPressing = false
        withAnimation(CourtifyMotion.exit) {
            fillProgress = 0
        }
    }

    private func triggerBurst() {
        withAnimation(CourtifyMotion.reveal) {
            showBurst = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(CourtifyMotion.exit) {
                showBurst = false
            }
        }
    }
}

// MARK: - Congrats burst

private struct TourSelectBurst: View {
    @State private var expand = false

    private let rays = Array(0..<10)

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ThemeManager.brandYellow.opacity(0.35),
                            ThemeManager.brandYellow.opacity(0),
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: expand ? 90 : 20
                    )
                )
                .scaleEffect(expand ? 1.15 : 0.4)
                .opacity(expand ? 0 : 1)

            ForEach(rays, id: \.self) { index in
                Capsule()
                    .fill(ThemeManager.brandYellow.opacity(expand ? 0 : 0.9))
                    .frame(width: 3, height: expand ? 28 : 8)
                    .offset(y: expand ? -54 : -16)
                    .rotationEffect(.degrees(Double(index) / Double(rays.count) * 360))

                Circle()
                    .fill(ThemeManager.brandYellow)
                    .frame(width: expand ? 4 : 6, height: expand ? 4 : 6)
                    .offset(y: expand ? -72 : -22)
                    .rotationEffect(.degrees(Double(index) / Double(rays.count) * 360 + 18))
                    .opacity(expand ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(CourtifyMotion.reveal) {
                expand = true
            }
        }
    }
}

#Preview {
    TourPreferenceView(tourPreference: .constant(.both), onContinue: {})
        .courtifyBackground()
}

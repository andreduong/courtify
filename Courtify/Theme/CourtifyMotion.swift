import SwiftUI

// MARK: - Motion Tokens

/// Central motion + press system for Courtify. Apply via `.courtifyButton(...)`
/// (or the app-root default) so every control shares the same haptic and spring.
enum CourtifyMotion {
    enum Direction {
        case forward
        case backward
    }

    // Springs tuned for native iOS interactive motion.
    static let screen = Animation.spring(response: 0.44, dampingFraction: 0.88, blendDuration: 0.08)
    static let press = Animation.interactiveSpring(response: 0.22, dampingFraction: 0.72, blendDuration: 0.05)
    static let selection = Animation.spring(response: 0.34, dampingFraction: 0.82)
    static let modal = Animation.spring(response: 0.4, dampingFraction: 0.86)
    static let reveal = Animation.spring(response: 0.5, dampingFraction: 0.9)
    static let exit = Animation.spring(response: 0.36, dampingFraction: 0.92)

    static let pressedScalePrimary: CGFloat = 0.968
    static let pressedScaleCard: CGFloat = 0.982
    static let pressedScaleIcon: CGFloat = 0.88
    static let pressedScaleGhost: CGFloat = 0.975
    static let selectedScale: CGFloat = 1.02

    /// Soft impact on touch-down — matches system control feel (iOS 17+).
    static func pressFeedback(for style: CourtifyPressStyle) -> SensoryFeedback {
        switch style {
        case .primary, .secondary:
            .impact(flexibility: .soft, intensity: 0.9)
        case .card:
            .impact(flexibility: .soft, intensity: 0.55)
        case .icon:
            .impact(flexibility: .soft, intensity: 0.75)
        case .ghost, .row:
            .impact(flexibility: .soft, intensity: 0.5)
        }
    }

    static func screenTransition(_ direction: Direction) -> AnyTransition {
        switch direction {
        case .forward:
            AnyTransition.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            AnyTransition.asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    static var modalPresent: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.94).combined(with: .opacity),
            removal: .scale(scale: 0.98).combined(with: .opacity)
        )
    }

    static var modalDismiss: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.96))
    }

    static var crossfade: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.98))
    }

    static func animateScreen(_ direction: Direction, _ changes: () -> Void) {
        var transaction = Transaction(animation: screen)
        transaction.disablesAnimations = false
        withTransaction(transaction) {
            changes()
        }
    }

    static func animateSelection(_ changes: () -> Void) {
        withAnimation(selection, changes)
    }

    static func animateModal(_ changes: () -> Void) {
        withAnimation(modal, changes)
    }
}

// MARK: - Button Styles

enum CourtifyPressStyle: Equatable {
    /// Filled CTAs (Join, Continue, Subscribe).
    case primary
    /// Outlined / secondary CTAs.
    case secondary
    /// Large tappable cards and list rows.
    case card
    /// Text / pill chrome with light press.
    case ghost
    /// Circular icon buttons (profile, close).
    case icon
    /// Full-width list rows (rankings, schedule) — subtle scale.
    case row
}

struct CourtifyPressButtonStyle: ButtonStyle {
    var style: CourtifyPressStyle = .ghost
    /// Optional override; defaults to the environment `isEnabled`.
    var isEnabled: Bool? = nil

    @Environment(\.isEnabled) private var environmentEnabled

    private var effectivelyEnabled: Bool {
        isEnabled ?? environmentEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scale(isPressed: configuration.isPressed))
            .opacity(opacity(isPressed: configuration.isPressed))
            .brightness(configuration.isPressed && effectivelyEnabled ? -0.025 : 0)
            .animation(CourtifyMotion.press, value: configuration.isPressed)
            .sensoryFeedback(
                CourtifyMotion.pressFeedback(for: style),
                trigger: configuration.isPressed
            ) { _, isPressed in
                isPressed && effectivelyEnabled
            }
    }

    private func scale(isPressed: Bool) -> CGFloat {
        guard effectivelyEnabled, isPressed else { return 1 }

        switch style {
        case .primary, .secondary:
            return CourtifyMotion.pressedScalePrimary
        case .card:
            return CourtifyMotion.pressedScaleCard
        case .icon:
            return CourtifyMotion.pressedScaleIcon
        case .ghost:
            return CourtifyMotion.pressedScaleGhost
        case .row:
            return CourtifyMotion.pressedScaleCard
        }
    }

    private func opacity(isPressed: Bool) -> Double {
        if !effectivelyEnabled { return 0.5 }
        return isPressed ? 0.92 : 1
    }
}

extension ButtonStyle where Self == CourtifyPressButtonStyle {
    static var courtify: CourtifyPressButtonStyle { CourtifyPressButtonStyle() }

    static func courtify(_ style: CourtifyPressStyle, enabled: Bool? = nil) -> CourtifyPressButtonStyle {
        CourtifyPressButtonStyle(style: style, isEnabled: enabled)
    }
}

// MARK: - Screen Flow

struct CourtifyScreenFlow<Step: Hashable, Root: View, Destination: View>: View {
    @Binding var path: [Step]
    @Binding var direction: CourtifyMotion.Direction

    @ViewBuilder let root: () -> Root
    @ViewBuilder let destination: (Step) -> Destination

    var body: some View {
        ZStack {
            if path.isEmpty {
                root()
                    .transition(CourtifyMotion.screenTransition(.backward))
                    .zIndex(0)
            } else if let step = path.last {
                destination(step)
                    .transition(CourtifyMotion.screenTransition(direction))
                    .zIndex(1)
            }
        }
        .animation(CourtifyMotion.screen, value: path)
    }
}

// MARK: - View Modifiers

private struct CourtifySelectionModifier: ViewModifier {
    let isSelected: Bool
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(isSelected ? scale : 1)
            .animation(CourtifyMotion.selection, value: isSelected)
            .sensoryFeedback(.selection, trigger: isSelected) { _, selected in
                selected
            }
    }
}

private struct CourtifyPrimaryButtonLabelModifier: ViewModifier {
    var cornerRadius: CGFloat = 14
    var verticalPadding: CGFloat = 16
    var isFilled: Bool = true
    var fillOpacity: Double = 1
    @ObservedObject private var appearance = AppAppearanceStore.shared

    func body(content: Content) -> some View {
        content
            .font(ThemeManager.roundedFont(.headline, weight: .semibold))
            .foregroundStyle(isFilled ? appearance.canvasColor : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background {
                if isFilled {
                    appearance.accentColor.opacity(fillOpacity)
                } else {
                    Color.white.opacity(0.12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    /// Shared press scale + soft haptic. Prefer this on every `Button` / `NavigationLink`.
    func courtifyButton(_ style: CourtifyPressStyle = .primary, enabled: Bool = true) -> some View {
        buttonStyle(.courtify(style, enabled: enabled))
    }

    /// App-root default so unlabeled buttons still get Courtify press feedback.
    func courtifyInteractiveChrome() -> some View {
        buttonStyle(.courtify(.ghost))
    }

    func courtifySelection(_ isSelected: Bool, scale: CGFloat = CourtifyMotion.selectedScale) -> some View {
        modifier(CourtifySelectionModifier(isSelected: isSelected, scale: scale))
    }

    /// Selection haptic when a discrete value changes (tabs, toggles, tour pills).
    func courtifySelectionFeedback<T: Equatable>(_ trigger: T) -> some View {
        sensoryFeedback(.selection, trigger: trigger)
    }

    func courtifyPrimaryButtonLabel(
        cornerRadius: CGFloat = 14,
        verticalPadding: CGFloat = 16,
        fillOpacity: Double = 1
    ) -> some View {
        modifier(
            CourtifyPrimaryButtonLabelModifier(
                cornerRadius: cornerRadius,
                verticalPadding: verticalPadding,
                isFilled: true,
                fillOpacity: fillOpacity
            )
        )
    }

    func courtifySecondaryButtonLabel(cornerRadius: CGFloat = 12) -> some View {
        modifier(
            CourtifyPrimaryButtonLabelModifier(
                cornerRadius: cornerRadius,
                verticalPadding: 14,
                isFilled: false,
                fillOpacity: 1
            )
        )
    }

    func courtifyScreenContent() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    func courtifyModalBackdrop() -> some View {
        self
            .background(Color.black.opacity(0.65).ignoresSafeArea())
    }
}

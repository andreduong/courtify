import SwiftUI
import UIKit

// MARK: - Motion Tokens

/// Central motion system for Courtify. Apply via view modifiers and button styles
/// so animations stay consistent across onboarding, paywall, and home.
enum CourtifyMotion {
    enum Direction {
        case forward
        case backward
    }

    // Springs tuned for iOS-style interactive motion.
    static let screen = Animation.spring(response: 0.44, dampingFraction: 0.88, blendDuration: 0.08)
    static let press = Animation.spring(response: 0.26, dampingFraction: 0.74)
    static let selection = Animation.spring(response: 0.34, dampingFraction: 0.82)
    static let modal = Animation.spring(response: 0.4, dampingFraction: 0.86)
    static let reveal = Animation.spring(response: 0.5, dampingFraction: 0.9)
    static let exit = Animation.spring(response: 0.36, dampingFraction: 0.92)

    static let pressedScalePrimary: CGFloat = 0.972
    static let pressedScaleCard: CGFloat = 0.985
    static let pressedScaleIcon: CGFloat = 0.9
    static let selectedScale: CGFloat = 1.02

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

enum CourtifyPressStyle {
    case primary
    case secondary
    case card
    case ghost
    case icon
}

struct CourtifyPressButtonStyle: ButtonStyle {
    let style: CourtifyPressStyle
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scale(isPressed: configuration.isPressed))
            .opacity(opacity(isPressed: configuration.isPressed))
            .brightness(configuration.isPressed && isEnabled ? -0.03 : 0)
            .animation(CourtifyMotion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && isEnabled {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }

    private func scale(isPressed: Bool) -> CGFloat {
        guard isEnabled else { return 1 }
        guard isPressed else { return 1 }

        switch style {
        case .primary, .secondary, .ghost:
            return CourtifyMotion.pressedScalePrimary
        case .card:
            return CourtifyMotion.pressedScaleCard
        case .icon:
            return CourtifyMotion.pressedScaleIcon
        }
    }

    private func opacity(isPressed: Bool) -> Double {
        if !isEnabled { return 0.5 }
        return isPressed ? 0.94 : 1
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
    }
}

private struct CourtifyPrimaryButtonLabelModifier: ViewModifier {
    var cornerRadius: CGFloat = 14
    var verticalPadding: CGFloat = 16
    var isFilled: Bool = true
    var fillOpacity: Double = 1

    func body(content: Content) -> some View {
        content
            .font(ThemeManager.roundedFont(.headline, weight: .semibold))
            .foregroundStyle(isFilled ? ThemeManager.midnightGreen : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background {
                if isFilled {
                    ThemeManager.opticYellow.opacity(fillOpacity)
                } else {
                    Color.white.opacity(0.12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func courtifyButton(_ style: CourtifyPressStyle = .primary, enabled: Bool = true) -> some View {
        buttonStyle(CourtifyPressButtonStyle(style: style, isEnabled: enabled))
    }

    func courtifySelection(_ isSelected: Bool, scale: CGFloat = CourtifyMotion.selectedScale) -> some View {
        modifier(CourtifySelectionModifier(isSelected: isSelected, scale: scale))
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

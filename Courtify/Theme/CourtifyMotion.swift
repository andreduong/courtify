import SwiftUI
import UIKit

// MARK: - Motion Tokens

/// Central motion + press system for Courtify. Apply via `.courtifyButton(...)`
/// (or the app-root `.courtifyInteractiveChrome()`) so every control — and every
/// non-button surface tap — shares the same haptic and spring.
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

    static let pressedScalePrimary: CGFloat = 0.96
    static let pressedScaleCard: CGFloat = 0.97
    static let pressedScaleIcon: CGFloat = 0.88
    static let pressedScaleGhost: CGFloat = 0.96
    static let pressedScaleRow: CGFloat = 0.978
    /// Whole-surface press (non-button taps) — subtle so scrollable screens stay calm.
    static let pressedScaleSurface: CGFloat = 0.991
    static let selectedScale: CGFloat = 1.03

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

    /// Soft tap for empty canvas / non-control presses (buttons keep their own haptic).
    static var surfacePressFeedback: SensoryFeedback {
        .impact(flexibility: .soft, intensity: 0.4)
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
            return CourtifyMotion.pressedScaleRow
        }
    }

    private func opacity(isPressed: Bool) -> Double {
        if !effectivelyEnabled { return 0.5 }
        return isPressed ? 0.9 : 1
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

/// Default `Button` press style + installs the window-level surface press once.
/// Nested calls are safe (gesture is idempotent per window).
private struct CourtifyInteractiveChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.courtify(.ghost))
            .background {
                CourtifyWindowPressInstaller()
            }
    }
}

/// Passive window gesture: soft scale + dim on *any* touch (including non-buttons),
/// cancelled when the finger moves (scroll). Does not steal taps from controls.
private struct CourtifyWindowPressInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        context.coordinator.hostView = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.hostView = uiView
        context.coordinator.attachIfNeeded()
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.hostView = nil
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var hostView: UIView?

        func attachIfNeeded() {
            guard let window = hostView?.window else { return }
            CourtifyWindowSurfacePress.shared.install(on: window, delegate: self)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }
    }
}

/// Singleton per-window press feedback so the entire app (including sheets) animates
/// without stacking SwiftUI `scaleEffect` modifiers.
@MainActor
private final class CourtifyWindowSurfacePress: NSObject {
    static let shared = CourtifyWindowSurfacePress()

    private weak var window: UIWindow?
    private var recognizer: UILongPressGestureRecognizer?
    private weak var dimView: UIView?
    private var pressOrigin: CGPoint = .zero
    private var isPressed = false
    private let moveSlop: CGFloat = 10
    private let haptic = UIImpactFeedbackGenerator(style: .soft)

    func install(on window: UIWindow, delegate: UIGestureRecognizerDelegate) {
        if self.window === window, recognizer != nil {
            recognizer?.delegate = delegate
            return
        }

        if let recognizer, let old = self.window {
            old.removeGestureRecognizer(recognizer)
        }
        dimView?.removeFromSuperview()
        dimView = nil
        resetVisuals(animated: false)

        let gesture = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handlePress(_:))
        )
        gesture.minimumPressDuration = 0
        gesture.cancelsTouchesInView = false
        gesture.delaysTouchesBegan = false
        gesture.delaysTouchesEnded = false
        gesture.delegate = delegate
        window.addGestureRecognizer(gesture)

        self.window = window
        recognizer = gesture
        haptic.prepare()
    }

    @objc private func handlePress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            pressOrigin = gesture.location(in: gesture.view)
            setPressed(true)
        case .changed:
            let point = gesture.location(in: gesture.view)
            let dx = point.x - pressOrigin.x
            let dy = point.y - pressOrigin.y
            if hypot(dx, dy) > moveSlop {
                setPressed(false)
                gesture.isEnabled = false
                gesture.isEnabled = true
            }
        case .ended, .cancelled, .failed:
            setPressed(false)
        default:
            break
        }
    }

    private func setPressed(_ pressed: Bool) {
        guard isPressed != pressed else { return }
        isPressed = pressed
        if pressed {
            haptic.impactOccurred(intensity: 0.4)
            haptic.prepare()
            applyPressedVisuals()
        } else {
            resetVisuals(animated: true)
        }
    }

    private func applyPressedVisuals() {
        guard let window else { return }
        let target = window.rootViewController?.view ?? window

        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
        ) {
            target.transform = CGAffineTransform(
                scaleX: CourtifyMotion.pressedScaleSurface,
                y: CourtifyMotion.pressedScaleSurface
            )
        }

        let dim = dimView ?? {
            let view = UIView(frame: window.bounds)
            view.backgroundColor = UIColor.black.withAlphaComponent(0.05)
            view.isUserInteractionEnabled = false
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.alpha = 0
            window.addSubview(view)
            dimView = view
            return view
        }()
        dim.frame = window.bounds
        window.bringSubviewToFront(dim)

        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
        ) {
            dim.alpha = 1
        }
    }

    private func resetVisuals(animated: Bool) {
        guard let window else {
            dimView?.removeFromSuperview()
            dimView = nil
            return
        }
        let target = window.rootViewController?.view ?? window
        let dim = dimView

        let animations = {
            target.transform = .identity
            dim?.alpha = 0
        }
        let completion: (Bool) -> Void = { _ in
            if !self.isPressed {
                dim?.removeFromSuperview()
                if self.dimView === dim {
                    self.dimView = nil
                }
            }
        }

        if animated {
            UIView.animate(
                withDuration: 0.22,
                delay: 0,
                options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut],
                animations: animations,
                completion: completion
            )
        } else {
            animations()
            completion(true)
        }
    }
}

private struct CourtifyPrimaryButtonLabelModifier: ViewModifier {
    var verticalPadding: CGFloat = 16
    var fillOpacity: Double = 1

    func body(content: Content) -> some View {
        content
            .font(ThemeManager.roundedFont(.headline, weight: .semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background(ThemeManager.brandYellow.opacity(fillOpacity), in: Capsule())
            // Shadow must sit outside any clip; `in: Capsule()` keeps the fill shaped
            // without clipping the glow the way `.clipShape` + parent ScrollViews can.
            .compositingGroup()
            .shadow(
                color: ThemeManager.brandYellow.opacity(0.4 * fillOpacity),
                radius: 20,
                y: 8
            )
    }
}

/// Glass secondary pill — Skip / Not now (no murky green fill).
private struct CourtifySecondaryButtonLabelModifier: ViewModifier {
    var verticalPadding: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .font(ThemeManager.roundedFont(.headline, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(ThemeManager.glassPillEdge, lineWidth: 1)
            }
    }
}

/// Inactive primary placeholder — dormant glass, not muddy yellow.
private struct CourtifyDormantButtonLabelModifier: ViewModifier {
    var verticalPadding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .font(ThemeManager.roundedFont(.headline, weight: .semibold))
            .foregroundStyle(.white.opacity(0.3))
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(ThemeManager.glassEdge, lineWidth: ThemeManager.glassEdgeWidth)
            }
    }
}

extension View {
    /// Shared press scale + soft haptic. Prefer this on every `Button` / `NavigationLink`.
    func courtifyButton(_ style: CourtifyPressStyle = .primary, enabled: Bool = true) -> some View {
        buttonStyle(.courtify(style, enabled: enabled))
    }

    /// App-root chrome: default button press + universal surface press (scale/dim/haptic)
    /// for any tap, including non-buttons. Safe to call from sheets — gesture is one per window.
    func courtifyInteractiveChrome() -> some View {
        modifier(CourtifyInteractiveChromeModifier())
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
        // `cornerRadius` retained for call-site compatibility; primary CTAs are always Capsule.
        _ = cornerRadius
        return modifier(
            CourtifyPrimaryButtonLabelModifier(
                verticalPadding: verticalPadding,
                fillOpacity: fillOpacity
            )
        )
    }

    func courtifySecondaryButtonLabel(cornerRadius: CGFloat = 12) -> some View {
        _ = cornerRadius
        return modifier(CourtifySecondaryButtonLabelModifier())
    }

    /// Disabled / pre-selection CTA — glass with quiet white text (no muddy yellow fill).
    func courtifyDormantButtonLabel(verticalPadding: CGFloat = 16) -> some View {
        modifier(CourtifyDormantButtonLabelModifier(verticalPadding: verticalPadding))
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

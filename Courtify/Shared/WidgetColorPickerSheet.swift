import SwiftUI

/// Premium sheet: pick a preset / custom accent + gradient strength for one gallery widget.
struct WidgetColorPickerSheet: View {
    let widgetID: String
    let title: String
    var onRequestPaywall: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var revenueCat = RevenueCatManager.shared
    @State private var draft: WidgetColorConfig
    @State private var sheetDetent: PresentationDetent = .large
    @State private var customColor: Color
    /// Avoid writing app-group + reloading widget timelines on every slider tick.

    private var isEntitled: Bool {
        revenueCat.isProUser || AppGroupConstants.referralBypassActive
    }

    init(widgetID: String, title: String, onRequestPaywall: (() -> Void)? = nil) {
        self.widgetID = widgetID
        self.title = title
        self.onRequestPaywall = onRequestPaywall
        let initial = WidgetColorStyle.config(for: widgetID)
        _draft = State(initialValue: initial)
        _customColor = State(initialValue: initial.resolvedAccent)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    previewCard

                    if !isEntitled {
                        lockedBanner
                    }

                    // Gradient sits above the color grid so the thumb stays clear of the home indicator.
                    gradientSection
                    presetSection
                }
                .padding(20)
                .padding(.bottom, 36)
            }
            .background(ThemeManager.midnightGreen.ignoresSafeArea())
            .navigationTitle("Widget color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        guard isEntitled else {
                            presentPaywall()
                            return
                        }
                        WidgetColorStyle.reset(widgetID)
                        draft = .default
                        customColor = draft.resolvedAccent
                    }
                    .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if isEntitled {
                            persistDraft(reloadTimelines: true)
                        }
                        dismiss()
                    }
                    .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                    .tint(ThemeManager.opticYellow)
                }
            }
            .toolbarBackground(ThemeManager.midnightGreen, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .interactiveDismissDisabled(false)
        .onDisappear {
            // Persist if the user flicked the sheet away without Done.
            guard isEntitled else { return }
            persistDraft(reloadTimelines: true)
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(ThemeManager.roundedFont(.caption, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: previewColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 88)
                .overlay(alignment: .bottomLeading) {
                    Text("Preview")
                        .font(ThemeManager.roundedFont(.subheadline, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(14)
                }
        }
    }

    private var previewColors: [Color] {
        let top = draft.resolvedAccent
        let level = draft.clampedLevel
        let bottom = WidgetTheme.midnightGreen.opacity(0.35 + (0.65 * level))
        let mid = top.opacity(1.0 - (0.35 * level))
        return level < 0.15 ? [top, top.opacity(0.92)] : [top, mid, bottom]
    }

    private var lockedBanner: some View {
        Button(action: presentPaywall) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(ThemeManager.opticYellow)
                Text("Widget colors are a Premium feature")
                    .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Unlock")
                    .font(ThemeManager.roundedFont(.caption, weight: .bold))
                    .foregroundStyle(ThemeManager.midnightGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ThemeManager.opticYellow)
                    .clipShape(Capsule())
            }
            .padding(14)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .courtifyButton(.card)
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color")
                .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 10) {
                ForEach(WidgetColorPreset.allCases) { preset in
                    Button {
                        guard isEntitled else {
                            presentPaywall()
                            return
                        }
                        CourtifyMotion.animateSelection {
                            draft.presetID = preset.rawValue
                            draft.customAccentHex = nil
                            customColor = preset.accent
                        }
                        persistDraft(reloadTimelines: false)
                    } label: {
                        colorSwatch(
                            fill: preset.accent,
                            title: preset.title,
                            isSelected: !draft.isCustom && draft.presetID == preset.rawValue
                        )
                    }
                    .courtifyButton(.ghost)
                }

                customColorSwatch
            }
        }
    }

    private var customColorSwatch: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay {
                        Circle()
                            .fill(customColor)
                            .frame(width: 22, height: 22)
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(
                                draft.isCustom ? ThemeManager.opticYellow : .white.opacity(0.15),
                                lineWidth: draft.isCustom ? 2.5 : 1
                            )
                    }

                // Full-size ColorPicker hit target (visually hidden) over the swatch.
                ColorPicker(
                    "",
                    selection: Binding(
                        get: { customColor },
                        set: { newColor in
                            guard isEntitled else {
                                presentPaywall()
                                return
                            }
                            customColor = newColor
                            draft.presetID = WidgetColorConfig.customPresetID
                            draft.customAccentHex = WidgetColorStyle.rgbHex(from: newColor)
                            persistDraft(reloadTimelines: false)
                        }
                    ),
                    supportsOpacity: false
                )
                .labelsHidden()
                .scaleEffect(1.6)
                .opacity(0.02)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
            }
            .frame(width: 36, height: 36)

            Text("Custom")
                .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(draft.isCustom ? 0.1 : 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            if !isEntitled {
                presentPaywall()
            }
        }
    }

    private func colorSwatch(fill: Color, title: String, isSelected: Bool) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(fill)
                .frame(width: 36, height: 36)
                .overlay {
                    Circle()
                        .strokeBorder(
                            isSelected ? ThemeManager.opticYellow : .white.opacity(0.15),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                }
            Text(title)
                .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(isSelected ? 0.1 : 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var gradientSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Gradient")
                    .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text(gradientLabel)
                    .font(ThemeManager.roundedFont(.caption, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            // Local binding only — persist when the finger lifts so dragging stays smooth.
            Slider(
                value: Binding(
                    get: { draft.gradientLevel },
                    set: { newValue in
                        guard isEntitled else { return }
                        draft.gradientLevel = newValue
                    }
                ),
                in: 0 ... 1,
                onEditingChanged: { editing in
                    if !isEntitled {
                        if editing { presentPaywall() }
                        return
                    }
                    if !editing {
                        persistDraft(reloadTimelines: false)
                    }
                }
            )
            .tint(ThemeManager.opticYellow)
        }
    }

    private var gradientLabel: String {
        switch draft.clampedLevel {
        case ..<0.25: return "Flat"
        case ..<0.55: return "Soft"
        case ..<0.8: return "Medium"
        default: return "Strong"
        }
    }

    private func persistDraft(reloadTimelines: Bool) {
        WidgetColorStyle.set(draft, for: widgetID, reloadTimelines: reloadTimelines)
    }

    private func presentPaywall() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onRequestPaywall?()
        }
    }
}

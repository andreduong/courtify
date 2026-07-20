import SwiftUI

/// Premium sheet: pick Tournament theme / preset / custom accent + gradient for one gallery widget.
struct WidgetColorPickerSheet: View {
    let widgetID: String
    let title: String
    var onRequestPaywall: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var revenueCat = RevenueCatManager.shared
    @AppStorage(AppGroupConstants.Keys.tourPreference, store: AppGroupConstants.userDefaults)
    private var tourPreferenceRaw = TourPreference.atp.rawValue
    @State private var draft: WidgetColorConfig
    @State private var sheetDetent: PresentationDetent = .large
    @State private var customColor: Color
    /// Avoid writing app-group + reloading widget timelines on every slider tick.

    private var isEntitled: Bool {
        revenueCat.isProUser || AppGroupConstants.referralBypassActive
    }

    private var preferredTour: TourPreference {
        let tour = TourPreference(rawValue: tourPreferenceRaw) ?? .atp
        return tour == .both ? .atp : tour
    }

    init(widgetID: String, title: String, onRequestPaywall: (() -> Void)? = nil) {
        self.widgetID = widgetID
        self.title = title
        self.onRequestPaywall = onRequestPaywall
        let initial = WidgetColorStyle.config(for: widgetID)
        _draft = State(initialValue: initial)
        _customColor = State(initialValue: initial.isTournament
            ? WidgetColorStyle.tournamentThemeAccent()
            : initial.resolvedAccent)
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
                    if !draft.isTournament {
                        gradientSection
                        textureSection
                    }
                    presetSection
                }
                .padding(20)
                .padding(.bottom, 36)
            }
            .background(ThemeManager.midnightGreen.ignoresSafeArea())
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        guard isEntitled else {
                            presentPaywall()
                            return
                        }
                        WidgetColorStyle.reset(widgetID)
                        draft = WidgetColorStyle.defaultConfig(for: widgetID)
                        customColor = draft.isTournament
                            ? WidgetColorStyle.tournamentThemeAccent(tour: preferredTour)
                            : draft.resolvedAccent
                    } label: {
                        Text("Reset")
                            .font(ThemeManager.roundedFont(.subheadline, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .fixedSize()
                    }
                    .courtifyButton(.ghost)
                    .accessibilityLabel("Reset to default")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if isEntitled {
                            persistDraft(reloadTimelines: true)
                        }
                        dismiss()
                    }
                    .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                    .tint(ThemeManager.opticYellow)
                    .courtifyButton(.ghost)
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

            ZStack {
                if draft.isTournament {
                    tournamentPreviewBackground
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: previewColors,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    WidgetTextureOverlay(
                        texture: draft.resolvedTexture,
                        accent: draft.resolvedAccent
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .frame(height: 88)
            .overlay(alignment: .bottomLeading) {
                Text(draft.isTournament ? "Tournament theme" : "Preview")
                    .font(ThemeManager.roundedFont(.subheadline, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    @ViewBuilder
    private var tournamentPreviewBackground: some View {
        let event = TournamentCalendar.nextMajor(for: preferredTour)
        if WidgetColorStyle.defaultsToTournamentTheme(widgetID),
           widgetID == "calendar" {
            WidgetAtmosphere(accent: Color(hex: 0x143D2B), glowOpacity: 0.35, texture: .velvet)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            widgetSurfaceGradient(for: event)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                tournamentSwatch

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
                            isSelected: !draft.isCustom && !draft.isTournament && draft.presetID == preset.rawValue
                        )
                    }
                    .courtifyButton(.ghost)
                }

                customColorSwatch
            }
        }
    }

    private var tournamentSwatch: some View {
        Button {
            guard isEntitled else {
                presentPaywall()
                return
            }
            CourtifyMotion.animateSelection {
                draft.presetID = WidgetColorConfig.tournamentPresetID
                draft.customAccentHex = nil
                customColor = WidgetColorStyle.tournamentThemeAccent(tour: preferredTour)
            }
            persistDraft(reloadTimelines: false)
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                Color(hex: GrandSlam.australianOpen.accentColor),
                                Color(hex: GrandSlam.frenchOpen.accentColor),
                                Color(hex: GrandSlam.wimbledon.accentColor),
                                Color(hex: GrandSlam.usOpen.accentColor),
                                Color(hex: GrandSlam.australianOpen.accentColor),
                            ],
                            center: .center
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                draft.isTournament ? ThemeManager.opticYellow : .white.opacity(0.15),
                                lineWidth: draft.isTournament ? 2.5 : 1
                            )
                    }
                Text("Tournament")
                    .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.white.opacity(draft.isTournament ? 0.1 : 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .courtifyButton(.ghost)
    }

    private var customColorSwatch: some View {
        Button {
            if !isEntitled {
                presentPaywall()
            }
        } label: {
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
                    .allowsHitTesting(isEntitled)
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
        }
        .courtifyButton(.ghost)
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

    private var textureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Texture")
                .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 10) {
                ForEach(WidgetTexturePreset.allCases) { texture in
                    Button {
                        guard isEntitled else {
                            presentPaywall()
                            return
                        }
                        CourtifyMotion.animateSelection {
                            draft.textureID = texture.rawValue
                        }
                        persistDraft(reloadTimelines: false)
                    } label: {
                        textureSwatch(texture)
                    }
                    .courtifyButton(.ghost)
                }
            }
        }
    }

    private func textureSwatch(_ texture: WidgetTexturePreset) -> some View {
        let selected = draft.resolvedTexture == texture
        return VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [draft.resolvedAccent, WidgetTheme.midnightGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                WidgetTextureOverlay(texture: texture, accent: draft.resolvedAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .frame(height: 44)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        selected ? ThemeManager.opticYellow : .white.opacity(0.12),
                        lineWidth: selected ? 2 : 1
                    )
            }

            Text(texture.title)
                .font(ThemeManager.roundedFont(.caption2, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(texture.subtitle)
                .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(selected ? 0.1 : 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

import SwiftUI

/// Premium sheet: pick a preset accent + gradient strength for one gallery widget.
struct WidgetColorPickerSheet: View {
    let widgetID: String
    let title: String
    var onRequestPaywall: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var revenueCat = RevenueCatManager.shared
    @State private var draft: WidgetColorConfig

    private var isEntitled: Bool {
        revenueCat.isProUser || AppGroupConstants.referralBypassActive
    }

    init(widgetID: String, title: String, onRequestPaywall: (() -> Void)? = nil) {
        self.widgetID = widgetID
        self.title = title
        self.onRequestPaywall = onRequestPaywall
        _draft = State(initialValue: WidgetColorStyle.config(for: widgetID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    previewCard

                    if !isEntitled {
                        lockedBanner
                    }

                    presetSection
                    gradientSection

                    Button {
                        guard isEntitled else {
                            presentPaywall()
                            return
                        }
                        WidgetColorStyle.reset(widgetID)
                        draft = .default
                    } label: {
                        Text("Reset to default")
                            .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .courtifyButton(.ghost)
                }
                .padding(20)
            }
            .background(ThemeManager.midnightGreen.ignoresSafeArea())
            .navigationTitle("Widget color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if isEntitled {
                            WidgetColorStyle.set(draft, for: widgetID)
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
        .presentationDetents([.medium, .large])
        .onChange(of: draft) { _, newValue in
            guard isEntitled else { return }
            WidgetColorStyle.set(newValue, for: widgetID)
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
        let preset = WidgetColorPreset(rawValue: draft.presetID) ?? .courtify
        let level = draft.clampedLevel
        let top = preset.accent
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
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(preset.accent)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Circle()
                                        .strokeBorder(
                                            draft.presetID == preset.rawValue
                                                ? ThemeManager.opticYellow
                                                : .white.opacity(0.15),
                                            lineWidth: draft.presetID == preset.rawValue ? 2.5 : 1
                                        )
                                }
                            Text(preset.title)
                                .font(ThemeManager.roundedFont(.caption2, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.white.opacity(draft.presetID == preset.rawValue ? 0.1 : 0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .courtifyButton(.ghost)
                }
            }
        }
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

            Slider(
                value: Binding(
                    get: { draft.gradientLevel },
                    set: { newValue in
                        guard isEntitled else {
                            presentPaywall()
                            return
                        }
                        draft.gradientLevel = newValue
                    }
                ),
                in: 0 ... 1
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

    private func presentPaywall() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onRequestPaywall?()
        }
    }
}

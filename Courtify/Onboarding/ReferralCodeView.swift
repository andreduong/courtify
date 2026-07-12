import SwiftUI

enum ReferralAccess {
    static let bypassCode = "andreduong2026"

    static func isValid(_ code: String) -> Bool {
        code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == bypassCode.lowercased()
    }
}

struct ReferralCodeView: View {
    @State private var referralCode = ""
    @State private var showInvalidHint = false
    @FocusState private var isFieldFocused: Bool

    let onSubmit: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter referral code")
                    .font(ThemeManager.roundedFont(.title, weight: .bold))
                    .foregroundStyle(.white)

                Text("Optional - you can skip this step.")
                    .font(ThemeManager.roundedFont(.subheadline))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.top, 8)

            TextField("Referral code", text: $referralCode)
                .font(ThemeManager.roundedFont(.body, weight: .medium))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFieldFocused)
                .submitLabel(.go)
                .onSubmit(submitCode)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            showInvalidHint ? Color.red.opacity(0.7) : Color.white.opacity(0.12),
                            lineWidth: showInvalidHint ? 1.5 : 1
                        )
                }
                .offset(x: showInvalidHint ? -6 : 0)
                .animation(
                    showInvalidHint
                        ? .default.repeatCount(3, autoreverses: true).speed(4)
                        : CourtifyMotion.selection,
                    value: showInvalidHint
                )

            if showInvalidHint {
                Text("That code isn't recognized. Try again or skip.")
                    .font(ThemeManager.roundedFont(.caption))
                    .foregroundStyle(.red.opacity(0.85))
                    .transition(CourtifyMotion.crossfade)
            }

            Spacer()

            Button(action: submitCode) {
                Text("SUBMIT")
                    .courtifyPrimaryButtonLabel(cornerRadius: 16)
            }
            .courtifyButton(.primary, enabled: !referralCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button(action: onSkip) {
                Text("Skip")
                    .courtifySecondaryButtonLabel(cornerRadius: 16)
            }
            .courtifyButton(.secondary)
        }
        .padding(24)
        .animation(CourtifyMotion.selection, value: showInvalidHint)
        .onAppear {
            isFieldFocused = true
        }
    }

    private func submitCode() {
        let trimmed = referralCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if ReferralAccess.isValid(trimmed) {
            showInvalidHint = false
            onSubmit()
        } else {
            CourtifyMotion.animateSelection {
                showInvalidHint = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                CourtifyMotion.animateSelection {
                    showInvalidHint = false
                }
            }
        }
    }
}

#Preview {
    ReferralCodeView(onSubmit: {}, onSkip: {})
        .courtifyBackground()
}

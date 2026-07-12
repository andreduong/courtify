import SwiftUI

struct FavoriteGrandSlamView: View {
    @Binding var favoriteGrandSlam: String
    @State private var selectedSlam: GrandSlam?

    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pick your Grand Slam")
                    .font(ThemeManager.roundedFont(.title, weight: .bold))
                    .foregroundStyle(.white)

                Text("Which major gets your heart racing? We'll highlight it all season.")
                    .font(ThemeManager.roundedFont(.subheadline))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.top, 8)

            VStack(spacing: 14) {
                ForEach(GrandSlam.allCases) { slam in
                    GrandSlamRow(
                        slam: slam,
                        isSelected: selectedSlam == slam
                    ) {
                        CourtifyMotion.animateSelection {
                            selectedSlam = slam
                            favoriteGrandSlam = slam.rawValue
                        }
                    }
                }
            }

            Spacer()

            Button(action: onContinue) {
                Text(selectedSlam == nil ? "Choose a Slam" : "Continue")
                    .courtifyPrimaryButtonLabel(fillOpacity: selectedSlam == nil ? 0.4 : 1)
            }
            .courtifyButton(.primary, enabled: selectedSlam != nil)
        }
        .padding(24)
        .onAppear {
            if let existing = GrandSlam(rawValue: favoriteGrandSlam) {
                selectedSlam = existing
            }
        }
    }
}

private struct GrandSlamRow: View {
    let slam: GrandSlam
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                CachedBundledImage(name: slam.logoImageName, contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(slam.rawValue)
                        .font(ThemeManager.roundedFont(.headline, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("\(slam.location) · \(slam.surface)")
                        .font(ThemeManager.roundedFont(.caption))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(ThemeManager.opticYellow)
                }
            }
            .glassCard(cornerRadius: 16, padding: 16)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? ThemeManager.opticYellow : Color.clear,
                        lineWidth: 2
                    )
            }
            .courtifySelection(isSelected)
        }
        .courtifyButton(.card)
    }
}

#Preview {
    FavoriteGrandSlamView(favoriteGrandSlam: .constant(""), onContinue: {})
        .courtifyBackground()
}

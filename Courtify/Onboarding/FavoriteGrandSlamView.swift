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

            VStack(spacing: 12) {
                ForEach(GrandSlam.allCases) { slam in
                    GrandSlamListRow(
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

            Spacer(minLength: 0)

            if selectedSlam == nil {
                Text("Choose a Slam")
                    .courtifyDormantButtonLabel()
            } else {
                Button(action: onContinue) {
                    Text("Continue")
                        .courtifyPrimaryButtonLabel()
                }
                .courtifyButton(.primary)
            }
        }
        .padding(24)
        .onAppear {
            if let existing = GrandSlam(rawValue: favoriteGrandSlam) {
                selectedSlam = existing
            }
        }
    }
}

private struct GrandSlamListRow: View {
    let slam: GrandSlam
    let isSelected: Bool
    let onTap: () -> Void

    private let cornerRadius: CGFloat = 18

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                SlamLogoBadge(slam: slam, size: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(slam.rawValue)
                        .font(ThemeManager.roundedFont(.headline, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("\(slam.location) · \(slam.surface)")
                        .font(ThemeManager.roundedFont(.caption))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(ThemeManager.brandYellow)
                        .shadow(color: ThemeManager.brandYellow.opacity(0.55), radius: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .courtifySelectableCard(isSelected: isSelected, cornerRadius: cornerRadius, scale: 1.02)
        }
        .courtifyButton(.card)
    }
}

#Preview {
    FavoriteGrandSlamView(favoriteGrandSlam: .constant(""), onContinue: {})
        .courtifyBackground()
}

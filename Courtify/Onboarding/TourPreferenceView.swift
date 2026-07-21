import SwiftUI

struct TourPreferenceView: View {
    @Binding var tourPreference: TourPreference
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Which tour do you follow?")
                    .font(ThemeManager.roundedFont(.title, weight: .bold))
                    .foregroundStyle(.white)

                Text("We'll tailor scores, news, and favorites to your pick.")
                    .font(ThemeManager.roundedFont(.subheadline))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.top, 8)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(TourPreference.allCases) { preference in
                    TourPreferenceCard(
                        preference: preference,
                        isSelected: tourPreference == preference
                    ) {
                        CourtifyMotion.animateSelection {
                            tourPreference = preference
                        }
                    }
                }
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .courtifyPrimaryButtonLabel()
            }
            .courtifyButton(.primary)
        }
        .padding(24)
    }
}

private struct TourPreferenceCard: View {
    let preference: TourPreference
    let isSelected: Bool
    let onTap: () -> Void

    private let cornerRadius: CGFloat = 20

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: preference.icon)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? ThemeManager.brandYellow : .white.opacity(0.7))

                Text(preference.rawValue)
                    .font(ThemeManager.roundedFont(.title3, weight: .bold))
                    .foregroundStyle(.white)

                Text(preference.subtitle)
                    .font(ThemeManager.roundedFont(.caption))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .courtifySelectableCard(isSelected: isSelected, cornerRadius: cornerRadius)
        }
        .courtifyButton(.card)
        .gridCellColumns(preference == .both ? 2 : 1)
    }
}

#Preview {
    TourPreferenceView(tourPreference: .constant(.both), onContinue: {})
        .courtifyBackground()
}

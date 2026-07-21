import SwiftUI

struct SplashScreenView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            ThemeManager.oledBlack.ignoresSafeArea()

            CourtifyMarqueeBackground()
                // Rasterize the live scrolling cards first — otherwise `.blur` barely softens them.
                .drawingGroup(opaque: true, colorMode: .extendedLinear)
                .blur(radius: 16)
                .scaleEffect(1.06) // hide soft blur edges at the screen bounds
                .allowsHitTesting(false)
                .ignoresSafeArea()

            // Moody scrim so white type pops over the soft widget texture.
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 14) {
                    CourtifyLogoMark(size: 72)

                    Text("Courtify")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Your courtside companion for live scores, stats, and Grand Slam drama.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Button(action: onContinue) {
                    Text("Join Courtify")
                        .courtifyPrimaryButtonLabel(verticalPadding: 18)
                }
                .courtifyButton(.primary)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            BundledImageCache.warmOnboardingAssets()
        }
    }
}

#Preview {
    SplashScreenView(onContinue: {})
}

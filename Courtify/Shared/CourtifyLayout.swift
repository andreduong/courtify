import SwiftUI
import UIKit

enum CourtifyLayout {
    static let heroListOverlap: CGFloat = 20
    static let tabBarHeight: CGFloat = 49
    static let scrollBottomExtra: CGFloat = 24
    static let heroContentTopExtra: CGFloat = 8

    static let rankingsHeroHeight: CGFloat = 380
    static let rankingsHeroEmptyHeight: CGFloat = 300
    static let scheduleHeroHeight: CGFloat = 360

    /// Legacy helper for full-screen overlays (e.g. paywall) outside tab scroll layouts.
    static var topSafeInset: CGFloat {
        guard let window = activeWindow else { return 59 }
        let top = window.safeAreaInsets.top
        return top > 0 ? top : 59
    }

    private static var activeWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        return scene?.windows.first(where: \.isKeyWindow) ?? scene?.windows.first
    }
}

// MARK: - Full-bleed screen (Home)

/// Single source of truth for full-bleed tops.
///
/// Reads the safe-area insets *before* extending under the status bar. Applying
/// `.ignoresSafeArea(edges: .top)` around a `GeometryReader` makes that reader
/// report `safeAreaInsets.top == 0`, which silently breaks every safe-top offset
/// inside it. This container avoids `ignoresSafeArea` on the content entirely:
/// it measures the real inset, then grows the content by that amount and shifts
/// it up so it draws edge-to-edge under the status bar.
struct CourtifyFullBleedScreen<Content: View>: View {
    @ViewBuilder var content: (_ safeTop: CGFloat, _ size: CGSize) -> Content

    var body: some View {
        GeometryReader { geometry in
            let safeTop = geometry.safeAreaInsets.top
            let size = CGSize(width: geometry.size.width, height: geometry.size.height + safeTop)
            content(safeTop, size)
                .frame(width: size.width, height: size.height, alignment: .top)
                .offset(y: -safeTop)
        }
        .background(ThemeManager.midnightGreen.ignoresSafeArea())
    }
}

// MARK: - Gradient hero + dark tile list (Schedule, Rankings)

/// F1-app-style screen: a full-bleed gradient hero on top that fades into the
/// dark background, followed by flat list tiles separated by hairline dividers
/// (no white card). `listContent` rows are wrapped in a single VStack here so
/// row modifiers never accidentally apply per-`ForEach`-element.
struct CourtifyHeroScrollScreen<HeroBackground: View, HeroContent: View, ListContent: View, ScrollTrigger: Equatable>: View {
    let heroHeight: CGFloat
    let scrollTrigger: ScrollTrigger
    let onScroll: ((ScrollViewProxy) -> Void)?
    @ViewBuilder var heroBackground: () -> HeroBackground
    @ViewBuilder var heroContent: () -> HeroContent
    @ViewBuilder var listContent: () -> ListContent

    init(
        heroHeight: CGFloat,
        scrollTrigger: ScrollTrigger = 0,
        onScroll: ((ScrollViewProxy) -> Void)? = nil,
        @ViewBuilder heroBackground: @escaping () -> HeroBackground,
        @ViewBuilder heroContent: @escaping () -> HeroContent,
        @ViewBuilder listContent: @escaping () -> ListContent
    ) {
        self.heroHeight = heroHeight
        self.scrollTrigger = scrollTrigger
        self.onScroll = onScroll
        self.heroBackground = heroBackground
        self.heroContent = heroContent
        self.listContent = listContent
    }

    var body: some View {
        GeometryReader { geometry in
            let safeTop = geometry.safeAreaInsets.top
            let safeBottom = geometry.safeAreaInsets.bottom

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        CourtifyHeroBlock(
                            heroHeight: heroHeight,
                            safeTop: safeTop,
                            heroBackground: heroBackground,
                            heroContent: heroContent
                        )

                        VStack(spacing: 0) {
                            listContent()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, safeBottom + CourtifyLayout.tabBarHeight + CourtifyLayout.scrollBottomExtra)
                    }
                }
                .scrollContentBackground(.hidden)
                .onAppear {
                    onScroll?(proxy)
                }
                .onChange(of: scrollTrigger) { _, _ in
                    onScroll?(proxy)
                }
            }
        }
        .background(ThemeManager.midnightGreen.ignoresSafeArea())
    }
}

/// Hero background extended under the status bar, content inset below it,
/// bottom fade into the screen background so the list tiles blend seamlessly.
private struct CourtifyHeroBlock<HeroBackground: View, HeroContent: View>: View {
    let heroHeight: CGFloat
    let safeTop: CGFloat
    @ViewBuilder var heroBackground: () -> HeroBackground
    @ViewBuilder var heroContent: () -> HeroContent

    var body: some View {
        ZStack(alignment: .topLeading) {
            heroBackground()
                .frame(maxWidth: .infinity)
                .frame(height: heroHeight + safeTop)
                .overlay(alignment: .bottom) {
                    // Fade the hero into the screen background *behind* the hero
                    // content so text near the bottom stays fully legible.
                    LinearGradient(
                        colors: [.clear, ThemeManager.midnightGreen],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                }
                .offset(y: -safeTop)
                .clipped()

            heroContent()
                .padding(.top, safeTop + CourtifyLayout.heroContentTopExtra)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: heroHeight, alignment: .topLeading)
        }
        .frame(height: heroHeight)
    }
}

/// Hairline separator between list tiles.
struct CourtifyTileDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 20)
    }
}

// MARK: - Plain scroll (Widgets)

struct CourtifyPlainScrollScreen<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            let safeBottom = geometry.safeAreaInsets.bottom

            ScrollView {
                content()
                    .padding(.top, 12)
                    .padding(.bottom, safeBottom + CourtifyLayout.tabBarHeight + CourtifyLayout.scrollBottomExtra)
            }
            .scrollContentBackground(.hidden)
        }
        .background(ThemeManager.midnightGreen.ignoresSafeArea())
    }
}

struct TourPillToggle: View {
    @Binding var selectedTour: TourPreference

    var body: some View {
        HStack(spacing: 0) {
            pill("ATP", tour: .atp)
            pill("WTA", tour: .wta)
        }
        .padding(4)
        .background(.white.opacity(0.12))
        .clipShape(Capsule())
    }

    private func pill(_ title: String, tour: TourPreference) -> some View {
        let isSelected = selectedTour == tour
        return Button {
            CourtifyMotion.animateSelection { selectedTour = tour }
        } label: {
            Text(title)
                .font(ThemeManager.roundedFont(.subheadline, weight: .semibold))
                .foregroundStyle(isSelected ? ThemeManager.midnightGreen : .white.opacity(0.85))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(isSelected ? Color.white : Color.clear)
                .clipShape(Capsule())
        }
        .courtifyButton(.ghost)
    }
}

import SwiftUI
import UIKit

// MARK: - Share screen

/// Full-screen shareable preview opened from the Widgets gallery.
struct WidgetShareView: View {
    let item: CourtifyWidgetCatalog.Item
    let favoritePlayer: TennisPlayer?
    let favoritePlayerID: String
    let tour: TourPreference
    let payload: WidgetDataPayload?
    var onClose: () -> Void

    @State private var activityItems: [Any] = []
    @State private var showActivitySheet = false

    private var previewWidth: CGFloat {
        item.size == .small ? item.size.previewHeight * 1.35 : UIScreen.main.bounds.width - 56
    }

    private var previewHeight: CGFloat {
        item.size.previewHeight * (item.size == .small ? 1.35 : 1.15)
    }

    var body: some View {
        ZStack {
            ThemeManager.midnightGreen.ignoresSafeArea()

            LinearGradient(
                colors: [
                    ThemeManager.emeraldGreen.opacity(0.35),
                    ThemeManager.midnightGreen,
                    ThemeManager.midnightGreen,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                header

                Spacer(minLength: 12)

                sharePreviewCard
                    .padding(.horizontal, 28)

                Spacer(minLength: 12)

                MadeByCourtifyAppStoreStamp()
                    .padding(.bottom, 20)

                shareButton
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
            }
        }
        .sheet(isPresented: $showActivitySheet) {
            ActivityShareSheet(items: activityItems)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(ThemeManager.roundedFont(.title3, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(item.size.rawValue) · Share")
                    .font(ThemeManager.roundedFont(.footnote, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .courtifyButton(.icon)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var sharePreviewCard: some View {
        WidgetGalleryPreview(
            item: item,
            favoritePlayer: favoritePlayer,
            favoritePlayerID: favoritePlayerID,
            tour: tour,
            payload: payload
        )
        .frame(width: item.size == .small ? previewWidth : nil)
        .frame(maxWidth: item.size == .small ? previewWidth : .infinity)
        .frame(height: previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
    }

    private var shareButton: some View {
        Button {
            presentSystemShare()
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
                .courtifyPrimaryButtonLabel(cornerRadius: 16, verticalPadding: 17)
        }
        .courtifyButton(.primary)
    }

    private func presentSystemShare() {
        guard let image = WidgetShareExporter.renderImage(
            item: item,
            favoritePlayer: favoritePlayer,
            favoritePlayerID: favoritePlayerID,
            tour: tour,
            payload: payload
        ) else { return }
        activityItems = [image, CourtifyDeepLinks.appStoreURL]
        showActivitySheet = true
    }
}

// MARK: - App Store stamp (share canvas + on-screen)

struct MadeByCourtifyAppStoreStamp: View {
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 2 : 4) {
            Text("Made by Courtify")
                .font(ThemeManager.roundedFont(size: compact ? 13 : 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
            Text("on App Store")
                .font(ThemeManager.roundedFont(size: compact ? 11 : 12, weight: .semibold))
                .foregroundStyle(ThemeManager.opticYellow.opacity(0.9))
                .tracking(0.6)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Made by Courtify on App Store")
    }
}

// MARK: - Share asset exporter

enum WidgetShareExporter {
    @MainActor
    static func renderImage(
        item: CourtifyWidgetCatalog.Item,
        favoritePlayer: TennisPlayer?,
        favoritePlayerID: String,
        tour: TourPreference,
        payload: WidgetDataPayload?
    ) -> UIImage? {
        let canvas = WidgetShareCanvas(
            item: item,
            favoritePlayer: favoritePlayer,
            favoritePlayerID: favoritePlayerID,
            tour: tour,
            payload: payload
        )
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// 9:16 shareable asset with widget + App Store stamp (rendered via `ImageRenderer`).
private struct WidgetShareCanvas: View {
    let item: CourtifyWidgetCatalog.Item
    let favoritePlayer: TennisPlayer?
    let favoritePlayerID: String
    let tour: TourPreference
    let payload: WidgetDataPayload?

    private let canvasWidth: CGFloat = 360
    private let canvasHeight: CGFloat = 640

    private var widgetWidth: CGFloat {
        switch item.size {
        case .small: 200
        case .medium, .large: 300
        }
    }

    private var widgetHeight: CGFloat {
        switch item.size {
        case .small: 200
        case .medium: 190
        case .large: 300
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x00703C),
                    ThemeManager.midnightGreen,
                    ThemeManager.midnightGreen,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 28) {
                Spacer(minLength: 40)

                Text(item.title.uppercased())
                    .font(ThemeManager.roundedFont(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .tracking(1.2)

                WidgetGalleryPreview(
                    item: item,
                    favoritePlayer: favoritePlayer,
                    favoritePlayerID: favoritePlayerID,
                    tour: tour,
                    payload: payload
                )
                .frame(width: widgetWidth, height: widgetHeight)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)

                Spacer(minLength: 20)

                MadeByCourtifyAppStoreStamp()
                    .padding(.bottom, 48)
            }
            .padding(.horizontal, 24)
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }
}

// MARK: - UIKit share sheet

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

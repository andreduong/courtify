import SwiftUI
import UIKit

enum TennisPlayerPhotoStyle {
  case headshot
  case hero
}

/// Soft bottom fade so torso cutouts dissolve into OLED black (no hard crop line).
struct CourtifyHeroFadeMask: ViewModifier {
  /// Portion of height that fades to transparent (0.25 = bottom 25%).
  var fadePortion: CGFloat = 0.25

  func body(content: Content) -> some View {
    content.mask {
      LinearGradient(
        stops: [
          .init(color: .white, location: 0),
          .init(color: .white, location: max(0, 1 - fadePortion)),
          .init(color: .clear, location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    }
  }
}

extension View {
  /// Fade the bottom of a player cutout into the canvas.
  func courtifyHeroFadeMask(fadePortion: CGFloat = 0.25) -> some View {
    modifier(CourtifyHeroFadeMask(fadePortion: fadePortion))
  }

  /// Massive ranks / countdowns — tightened tracking for a digital scoreboard.
  func courtifyScoreboardNumber() -> some View {
    kerning(WidgetTheme.scoreboardKerning)
  }

  /// Unit / stat labels under big numbers — tiny, uppercase, wide tracking, secondary.
  func courtifyMicroLabel() -> some View {
    font(WidgetTheme.microLabelFont(size: 10, weight: .semibold))
      .textCase(.uppercase)
      .kerning(WidgetTheme.microLabelKerning)
      .foregroundStyle(Color.secondary)
  }
}

/// Full-torso cutout for Home, widgets gallery, and settings favorite cards.
/// Bundled `-hero` assets for featured players only. RapidAPI studio JPEGs are
/// opaque plates — always circular headshots, never rectangular “cutouts”.
/// Never falls back to letter placeholders (`placeholder-male` / `placeholder-female`).
struct PlayerTorsoPhotoView: View {
  let player: TennisPlayer
  var contentMode: ContentMode = .fit
  /// Soft bottom blend into black — on for large heroes; off for tiny thumbnails if needed.
  var fadesIntoBackground: Bool = true
  /// Bottom fraction that dissolves (default 25% per product spec).
  var fadePortion: CGFloat = 0.25
  /// When no transparent cutout exists, show a circular studio headshot instead of only silhouette.
  var prefersCircularHeadshotFallback: Bool = true
  /// Diameter for the circular fallback (Home / posters use a larger default than Settings).
  var circularHeadshotSize: CGFloat = 140
  /// Where the circular API headshot sits when there is no bundled cutout.
  var circularHeadshotAlignment: Alignment = .bottomTrailing

  var body: some View {
    photoContent
      .modifier(OptionalHeroFade(enabled: fadesIntoBackground && showsCutoutFade, fadePortion: fadePortion))
  }

  @ViewBuilder
  private var photoContent: some View {
    if let bundled = bundledHeroName {
      // Only bundled transparent PNGs get full-bleed rectangular torso layout.
      Image(bundled)
        .resizable()
        .aspectRatio(contentMode: contentMode)
    } else if prefersCircularHeadshotFallback, let uiImage = studioHeadshotImage {
      StudioHeadshotCircle(uiImage: uiImage, size: circularHeadshotSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: circularHeadshotAlignment)
    } else {
      PlayerSilhouetteView(tour: player.tour, style: .torso)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  /// Fade only applies to real transparent cutouts — never to circular studio plates.
  private var showsCutoutFade: Bool {
    bundledHeroName != nil
  }

  private var bundledHeroName: String? {
    guard let imageName = player.imageName else { return nil }
    return "\(imageName)-hero"
  }

  /// Any cached API JPEG is a studio plate (head preferred; leftover `-hero.jpg` is the same bytes).
  private var studioHeadshotImage: UIImage? {
    trustedCachedUIImage(variant: .head) ?? trustedCachedUIImage(variant: .hero)
  }

  private func trustedCachedUIImage(variant: PlayerPhotoVariant) -> UIImage? {
    guard player.isCustom else { return nil }
    guard PlayerPhotoStore.isValidImageFile(playerID: player.id, variant: variant),
          let path = PlayerPhotoStore.cachedPath(playerID: player.id, variant: variant) else {
      return nil
    }
    return UIImage(contentsOfFile: path)
  }
}

/// Soft circular framing for opaque RapidAPI studio plates (hides hard JPEG corners).
private struct StudioHeadshotCircle: View {
  let uiImage: UIImage
  let size: CGFloat

  var body: some View {
    Image(uiImage: uiImage)
      .resizable()
      .scaledToFill()
      .frame(width: size, height: size)
      .clipShape(Circle())
      .overlay {
        Circle()
          .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
  }
}

private struct OptionalHeroFade: ViewModifier {
  var enabled: Bool
  var fadePortion: CGFloat = 0.25

  @ViewBuilder
  func body(content: Content) -> some View {
    if enabled {
      content.courtifyHeroFadeMask(fadePortion: fadePortion)
    } else {
      content
    }
  }
}

/// Circular list / search headshot. Bundled avatar or cached API JPEG only —
/// never a grey rectangle. Silhouette fallback is monochrome SF Symbol (no fill).
struct TennisPlayerPhotoView: View {
  let player: TennisPlayer
  var style: TennisPlayerPhotoStyle = .headshot
  var size: CGFloat = 44

  var body: some View {
    Group {
      if let bundledName = bundledAssetName {
        Image(bundledName)
          .resizable()
          .scaledToFill()
          .frame(width: size, height: size)
          .clipShape(Circle())
      } else if let uiImage = cachedStudioImage {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()
          .frame(width: size, height: size)
          .clipShape(Circle())
      } else {
        PlayerSilhouetteView(tour: player.tour, style: .headshot, size: size)
      }
    }
    .overlay {
      Circle()
        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        .frame(width: size, height: size)
    }
  }

  /// Bundled avatar for headshot; bundled `-hero` only when style is `.hero` (cutout elsewhere).
  private var bundledAssetName: String? {
    guard player.imageName != nil else { return nil }
    switch style {
    case .headshot:
      return player.resolvedImageName
    case .hero:
      // This view is circular-only — torso cutouts go through PlayerTorsoPhotoView.
      // Prefer the bundled circular avatar when available.
      return player.resolvedImageName
    }
  }

  /// Head preferred; leftover `-hero.jpg` studio plates are the same RapidAPI bytes.
  private var cachedStudioImage: UIImage? {
    if PlayerPhotoStore.isValidImageFile(playerID: player.id, variant: .head),
       let path = PlayerPhotoStore.cachedPath(playerID: player.id, variant: .head),
       let image = UIImage(contentsOfFile: path) {
      return image
    }
    if PlayerPhotoStore.isValidImageFile(playerID: player.id, variant: .hero),
       let path = PlayerPhotoStore.cachedPath(playerID: player.id, variant: .hero),
       let image = UIImage(contentsOfFile: path) {
      return image
    }
    return nil
  }
}

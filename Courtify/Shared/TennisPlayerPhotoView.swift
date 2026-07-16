import SwiftUI
import UIKit

enum TennisPlayerPhotoStyle {
  case headshot
  case hero
}

/// Full-torso cutout for Home, widgets gallery, and settings favorite cards.
/// Bundled `-hero` assets for featured players; app-group cache for custom picks.
/// Never falls back to the letter placeholders (`placeholder-male` / `placeholder-female`).
struct PlayerTorsoPhotoView: View {
  let player: TennisPlayer
  var contentMode: ContentMode = .fit

  var body: some View {
    Group {
      if let bundled = bundledHeroName {
        Image(bundled)
          .resizable()
          .aspectRatio(contentMode: contentMode)
      } else if let uiImage = trustedCachedUIImage(variant: .hero) {
        Image(uiImage: uiImage)
          .resizable()
          .aspectRatio(contentMode: contentMode)
      } else if let uiImage = trustedCachedUIImage(variant: .head) {
        Image(uiImage: uiImage)
          .resizable()
          .aspectRatio(contentMode: contentMode)
      } else {
        PlayerSilhouetteView(tour: player.tour, style: .torso)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }

  private var bundledHeroName: String? {
    guard let imageName = player.imageName else { return nil }
    return "\(imageName)-hero"
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
      } else if let path = cachedPath,
                PlayerPhotoStore.isValidImageFile(playerID: player.id, variant: style == .headshot ? .head : .hero),
                let uiImage = UIImage(contentsOfFile: path) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()
      } else {
        PlayerSilhouetteView(tour: player.tour, style: .headshot, size: size)
      }
    }
    .frame(width: size, height: style == .hero ? nil : size)
    .frame(maxWidth: style == .hero ? .infinity : size, maxHeight: style == .hero ? .infinity : size)
    .background(Color.black.opacity(0.2))
    .clipShape(style == .headshot ? AnyShape(Circle()) : AnyShape(Rectangle()))
    .overlay {
      if style == .headshot {
        Circle()
          .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
      }
    }
  }

  private var bundledAssetName: String? {
    guard player.imageName != nil else { return nil }
    switch style {
    case .headshot:
      return player.resolvedImageName
    case .hero:
      return player.heroImageName.hasSuffix("-hero") ? player.heroImageName : nil
    }
  }

  private var cachedPath: String? {
    let variant: PlayerPhotoVariant = style == .headshot ? .head : .hero
    return PlayerPhotoStore.cachedPath(playerID: player.id, variant: variant)
  }
}

private struct AnyShape: Shape {
  private let builder: (CGRect) -> Path

  init<S: Shape>(_ shape: S) {
    builder = { rect in shape.path(in: rect) }
  }

  func path(in rect: CGRect) -> Path {
    builder(rect)
  }
}

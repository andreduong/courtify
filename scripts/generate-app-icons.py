#!/usr/bin/env python3
"""Generate Courtify app icon variants (primary + alternates) from the master PNG."""

from __future__ import annotations

import colorsys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Courtify" / "Assets.xcassets"
ICON_MASTER = ASSETS / "AppIcon.appiconset" / "AppIcon-1024.png"

ICON_PRESETS: dict[str, tuple[int, int, int]] = {
    "AppIcon": (0xCC, 0xFF, 0x00),  # courtify (primary) — brand optic accent
    "AppIcon-Hardcourt": (0x4A, 0x90, 0xD9),
    "AppIcon-Clay": (0xE3, 0x52, 0x05),
    "AppIcon-Grass": (0x00, 0x66, 0x33),
    "AppIcon-Berry": (0x9B, 0x6B, 0xFF),
    "AppIcon-White": (0xFF, 0xFF, 0xFF),
    "AppIcon-Optic": (0xCC, 0xFF, 0x00),
}

ICON_TO_LOGO: dict[str, str] = {
    "AppIcon": "courtify-logo-courtify",
    "AppIcon-Hardcourt": "courtify-logo-hardcourt",
    "AppIcon-Clay": "courtify-logo-clay",
    "AppIcon-Grass": "courtify-logo-grass",
    "AppIcon-Berry": "courtify-logo-berry",
    "AppIcon-White": "courtify-logo-white",
    "AppIcon-Optic": "courtify-logo-optic",
}

CONTENTS_TEMPLATE = """{{
  "images" : [
    {{
      "filename" : "{filename}",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }}
  ],
  "info" : {{
    "author" : "xcode",
    "version" : 1
  }}
}}
"""

LOGO_CONTENTS_TEMPLATE = """{{
  "images" : [
    {{
      "filename" : "{filename}",
      "idiom" : "universal",
      "scale" : "1x"
    }},
    {{
      "idiom" : "universal",
      "scale" : "2x"
    }},
    {{
      "idiom" : "universal",
      "scale" : "3x"
    }}
  ],
  "info" : {{
    "author" : "xcode",
    "version" : 1
  }}
}}
"""


def recolor(src_rgb: Image.Image, target_rgb: tuple[int, int, int]) -> Image.Image:
    arr = np.array(src_rgb.convert("RGB"), dtype=np.float32)
    intensity = arr.sum(axis=2)
    ball = intensity > 90

    tr, tg, tb = (c / 255.0 for c in target_rgb)
    target_h, target_s, _ = colorsys.rgb_to_hsv(tr, tg, tb)

    rgb = arr / 255.0
    maxc = rgb.max(axis=2)
    minc = rgb.min(axis=2)
    delta = maxc - minc

    value = maxc
    saturation = np.zeros_like(value)
    nonzero = delta > 1e-6
    saturation[nonzero] = delta[nonzero] / maxc[nonzero]

    hue = np.zeros_like(value)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mask_r = nonzero & (maxc == r)
    mask_g = nonzero & (maxc == g)
    mask_b = nonzero & (maxc == b)
    hue[mask_r] = ((g - b) / delta)[mask_r] % 6
    hue[mask_g] = ((b - r) / delta)[mask_g] + 2
    hue[mask_b] = ((r - g) / delta)[mask_b] + 4
    hue = hue / 6.0

    out_h = np.where(ball, target_h, hue)
    out_s = np.where(ball, np.maximum(saturation, target_s * 0.85), saturation)
    out_v = value

    hi = np.floor(out_h * 6).astype(int) % 6
    f = out_h * 6 - np.floor(out_h * 6)
    p = out_v * (1 - out_s)
    q = out_v * (1 - f * out_s)
    t = out_v * (1 - (1 - f) * out_s)

    result = np.zeros_like(rgb)
    for i, (a, b, c) in enumerate(
        [
            (out_v, t, p),
            (q, out_v, p),
            (p, out_v, t),
            (p, q, out_v),
            (t, p, out_v),
            (out_v, p, q),
        ]
    ):
        m = hi == i
        result[m, 0] = a[m]
        result[m, 1] = b[m]
        result[m, 2] = c[m]

  # Keep seams/background exactly black.
    result[~ball] = rgb[~ball]
    return Image.fromarray((result * 255).astype(np.uint8))


def write_icon_set(name: str, image: Image.Image) -> None:
    folder = ASSETS / f"{name}.appiconset"
    folder.mkdir(parents=True, exist_ok=True)
    filename = f"{name}-1024.png"
    image.save(folder / filename)
    (folder / "Contents.json").write_text(CONTENTS_TEMPLATE.format(filename=filename))


def write_logo_imageset(name: str, image: Image.Image) -> None:
    folder = ASSETS / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    filename = f"{name}.png"
    image.save(folder / filename)
    (folder / "Contents.json").write_text(LOGO_CONTENTS_TEMPLATE.format(filename=filename))


def main() -> None:
    if not ICON_MASTER.exists():
        raise SystemExit(f"Missing master icon: {ICON_MASTER}")

    icon_source = Image.open(ICON_MASTER).convert("RGB")
    for set_name, rgb in ICON_PRESETS.items():
        icon = recolor(icon_source, rgb)
        write_icon_set(set_name, icon)
        print(f"wrote {set_name}")

        logo_name = ICON_TO_LOGO[set_name]
        write_logo_imageset(logo_name, icon)
        print(f"wrote {logo_name}")


if __name__ == "__main__":
    main()

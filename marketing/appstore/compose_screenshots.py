#!/usr/bin/env python3
"""Compose App Store marketing screenshots from real Courtify simulator captures."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

RAW = Path(__file__).resolve().parent / "raw"
OUT = Path(__file__).resolve().parent / "out"
OUT.mkdir(parents=True, exist_ok=True)

# App Store 6.7" portrait
W, H = 1290, 2796

LIME = (204, 255, 0)
LIME_SOFT = (180, 230, 60)
WHITE = (255, 255, 255)
OFFWHITE = (235, 240, 235)
MUTED = (170, 180, 170)
BLACK = (0, 0, 0)
MIDNIGHT = (6, 18, 14)
EMERALD = (18, 90, 55)


def load_font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont:
    paths = [
        "/System/Library/Fonts/Supplemental/Arial Black.ttf",
        "/System/Library/Fonts/Supplemental/Impact.ttf",
        "/System/Library/Fonts/Avenir Next.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/SFNS.ttf",
    ]
    for path in paths:
        try:
            if path.endswith(".ttc"):
                # index 1 often = Bold/Medium in Apple TTCs
                return ImageFont.truetype(path, size=size, index=1 if bold else 0)
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def radial_glow(
    size: tuple[int, int],
    color: tuple[int, int, int],
    center: tuple[float, float] | None = None,
    radius: float = 0.55,
    strength: int = 210,
) -> Image.Image:
    w, h = size
    cx, cy = center if center else (0.5, 0.42)
    cx *= w
    cy *= h
    r = radius * max(w, h)
    base = Image.new("RGBA", size, (0, 0, 0, 0))
    px = base.load()
    for y in range(h):
        # sample every 2px for speed then upsample
        pass
    # Faster: draw soft ellipse layers
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for i in range(18, 0, -1):
        t = i / 18
        alpha = int(strength * (1 - t) ** 1.6)
        rr = r * (0.25 + 0.85 * t)
        bbox = [cx - rr, cy - rr * 1.15, cx + rr, cy + rr * 1.15]
        draw.ellipse(bbox, fill=(*color, alpha))
    return layer.filter(ImageFilter.GaussianBlur(radius=48))


def rounded_rect_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return mask


def make_phone_frame(screen: Image.Image, max_h: int, max_w: int | None = None) -> Image.Image:
    """Wrap a screenshot in a simple dark iPhone-like bezel."""
    screen = screen.convert("RGBA")
    # Crop status-bar-friendly; keep full screen
    aspect = screen.height / screen.width
    target_h = max_h
    target_w = int(target_h / aspect)
    if max_w and target_w > max_w:
        target_w = max_w
        target_h = int(target_w * aspect)
    screen = screen.resize((target_w, target_h), Image.LANCZOS)

    bezel = 18
    radius = 78
    outer_w = target_w + bezel * 2
    outer_h = target_h + bezel * 2
    outer = Image.new("RGBA", (outer_w, outer_h), (0, 0, 0, 0))
    frame = Image.new("RGBA", (outer_w, outer_h), (18, 20, 22, 255))
    frame_mask = rounded_rect_mask((outer_w, outer_h), radius)
    outer.paste(frame, (0, 0), frame_mask)

    # subtle silver edge
    edge = Image.new("RGBA", (outer_w, outer_h), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        [1, 1, outer_w - 2, outer_h - 2],
        radius=radius - 1,
        outline=(90, 95, 100, 180),
        width=3,
    )
    outer.alpha_composite(edge)

    screen_mask = rounded_rect_mask((target_w, target_h), radius - bezel + 4)
    outer.paste(screen, (bezel, bezel), screen_mask)

    # Dynamic Island
    island_w, island_h = int(target_w * 0.28), int(target_h * 0.028)
    ix = bezel + (target_w - island_w) // 2
    iy = bezel + int(target_h * 0.018)
    island = Image.new("RGBA", (outer_w, outer_h), (0, 0, 0, 0))
    ImageDraw.Draw(island).rounded_rectangle(
        [ix, iy, ix + island_w, iy + island_h],
        radius=island_h // 2,
        fill=(5, 5, 5, 255),
    )
    outer.alpha_composite(island)

    # soft drop shadow
    shadow = Image.new("RGBA", (outer_w + 80, outer_h + 80), (0, 0, 0, 0))
    sh = Image.new("RGBA", (outer_w, outer_h), (0, 0, 0, 160))
    sh = Image.composite(sh, Image.new("RGBA", (outer_w, outer_h), (0, 0, 0, 0)), frame_mask)
    sh = sh.filter(ImageFilter.GaussianBlur(28))
    shadow.paste(sh, (40, 50), sh)
    shadow.alpha_composite(outer, (40, 30))
    return shadow


def text_size(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont) -> tuple[int, int]:
    box = draw.textbbox((0, 0), text, font=font)
    return box[2] - box[0], box[3] - box[1]


def draw_wrapped_headline(
    canvas: Image.Image,
    lines: list[str],
    y: int,
    font: ImageFont.ImageFont,
    fill=WHITE,
    accent_words: set[str] | None = None,
    accent_fill=LIME,
    center: bool = False,
    x: int = 72,
    max_width: int | None = None,
) -> int:
    draw = ImageDraw.Draw(canvas)
    accent_words = accent_words or set()
    max_width = max_width or (W - 2 * x)
    for line in lines:
        words = line.split(" ")
        # measure whole line
        tw, th = text_size(draw, line, font)
        lx = (W - tw) // 2 if center else x
        # draw word by word for accents
        cx = lx
        for i, word in enumerate(words):
            color = accent_fill if word.strip(".,!").upper() in {w.upper() for w in accent_words} else fill
            draw.text((cx, y), word, font=font, fill=color)
            ww, _ = text_size(draw, word + (" " if i < len(words) - 1 else ""), font)
            cx += ww
        y += int(th * 1.05)
    return y


def wrap_text(text: str, font: ImageFont.ImageFont, max_width: int) -> list[str]:
    draw = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    words = text.split()
    lines: list[str] = []
    cur = ""
    for word in words:
        trial = f"{cur} {word}".strip()
        tw, _ = text_size(draw, trial, font)
        if tw <= max_width or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def draw_subline(canvas: Image.Image, text: str, y: int, center: bool = False, x: int = 72) -> int:
    font = load_font(38, bold=False)
    draw = ImageDraw.Draw(canvas)
    max_w = W - 2 * x
    for line in wrap_text(text, font, max_w):
        tw, th = text_size(draw, line, font)
        lx = (W - tw) // 2 if center else x
        draw.text((lx, y), line, font=font, fill=MUTED)
        y += th + 8
    return y + 10


def base_canvas(glow_color=(40, 160, 70), glow_center=(0.5, 0.45)) -> Image.Image:
    img = Image.new("RGBA", (W, H), (*MIDNIGHT, 255))
    # vertical vignette gradient
    grad = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(grad)
    for y in range(H):
        t = y / H
        a = int(40 + 80 * abs(t - 0.55))
        gdraw.line([(0, y), (W, y)], fill=(0, 0, 0, min(a, 120)))
    glow = radial_glow((W, H), glow_color, center=glow_center, radius=0.62, strength=200)
    img.alpha_composite(glow)
    img.alpha_composite(grad)
    # faint speed streaks
    streaks = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(streaks)
    for i, yy in enumerate(range(200, H - 200, 140)):
        alpha = 18 if i % 2 == 0 else 10
        sd.arc([ -400, yy, W + 400, yy + 900], start=200, end=340, fill=(*LIME, alpha), width=3)
    streaks = streaks.filter(ImageFilter.GaussianBlur(2))
    img.alpha_composite(streaks)
    return img


def paste_centered(canvas: Image.Image, phone: Image.Image, y: int) -> None:
    x = (W - phone.width) // 2
    canvas.alpha_composite(phone, (x, y))


def press_logos_row(canvas: Image.Image, y: int) -> int:
    logos = ["TENNIS CHANNEL", "ESPN", "USA TODAY", "TechCrunch", "The Athletic"]
    font = load_font(28, bold=True)
    draw = ImageDraw.Draw(canvas)
    gap = 36
    widths = [text_size(draw, n, font)[0] for n in logos]
    total = sum(widths) + gap * (len(logos) - 1)
    x = (W - total) // 2
    for name, ww in zip(logos, widths):
        draw.text((x, y), name, font=font, fill=(210, 220, 210, 220))
        x += ww + gap
    return y + 50


def award_badge(canvas: Image.Image, y: int, text: str = "APP STORE BEST OF 2026 FINALIST · SPORTS") -> int:
    font = load_font(30, bold=True)
    draw = ImageDraw.Draw(canvas)
    tw, th = text_size(draw, text, font)
    pad_x, pad_y = 36, 18
    bw, bh = tw + pad_x * 2 + 80, th + pad_y * 2
    bx = (W - bw) // 2
    badge = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    bd = ImageDraw.Draw(badge)
    bd.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=bh // 2, fill=(20, 28, 22, 220), outline=LIME, width=2)
    # simple laurel dots
    bd.text((22, pad_y - 2), "❧", font=font, fill=LIME)
    bd.text((bw - 48, pad_y - 2), "❧", font=font, fill=LIME)
    bd.text(((bw - tw) // 2, pad_y), text, font=font, fill=WHITE)
    canvas.alpha_composite(badge, (bx, y))
    return y + bh + 24


def save(canvas: Image.Image, name: str) -> Path:
    path = OUT / name
    rgb = Image.new("RGB", canvas.size, BLACK)
    rgb.paste(canvas, mask=canvas.split()[-1] if canvas.mode == "RGBA" else None)
    rgb.save(path, "PNG", optimize=True)
    print(f"wrote {path}")
    return path


def slide_01_social_proof() -> Path:
    """Box Box–style opener: fan count, press, award, real widget collage + icon."""
    canvas = base_canvas((50, 180, 70), (0.5, 0.42))
    y = 100
    y = draw_wrapped_headline(
        canvas,
        ["500,000+", "TENNIS FANS."],
        y,
        load_font(118, True),
        center=True,
        accent_words={"500,000+"},
    )
    y = draw_subline(
        canvas,
        "ONE OBSESSION. ATP & WTA LIVE SCORES, WIDGETS & RANKINGS.",
        y + 4,
        center=True,
    )

    # Floating real widget cards from simulator share screens
    share = Image.open(RAW / "05-share-favorite.png").convert("RGBA")
    next_share = Image.open(RAW / "06-share-next.png").convert("RGBA")
    order = Image.open(RAW / "11-order.png").convert("RGBA")

    # Crop central widget cards (1206x2622 share UIs)
    crops = [
        (share.crop((220, 620, 986, 1380)).resize((400, 400), Image.LANCZOS), -10, (70, y + 20)),
        (next_share.crop((90, 580, 1116, 1520)).resize((520, 520), Image.LANCZOS), 7, (W - 560, y + 60)),
        (order.crop((90, 580, 1116, 1520)).resize((480, 480), Image.LANCZOS), -4, (140, y + 520)),
    ]

    for crop, angle, (px, py) in crops:
        mask = rounded_rect_mask(crop.size, 64)
        crop.putalpha(mask)
        card = crop.rotate(angle, resample=Image.BICUBIC, expand=True)
        sh = Image.new("RGBA", (card.width + 50, card.height + 50), (0, 0, 0, 0))
        s = Image.new("RGBA", card.size, (0, 0, 0, 150))
        s.putalpha(card.split()[-1])
        s = s.filter(ImageFilter.GaussianBlur(18))
        sh.paste(s, (18, 22), s)
        sh.alpha_composite(card, (8, 6))
        canvas.alpha_composite(sh, (px, py))

    # App icon center-front
    icon = Image.open(RAW / "app-icon.png").convert("RGBA").resize((200, 200), Image.LANCZOS)
    icon_mask = rounded_rect_mask((200, 200), 44)
    icon.putalpha(icon_mask)
    glow = Image.new("RGBA", (280, 280), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([20, 20, 260, 260], fill=(*LIME, 100))
    glow = glow.filter(ImageFilter.GaussianBlur(22))
    ix = (W - 280) // 2
    iy = y + 420
    canvas.alpha_composite(glow, (ix, iy))
    canvas.alpha_composite(icon, (ix + 40, iy + 40))

    tag_font = load_font(36, True)
    draw = ImageDraw.Draw(canvas)
    tag = "COURTIFY"
    tw, th = text_size(draw, tag, tag_font)
    draw.text(((W - tw) // 2, iy + 230), tag, font=tag_font, fill=WHITE)

    by = H - 300
    press_logos_row(canvas, by)
    award_badge(canvas, by + 70)
    return save(canvas, "01-social-proof.png")


def slide_phone(
    filename: str,
    screen_path: Path,
    headline: list[str],
    sub: str,
    accent_words: set[str] | None = None,
    glow=(45, 170, 80),
    phone_h: int = 1680,
) -> Path:
    canvas = base_canvas(glow, (0.5, 0.52))
    y = 110
    y = draw_wrapped_headline(
        canvas,
        headline,
        y,
        load_font(72 if max(len(l) for l in headline) > 18 else 84, True),
        center=True,
        accent_words=accent_words,
    )
    y = draw_subline(canvas, sub, y + 6, center=True)
    screen = Image.open(screen_path)
    phone = make_phone_frame(screen, max_h=phone_h, max_w=820)
    # place phone lower
    paste_centered(canvas, phone, min(y + 20, H - phone.height - 40))
    return save(canvas, filename)


def slide_widgets_home_screen() -> Path:
    """Widgets slide: gallery screen + badge callouts."""
    canvas = base_canvas((30, 140, 90), (0.5, 0.5))
    y = 100
    y = draw_wrapped_headline(
        canvas,
        ["CUSTOMIZE HOME &", "LOCK SCREEN WIDGETS."],
        y,
        load_font(68, True),
        center=True,
        accent_words={"HOME", "&", "LOCK", "SCREEN", "WIDGETS."},
    )
    y = draw_subline(
        canvas,
        "OVER 15 STYLES FOR ATP, WTA, GRAND SLAMS & LIVE SCORES.",
        y + 4,
        center=True,
    )

    # main phone: widgets gallery
    phone = make_phone_frame(Image.open(RAW / "04-widgets.png"), max_h=1500, max_w=760)
    paste_centered(canvas, phone, y + 10)

    # floating favorite widget card from share screen (crop widget area)
    share = Image.open(RAW / "05-share-favorite.png").convert("RGBA")
    # Approximate crop of central widget on 1206x2622
    widget = share.crop((220, 620, 986, 1380)).resize((420, 420), Image.LANCZOS)
    wmask = rounded_rect_mask(widget.size, 72)
    widget.putalpha(wmask)
    # shadow + place overlapping lower-left of phone
    wx, wy = 70, H - 780
    sh = widget.filter(ImageFilter.GaussianBlur(1))
    shadow = Image.new("RGBA", (widget.width + 40, widget.height + 40), (0, 0, 0, 0))
    s = Image.new("RGBA", widget.size, (0, 0, 0, 140))
    s.putalpha(wmask)
    s = s.filter(ImageFilter.GaussianBlur(16))
    shadow.paste(s, (20, 24), s)
    shadow.alpha_composite(widget, (10, 8))
    canvas.alpha_composite(shadow, (wx, wy))

    # badge
    badge_font = load_font(34, True)
    draw = ImageDraw.Draw(canvas)
    label = "LOCK SCREEN READY"
    tw, th = text_size(draw, label, badge_font)
    bw, bh = tw + 56, th + 28
    bx, by = W - bw - 70, H - 260
    ImageDraw.Draw(canvas).rounded_rectangle(
        [bx, by, bx + bw, by + bh], radius=bh // 2, fill=(18, 28, 20, 230), outline=LIME, width=2
    )
    draw.text((bx + 28, by + 12), label, font=badge_font, fill=LIME)
    return save(canvas, "03-widgets.png")


def slide_collage() -> Path:
    canvas = base_canvas((55, 150, 60), (0.5, 0.48))
    y = 110
    y = draw_wrapped_headline(
        canvas,
        ["THE ULTIMATE", "TENNIS COMPANION."],
        y,
        load_font(78, True),
        center=True,
        accent_words={"TENNIS", "COMPANION."},
    )
    y = draw_subline(
        canvas,
        "ATP, WTA, LIVE SCORES, WIDGETS & STATS IN ONE PLACE.",
        y + 4,
        center=True,
    )

    screens = [
        (RAW / "01-home.png", 0.92, -18),
        (RAW / "03-rankings.png", 1.0, 0),
        (RAW / "04-widgets.png", 0.92, 18),
    ]
    phones = []
    for path, scale, angle in screens:
        ph = make_phone_frame(Image.open(path), max_h=int(1450 * scale), max_w=int(700 * scale))
        ph = ph.rotate(angle, resample=Image.BICUBIC, expand=True)
        phones.append(ph)

    # layout: back left, back right, front center
    positions = [
        (40, y + 120),
        (W - phones[2].width - 40, y + 120),
        ((W - phones[1].width) // 2, y + 40),
    ]
    order = [0, 2, 1]  # left, right, center on top
    for i in order:
        canvas.alpha_composite(phones[i], positions[i])
    return save(canvas, "07-companion.png")


def main() -> None:
    slides = []
    slides.append(slide_01_social_proof())
    slides.append(
        slide_phone(
            "02-favorite-player.png",
            RAW / "01-home.png",
            ["TRACK YOUR", "FAVORITE PLAYER."],
            "PERSONALIZED TENNIS STATS, ATP RANKINGS & GRAND SLAM COUNTDOWNS.",
            {"FAVORITE", "PLAYER."},
            glow=(35, 150, 55),
        )
    )
    slides.append(slide_widgets_home_screen())
    slides.append(
        slide_phone(
            "04-rankings.png",
            RAW / "03-rankings.png",
            ["ATP & WTA RANKINGS", "AT A GLANCE."],
            "REAL-TIME TENNIS POINTS & STANDINGS. ALWAYS COURTSIDE.",
            {"ATP", "&", "WTA", "RANKINGS"},
            glow=(40, 130, 80),
        )
    )
    slides.append(
        slide_phone(
            "05-grand-slam.png",
            RAW / "02-schedule.png",
            ["NEVER MISS A", "GRAND SLAM."],
            "US OPEN COUNTDOWN, MASTERS 1000 & TOURNAMENT CALENDAR.",
            {"GRAND", "SLAM."},
            glow=(30, 110, 90),
        )
    )
    slides.append(
        slide_phone(
            "06-order-of-play.png",
            RAW / "11-order.png",
            ["LIVE SCORES &", "ORDER OF PLAY."],
            "INSTANT MATCH UPDATES, ATP / WTA SCHEDULES & WIDGETS.",
            {"LIVE", "SCORES", "&", "ORDER", "OF", "PLAY."},
            glow=(50, 140, 70),
            phone_h=1600,
        )
    )
    slides.append(slide_collage())

    # also export share-focused bonus using real widget share UI
    slides.append(
        slide_phone(
            "08-favorite-widget.png",
            RAW / "05-share-favorite.png",
            ["YOUR PLAYER.", "YOUR HOME SCREEN."],
            "FAVORITE PLAYER TENNIS WIDGETS WITH RANK, W-L & SEASON STATS.",
            {"PLAYER.", "HOME", "SCREEN."},
            glow=(60, 170, 50),
            phone_h=1600,
        )
    )

    print("\nDone. Slides:")
    for p in slides:
        print(" -", p)


if __name__ == "__main__":
    main()

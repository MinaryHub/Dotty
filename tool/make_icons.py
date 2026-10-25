"""Draws the Dotty logo (a lit LED "D" on a dot-matrix panel) and writes
every platform's app icon. Run from the repo root: python3 tool/make_icons.py
Needs Pillow."""

from PIL import Image, ImageDraw, ImageFilter

# 7×7 panel; the D is lit, the border ring stays dark like unlit LEDs.
GLYPH = [
    ".......",
    ".####..",
    ".#...#.",
    ".#...#.",
    ".#...#.",
    ".####..",
    ".......",
]

BG_TOP = (28, 24, 24)
BG_BOTTOM = (8, 8, 8)
LIT = (255, 59, 48)
CORE = (255, 214, 196)
UNLIT = (52, 22, 20)


def render(size, *, inset, radius, full_bleed=False):
    """[inset]: fraction of the canvas left empty around the panel;
    [radius]: panel corner radius as a fraction of the panel size."""
    ss = 4
    s = size * ss
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    # Panel background with a soft vertical gradient.
    pad = 0 if full_bleed else round(s * inset)
    panel = s - 2 * pad
    grad = Image.new("RGBA", (panel, panel))
    gd = ImageDraw.Draw(grad)
    for y in range(panel):
        t = y / max(1, panel - 1)
        c = tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM))
        gd.line([(0, y), (panel, y)], fill=c + (255,))
    mask = Image.new("L", (panel, panel), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, panel - 1, panel - 1],
        radius=0 if full_bleed else round(panel * radius),
        fill=255,
    )
    img.paste(grad, (pad, pad), mask)

    # Dot grid inside the panel (inside the maskable safe zone when full bleed).
    n = len(GLYPH)
    area = round(s * (0.62 if full_bleed else 1 - 2 * inset - 0.16 * (1 - 2 * inset)))
    origin = (s - area) / 2
    pitch = area / n
    r = pitch * 0.40

    glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    dots = ImageDraw.Draw(img)
    for row, line in enumerate(GLYPH):
        for col, ch in enumerate(line):
            cx = origin + (col + 0.5) * pitch
            cy = origin + (row + 0.5) * pitch
            if ch == "#":
                gdraw.ellipse(
                    [cx - r * 1.5, cy - r * 1.5, cx + r * 1.5, cy + r * 1.5],
                    fill=LIT + (150,),
                )
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(pitch * 0.45)))
    dots = ImageDraw.Draw(img)
    for row, line in enumerate(GLYPH):
        for col, ch in enumerate(line):
            cx = origin + (col + 0.5) * pitch
            cy = origin + (row + 0.5) * pitch
            if ch != "#":
                dots.ellipse([cx - r, cy - r, cx + r, cy + r], fill=UNLIT + (255,))
                continue
            # Lit LED: red lens fading to a hot core, plus a small highlight.
            steps = 24
            for i in range(steps):
                t = i / (steps - 1)
                rr = r * (1 - 0.75 * t)
                c = tuple(round(a + (b - a) * t ** 1.6) for a, b in zip(LIT, CORE))
                dots.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=c + (255,))
            hr = r * 0.22
            hx, hy = cx - r * 0.38, cy - r * 0.42
            dots.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=(255, 255, 255, 170))

    return img.resize((size, size), Image.LANCZOS)


def save(img, path):
    img.save(path)
    print(path)


icon = lambda size: render(size, inset=0.0, radius=0.22)  # noqa: E731
mac = lambda size: render(size, inset=0.1, radius=0.225)  # noqa: E731
maskable = lambda size: render(size, inset=0, radius=0, full_bleed=True)  # noqa: E731

save(icon(32), "web/favicon.png")
save(icon(192), "web/icons/Icon-192.png")
save(icon(512), "web/icons/Icon-512.png")
save(maskable(192), "web/icons/Icon-maskable-192.png")
save(maskable(512), "web/icons/Icon-maskable-512.png")
for name, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
    save(icon(size), f"android/app/src/main/res/mipmap-{name}/ic_launcher.png")
for size in [16, 32, 64, 128, 256, 512, 1024]:
    save(mac(size), f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png")
icon(256).save(
    "windows/runner/resources/app_icon.ico",
    sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
)
print("windows/runner/resources/app_icon.ico")
save(icon(256), "assets/logo.png")

#!/usr/bin/env python3
"""ひと駅なぞとき のアイコン（夜の地下鉄の駅）。1024x1024、透過なし PNG。

暗い紺の地にタイルの目地、路線の色（みなと線の青）の帯、駅ナンバリングの記号（白い丸に青い太い輪）の中に「?」、
上に発車標の青白い光の点。Pillow だけで描く。
  python3 scripts/make-icon-night.py
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "App", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")
NIGHT = (10, 15, 20)
TOP = (22, 33, 43)
RULE = (32, 43, 54)
LINE = (47, 157, 226)
SIGN = (243, 245, 246)
INK = (17, 24, 32)
LED = (150, 210, 250)  # 路線の色（青）を明るくした光。黄色は使わない

FONTS = ["/usr/share/fonts/opentype/inter/Inter-Black.otf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]


def font(size):
    for f in FONTS:
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default(size=size)


img = Image.new("RGB", (S, S), NIGHT)
d = ImageDraw.Draw(img)
# 上が少し明るい地
for y in range(S):
    t = min(1, y / (S * 0.7))
    c = tuple(int(TOP[i] * (1 - t) + NIGHT[i] * t) for i in range(3))
    d.line([(0, y), (S, y)], fill=c)
# タイルの目地
tw, th = 128, 64
for row, y in enumerate(range(0, S, th)):
    d.line([(0, y), (S, y)], fill=RULE, width=2)
    off = 0 if row % 2 == 0 else -tw // 2
    for x in range(off, S, tw):
        d.line([(x, y), (x, y + th)], fill=RULE, width=2)

# 路線の帯（上下に白い縁）
by = 600
d.rectangle([0, by - 8, S, by + 92], fill=SIGN)
d.rectangle([0, by, S, by + 84], fill=LINE)

# 発車標の光（青白い点の列）をにじませる
glow = Image.new("RGB", (S, S), (0, 0, 0))
g = ImageDraw.Draw(glow)
for i in range(7):
    x = 232 + i * 94
    g.ellipse([x - 22, 150 - 22, x + 22, 150 + 22], fill=LED)
glow = glow.filter(ImageFilter.GaussianBlur(18))
img = Image.composite(Image.new("RGB", (S, S), LED), img, glow.convert("L").point(lambda v: min(255, v)))
d = ImageDraw.Draw(img)
for i in range(7):
    x = 232 + i * 94
    d.ellipse([x - 18, 150 - 18, x + 18, 150 + 18], fill=LED)

# 駅ナンバリングの記号：白い丸に青い太い輪、中に「?」
cx, cy, r = S // 2, 560, 250
d.ellipse([cx - r - 14, cy - r - 14, cx + r + 14, cy + r + 14], fill=NIGHT)
d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=LINE)
ri = r - 58
d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], fill=SIGN)
d.text((cx, cy + 6), "?", fill=INK, font=font(300), anchor="mm")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT, "PNG", optimize=True)
print(f"wrote {os.path.relpath(OUT)} ({img.mode}, {img.size[0]}x{img.size[1]})")

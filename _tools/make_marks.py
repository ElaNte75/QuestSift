# Draws the bag mark pictures (white shapes, see-through background) into Media/Marks/*.tga.
# White so the game can colour them any way (Items/BagQuestItems.lua). Run: python -I _tools/make_marks.py <add-on folder>
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

root = sys.argv[1]
out = os.path.join(root, "Media", "Marks")
os.makedirs(out, exist_ok=True)

SIZE = 64          # final picture (power of two, as the game wants)
BIG = SIZE * 8     # drawn large, then shrunk = smooth edges
FONT = "C:/Windows/Fonts/ariblk.ttf"


def canvas():
    img = Image.new("RGBA", (BIG, BIG), (255, 255, 255, 0))
    return img, ImageDraw.Draw(img)


def P(x, y):
    return (x * BIG, y * BIG)


def thick_line(d, pts, w):
    w = int(w * BIG)
    d.line([P(*p) for p in pts], fill=(255, 255, 255, 255), width=w, joint="curve")
    for p in (pts[0], pts[-1]):
        x, y = P(*p)
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=(255, 255, 255, 255))


def glyph(d, ch, scale):
    font = ImageFont.truetype(FONT, int(BIG * scale))
    box = d.textbbox((0, 0), ch, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    d.text(((BIG - w) / 2 - box[0], (BIG - h) / 2 - box[1]), ch, font=font, fill=(255, 255, 255, 255))


def star(d, r1, r2):
    pts = []
    for i in range(10):
        r = r1 if i % 2 == 0 else r2
        a = -math.pi / 2 + i * math.pi / 5
        pts.append(P(0.5 + r * math.cos(a), 0.53 + r * math.sin(a)))
    d.polygon(pts, fill=(255, 255, 255, 255))


shapes = {
    "Tick": lambda d: thick_line(d, [(0.22, 0.52), (0.42, 0.72), (0.78, 0.30)], 0.15),
    "Cross": lambda d: (thick_line(d, [(0.28, 0.28), (0.72, 0.72)], 0.15),
                        thick_line(d, [(0.72, 0.28), (0.28, 0.72)], 0.15)),
    "Question": lambda d: glyph(d, "?", 0.82),
    "Exclaim": lambda d: glyph(d, "!", 0.82),
    "Star": lambda d: star(d, 0.40, 0.17),
    "Dot": lambda d: d.ellipse([P(0.24, 0.24), P(0.76, 0.76)], fill=(255, 255, 255, 255)),
    "Diamond": lambda d: d.polygon([P(0.5, 0.14), P(0.84, 0.5), P(0.5, 0.86), P(0.16, 0.5)], fill=(255, 255, 255, 255)),
}

for name, draw in shapes.items():
    img, d = canvas()
    draw(d)
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    path = os.path.join(out, name + ".tga")
    img.save(path)
    print("wrote", path)

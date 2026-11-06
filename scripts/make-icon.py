#!/usr/bin/env python3
"""Draws the App Vanish icon from code and writes every size in the app icon set.

Run from the repository root: python3 scripts/make-icon.py
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SS = 4
S = 1024 * SS
BODY = 824 * SS
MARGIN = (S - BODY) // 2


def px(v):
    return int(v * SS)


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def gradient(stops, angle=115):
    """Linear gradient across the canvas, stops = [(pos, '#hex'), ...]."""
    a = math.radians(angle)
    n = 384
    im = Image.new("RGB", (n, n))
    data = []
    rgb = [(p, hex_rgb(c)) for p, c in stops]
    norm = abs(math.sin(a)) + abs(math.cos(a))
    for y in range(n):
        for x in range(n):
            t = ((x / (n - 1) - .5) * math.sin(a) - (y / (n - 1) - .5) * math.cos(a)) / norm + .5
            t = min(1, max(0, t))
            for (p0, c0), (p1, c1) in zip(rgb, rgb[1:]):
                if t <= p1:
                    f = (t - p0) / (p1 - p0)
                    data.append(tuple(int(c0[i] + (c1[i] - c0[i]) * f) for i in range(3)))
                    break
    im.putdata(data)
    return im.resize((S, S), Image.BICUBIC).convert("RGBA")


def squircle_mask(size, n=5.0):
    pts = []
    r = size / 2
    for i in range(1440):
        t = 2 * math.pi * i / 1440
        c, s = math.cos(t), math.sin(t)
        pts.append((r + r * abs(c) ** (2 / n) * math.copysign(1, c), r + r * abs(s) ** (2 / n) * math.copysign(1, s)))
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def shadow(shape, blur, opacity, dy, color=(40, 0, 60)):
    alpha = shape.split()[3].filter(ImageFilter.GaussianBlur(px(blur)))
    alpha = alpha.point(lambda v: int(v * opacity))
    out = Image.new("RGBA", shape.size, color + (0,))
    out.putalpha(alpha)
    moved = Image.new("RGBA", shape.size, (0, 0, 0, 0))
    moved.paste(out, (0, px(dy)))
    return moved


def layer():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def rrect(d, box, r, fill):
    d.rounded_rectangle([px(v) for v in box], radius=px(r), fill=fill)


def bin_shape(cx, top, w, h, fill="#FFFFFF"):
    """Upright bin: taller than wide, so it never reads as squat."""
    out = layer()
    d = ImageDraw.Draw(out)
    tw, bw = w, w * .78
    x0, x1 = cx - tw / 2, cx + tw / 2
    bx0, bx1 = cx - bw / 2, cx + bw / 2
    y0, y1 = top, top + h
    d.polygon([(px(x0), px(y0)), (px(x1), px(y0)), (px(bx1), px(y1)), (px(bx0), px(y1))], fill=fill)
    out = out.filter(ImageFilter.GaussianBlur(px(11))).point(lambda v: v)
    a = out.split()[3].point(lambda v: 255 if v > 127 else 0)
    out = Image.new("RGBA", (S, S), hex_rgb(fill) + (0,))
    out.putalpha(a)
    return out


def lid(cx, y, w, fill="#FFFFFF", angle=0):
    t = w * .115
    im = layer()
    d = ImageDraw.Draw(im)
    rrect(d, (cx - w / 2, y, cx + w / 2, y + t), t / 2, fill)
    hw = w * .3
    d.rounded_rectangle([px(cx - hw / 2), px(y - t * .72), px(cx + hw / 2), px(y + t * .4)], radius=px(t * .42), fill=fill)
    if angle:
        im = im.rotate(angle, resample=Image.BICUBIC, center=(px(cx - w / 2), px(y + t)))
    return im


def sparkle(cx, cy, r, fill="#FFFFFF"):
    """Four-point star with curved sides."""
    pts = []
    for i in range(360):
        t = math.radians(i)
        c, s_ = math.cos(t), math.sin(t)
        pts.append((cx + r * math.copysign(abs(c) ** 3, c), cy + r * math.copysign(abs(s_) ** 3, s_)))
    out = layer()
    ImageDraw.Draw(out).polygon([(px(x), px(y)) for x, y in pts], fill=fill)
    return out


def app_tile(cx, cy, size, angle):
    """A bright app icon: a rounded tile with a simple grid of dots."""
    big = px(size * 1.7)
    a = (big - px(size)) // 2
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle([a, a, a + px(size), a + px(size)], radius=px(size * .25), fill=255)
    grad = gradient([(0, "#FFE24A"), (1, "#FF9A1F")], 160).resize((big, big), Image.BICUBIC)
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    im.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(im)
    dot = size * .2
    gap = size * .1
    start = (size - (2 * dot + gap)) / 2
    for r in range(2):
        for c in range(2):
            x = a + px(start + c * (dot + gap))
            y = a + px(start + r * (dot + gap))
            d.rounded_rectangle([x, y, x + px(dot), y + px(dot)], radius=px(dot * .3), fill=(255, 255, 255, 245))
    im = im.rotate(angle, resample=Image.BICUBIC)
    out = layer()
    out.paste(im, (px(cx) - big // 2, px(cy) - big // 2), im)
    return out


def tinted(shape, stops, angle=180):
    out = gradient(stops, angle)
    out.putalpha(shape.split()[3])
    return out


def art_scene():
    can = tinted(bin_shape(500, 486, 348, 356, "#FFFFFF"), [(0, "#D9E4FF"), (1, "#FFFFFF")])
    ribs = layer()
    d = ImageDraw.Draw(ribs)
    cx, top, w, h = 500, 486, 348, 356
    for f in (-.25, 0, .25):
        x0, x1 = cx + w * f, cx + w * f * .78
        y0, y1 = top + h * .18, top + h * .84
        d.line([(px(x0), px(y0)), (px(x1), px(y1))], fill="#5E8DF7", width=px(24))
        for x, y in ((x0, y0), (x1, y1)):
            r = px(12)
            d.ellipse([px(x) - r, px(y) - r, px(x) + r, px(y) + r], fill="#5E8DF7")
    cover = lid(492, 424, 412, "#FFFFFF", angle=11)
    piece = app_tile(632, 232, 168, -14)
    art = layer()
    for p in (piece, can, ribs, cover):
        art.alpha_composite(p)
    return art


def scene():
    """A bright app dropping into an upright bin, with a sparkle."""
    bg = gradient([(0, "#19D3FF"), (.5, "#2B7BFF"), (1, "#6A35F5")], 152)
    art = art_scene()
    spark = layer()
    spark.alpha_composite(sparkle(350, 268, 74))
    return bg, [shadow(art, 18, .34, 18, (12, 16, 96)), art, spark]


def render():
    bg, parts = scene()
    body = layer()
    body.paste(bg, (0, 0))
    # Soft light from above, so the tile doesn't look flat.
    sheen = Image.new("L", (1, 256))
    sheen.putdata([int(max(0, 1 - y / 140) ** 2 * 62) for y in range(256)])
    light = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    light.putalpha(sheen.resize((S, S), Image.BICUBIC))
    body.alpha_composite(light)
    for p in parts:
        body.alpha_composite(p)
    mask = Image.new("L", (S, S), 0)
    mask.paste(squircle_mask(BODY), (MARGIN, MARGIN))
    body.putalpha(mask)
    canvas = layer()
    canvas.alpha_composite(shadow(body, 16, .34, 12, (0, 0, 0)))
    canvas.alpha_composite(body)
    return canvas.resize((1024, 1024), Image.LANCZOS)


if __name__ == "__main__":
    master = render()
    icon_set = Path("App/Assets.xcassets/AppIcon.appiconset")
    for entry in json.loads((icon_set / "Contents.json").read_text())["images"]:
        name = entry.get("filename")
        if not name:
            continue
        points = float(entry["size"].split("x")[0])
        scale = int(entry.get("scale", "1x").rstrip("x"))
        size = int(points * scale)
        master.resize((size, size), Image.LANCZOS).save(icon_set / name, optimize=True)
        print(name, size)

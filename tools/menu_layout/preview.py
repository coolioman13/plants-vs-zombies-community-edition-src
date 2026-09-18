"""Offline render of the main-menu layout (python tools/menu_layout/preview.py [out.png] [mockup.png]).

Draws build_layout.build() the way GameSelector does (idle state, everything unlocked) at 1280x720.
With a mockup path, also writes <out>_compare.png: mockup | render in design pixels.
"""
import glob
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_layout as B  # noqa: E402

_cache = {}


def load(img):
    if img not in _cache:
        if "/" in img:
            base = os.path.join(B.ROOT, img)
            path = next(p for p in glob.glob(base + ".*") if not p.endswith(".import"))
        else:
            path = os.path.join(B.ROOT, "assets", "crop", img + ".png")
        _cache[img] = Image.open(path).convert("RGBA")
    return _cache[img]


def tinted(im, tint):
    if not tint:
        return im
    a = np.array(im).astype(np.float32)
    a *= np.array(list(tint) + [1.0] * (4 - len(tint)), np.float32)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def draw_sprite(canvas, e):
    im = tinted(load(e["img"]), e.get("tint"))
    if "src" in e:
        x, y, w, h = e["src"]
        im = im.crop((x, y, x + w, y + h))
    sx, sy = e.get("scale", (1, 1))
    if e.get("mirror"):
        sx = -sx
    w, h = im.size
    a = math.radians(e.get("rot", 0))
    c, s = math.cos(a), math.sin(a)
    cx, cy = e["pos"]
    m = np.array([[c * sx, -s * sy, cx], [s * sx, c * sy, cy], [0, 0, 1]])
    corners = [m @ np.array([x - w / 2, y - h / 2, 1]) for x, y in [(0, 0), (w, 0), (0, h), (w, h)]]
    x0 = int(math.floor(min(p[0] for p in corners))); x1 = int(math.ceil(max(p[0] for p in corners)))
    y0 = int(math.floor(min(p[1] for p in corners))); y1 = int(math.ceil(max(p[1] for p in corners)))
    if x1 <= x0 or y1 <= y0:
        return
    t = np.linalg.inv(m) @ np.array([[1, 0, x0], [0, 1, y0], [0, 0, 1]])
    t[0, 2] += w / 2
    t[1, 2] += h / 2
    f = max(abs(sx), abs(sy))
    if f < 0.5:  # pre-shrink so minification isn't aliased
        k = f * 2
        im = im.resize((max(1, int(w * k)), max(1, int(h * k))), Image.LANCZOS)
        t = np.diag([k, k, 1]) @ t
    layer = im.transform((x1 - x0, y1 - y0), Image.AFFINE, tuple(t[:2].flatten()), resample=Image.BICUBIC)
    if e.get("additive"):
        region = np.array(canvas.crop((x0, y0, x1, y1))).astype(np.float32)
        la = np.array(layer).astype(np.float32)
        region[..., :3] = np.minimum(255, region[..., :3] + la[..., :3] * la[..., 3:4] / 255)
        canvas.paste(Image.fromarray(region.astype(np.uint8)), (x0, y0))
    else:
        tmp = Image.new("RGBA", canvas.size)
        tmp.paste(layer, (x0, y0))
        canvas.alpha_composite(tmp)


def draw_poly(canvas, e):
    pts = e["poly"]
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
    sx, sy, sw, sh = e["src"]
    region = tinted(load(e["img"]), e.get("tint")).crop((sx, sy, sx + sw, sy + sh)).resize((int(x1 - x0), int(y1 - y0)), Image.BICUBIC)
    mask = Image.new("L", region.size, 0)
    ImageDraw.Draw(mask).polygon([(x - x0, y - y0) for x, y in pts], fill=255)
    ra = np.array(region)
    ra[..., 3] = (ra[..., 3].astype(np.float32) * np.array(mask) / 255).astype(np.uint8)
    tmp = Image.new("RGBA", canvas.size)
    tmp.paste(Image.fromarray(ra), (int(x0), int(y0)))
    canvas.alpha_composite(tmp)
    if "outline" in e:
        a, b = e["outline"]
        ImageDraw.Draw(canvas).line([tuple(p) for p in pts[a:b + 1]], fill=(0, 0, 0, 255), width=6, joint="curve")


def render():
    canvas = Image.new("RGBA", (B.DESIGN_W, B.DESIGN_H), (0, 0, 0, 255))
    for e in B.build():
        (draw_poly if "poly" in e else draw_sprite)(canvas, e)
    return canvas


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "preview.png")
    img = render()
    img.resize((1280, 720), Image.LANCZOS).save(out)
    if len(sys.argv) > 2:
        mock = Image.open(sys.argv[2]).convert("RGBA")
        side = Image.new("RGBA", (mock.width + B.DESIGN_W, B.DESIGN_H))
        side.paste(mock, (0, 0))
        side.paste(img, (mock.width, 0))
        side.resize((side.width // 2, side.height // 2), Image.LANCZOS).save(out.replace(".png", "_compare.png"))
    print("wrote", out)

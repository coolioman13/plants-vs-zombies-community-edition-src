"""Main-menu scene layout -> src/screens/main_menu_layout.gd

python tools/menu_layout/build_layout.py           writes the GDScript layout table
python tools/menu_layout/preview.py [out.png]      renders the same layout offline (no Godot needed)

Coordinates are "design" pixels: the 1600x1200 mockup the menu was matched against, extended to 16:9
(2134x1200). The game draws the design space at DESIGN_SCALE (0.6) so it fills 1280x720.
Sprite positions are sprite centres, rotations are clockwise degrees; draw order is list order.
Sprites without a folder come from assets/crop (see tools/crop_menu_sprites.py); others are existing
game images looked up through Res.load_image_path.
"""
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_GD = os.path.join(ROOT, "src", "screens", "main_menu_layout.gd")
DESIGN_W, DESIGN_H = 2134, 1200
DESIGN_SCALE = 0.6

# Spritesheet pieces matched against the mockup: centre x, centre y, scale, clockwise rotation.
FITS = {
    "tree_of_wisdom": (580.2, 47.9, 1.3898, -1.42),
    "island": (694.0, 471.0, 1.204, -6.5),
    "almanac": (233.5, 137.5, 1.0085, 6.0),
    "tombstone": (282.5, 717.0, 1.3165, -2.5),
    "skull_wings": (322.0, 530.0, 1.0665, 0.0),
    "btn_adventure": (313.5, 654.5, 1.2165, -4.5),
    "btn_minigames": (323.0, 792.0, 1.1495, -7.0),
    "btn_puzzle": (237.0, 921.0, 1.2335, -10.0),
    "shop_key": (1124.0, 573.0, 0.933, 21.0),
    "vase_help": (644.0, 985.5, 0.9085, 3.0),
    "vase_options": (723.5, 1031.0, 1.1165, 5.5),
    "vase_quit": (801.0, 1008.5, 1.1295, 1.5),
    "zen_garden": (953.0, 981.5, 0.758, 8.0),
    "bush_skull": (1010.0, 865.0, 1.238, -5.5),
}

rng = random.Random(7)


def fit(name, **kw):
    x, y, s, r = FITS[name]
    return spr(name, x, y, s, r, **kw)


def spr(img, x, y, scale=1.0, rot=0.0, **kw):
    sx, sy = scale if isinstance(scale, (list, tuple)) else (scale, scale)
    e = {"img": img, "pos": (x, y), "scale": (sx, sy), "rot": rot}
    e.update(kw)
    return e


def poly(img, src, points, tint=None, outline=None):
    e = {"poly": points, "img": img, "src": src}
    if tint:
        e["tint"] = tint
    if outline:
        e["outline"] = outline
    return e


def point_in_poly(x, y, pts):
    inside = False
    for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]):
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
            inside = not inside
    return inside


def scatter(pts, imgs, spacing, scale_range, tint, margin=20):
    """Grass tufts on a jittered grid inside a polygon, rows top to bottom."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    out = []
    y, row = min(ys) + margin, 0
    while y < max(ys):
        x = min(xs) + (spacing[0] / 2 if row % 2 else 0)
        while x < max(xs):
            jx, jy = x + rng.uniform(-12, 12), y + rng.uniform(-8, 8)
            if point_in_poly(jx, jy, pts):
                out.append(spr(rng.choice(imgs), round(jx), round(jy), round(rng.uniform(*scale_range), 2),
                               round(rng.uniform(-10, 10), 1), tint=tint, mirror=rng.random() < 0.5))
            x += spacing[0]
        y += spacing[1]
        row += 1
    return out


def along(pts, step):
    out = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) / step))
        out += [(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n) for i in range(n)]
    return out


GRASS_SRC = (390, 70, 140, 70)   # fine blades inside grass_strip
DIRT_SRC = (62, 24, 40, 24)      # plain dirt inside dirt_rock


def pebble(x, y, size):
    """Small outlined stone: the dirt rock sprite shrunk and lightened."""
    return spr("dirt_rock", x, y, round(0.16 * size, 3), round(rng.uniform(0, 360), 1), tint=(0.8, 0.78, 0.72))

WOOD_SRC = (200, 45, 230, 60)    # vertical grain on the stump, above the carving


def build():
    L = []
    # ------------------------------------------------------------ sky (existing tree-of-wisdom gradient + selector clouds)
    sky_sx, sky_sy = 2.0, 1.2
    sky_cx = round(1450 - 0.3 * 1066 * sky_sx + 533 * sky_sx)
    sky_cy = round(-40 + 300 * sky_sy)
    L += [
        spr("reanim/tree_bg", sky_cx, sky_cy, (sky_sx, sky_sy)),
        spr("reanim/tree_bg", sky_cx - round(1066 * sky_sx), sky_cy, (sky_sx, sky_sy), mirror=True),
        spr("reanim/tree_bg", sky_cx, sky_cy + round(300 * sky_sy) + 300, (sky_sx, 60.0), src=(0, 590, 1066, 10)),
    ]
    for x, rot, s, a in [(1330, -14, (4.0, 6.0), 0.10), (1440, -4, (5.0, 6.5), 0.13), (1570, 9, (4.0, 6.0), 0.08)]:
        L.append(spr("images/spotlight", x, 410, s, rot, additive=True, tint=(1, 1, 0.85, a)))
    for img, x, y, s in [("reanim/SelectorScreen_Cloud5", 1450, 125, 0.45), ("reanim/SelectorScreen_Cloud1", 1170, 255, 0.95),
                         ("reanim/SelectorScreen_Cloud4", 1560, 380, 0.9), ("reanim/SelectorScreen_Cloud7", 1040, 408, 0.55),
                         ("reanim/SelectorScreen_Cloud2", 1920, 210, 0.75), ("reanim/SelectorScreen_Cloud6", 2060, 470, 0.9)]:
        L.append(spr(img, x, y, s, cloud=True))

    # ------------------------------------------------------------ distant forest (existing bush art, hazed)
    for x, y, s in [(1120, 690, 0.36), (1270, 650, 0.42), (1440, 640, 0.44), (1610, 655, 0.42), (1780, 640, 0.46),
                    (1950, 660, 0.42), (2110, 645, 0.44)]:
        L.append(spr("reanim/bush_cover", x, y, s, src=(0, 0, 483, 330), tint=(0.66, 0.8, 0.45)))

    # ------------------------------------------------------------ trunk + dark dirt behind the tombstone
    trunk = [(-10, 560), (230, 240), (920, 240), (905, 340), (840, 440), (805, 560), (800, 650), (880, 720), (930, 1020),
             (520, 1060), (300, 1210), (-10, 1210)]
    L.append(poly("tree_of_wisdom", WOOD_SRC, trunk, tint=(0.36, 0.3, 0.27)))
    for x, y, s, r in [(30, 660, 0.42, 10), (20, 850, 0.35, -20), (95, 760, 0.3, 30), (640, 720, 0.3, 0), (700, 880, 0.35, 15)]:
        L.append(spr("dirt_rock", x, y, s, r, tint=(0.45, 0.38, 0.33)))

    # ------------------------------------------------------------ tree of wisdom stump + grassy hill on the left
    L.append(fit("tree_of_wisdom", button="tree"))
    hill = [(-10, 50), (110, 32), (230, 14), (290, -10), (330, -10), (320, 90), (300, 170), (380, 230), (470, 262),
            (330, 320), (200, 385), (100, 475), (30, 570), (-10, 640)]
    L.append(poly("grass_strip", GRASS_SRC, hill, tint=(0.66, 0.72, 0.52)))
    L += scatter(hill, ["grass_tuft1", "grass_tuft3"], (70, 52), (0.32, 0.45), (0.55, 0.66, 0.42))
    for x, y in along(hill[:9], 34):  # blade tips along the hill's upper and right edges
        L.append(spr(rng.choice(["grass_tuft1", "grass_tuft3"]), round(x), round(y - 8), round(rng.uniform(0.42, 0.55), 2),
                     round(rng.uniform(-12, 12), 1), tint=(0.66, 0.76, 0.5), mirror=rng.random() < 0.5))
    L.append(spr("flower_red", 148, 183, 0.7, flower=True))

    # ------------------------------------------------------------ right side: meadow, bushes, grass slope, path
    meadow = [(1100, 760), (2150, 700), (2150, 930), (1100, 930)]
    L.append(poly("grass_strip", GRASS_SRC, meadow, tint=(0.72, 0.8, 0.6)))
    for x, y, s, t in [(1290, 740, 1.3, 0.78), (1480, 730, 1.4, 0.78), (1700, 720, 1.35, 0.78), (1900, 735, 1.4, 0.78),
                       (2100, 720, 1.35, 0.78), (1400, 810, 1.7, 1.0), (1620, 830, 1.8, 1.0), (1860, 815, 1.7, 1.0),
                       (2080, 830, 1.8, 1.0)]:
        L.append(spr("bush_plain", x, y, s, round(rng.uniform(-8, 8), 1), tint=(t, t, round(t * 0.95, 3)), mirror=rng.random() < 0.5))
    L.append(spr("bush_berries", 990, 745, 1.55, 3))
    L.append(spr("bush_berries", 1180, 800, 1.3, -6))

    slope = [(860, 960), (1000, 900), (1200, 880), (1340, 890), (1390, 1000), (1460, 1110), (1510, 1210), (960, 1210),
             (1060, 1140), (960, 1040)]
    L.append(poly("grass_strip", GRASS_SRC, slope, tint=(1.0, 1.0, 0.85)))
    L += scatter(slope, ["grass_tuft1", "grass_tuft3"], (72, 54), (0.35, 0.5), (0.9, 1.0, 0.8))

    path = [(1290, 905), (1400, 875), (1560, 870), (1780, 872), (1930, 895), (2020, 960), (1990, 1070), (1900, 1210),
            (1470, 1210), (1420, 1110), (1350, 1010)]
    L.append(poly("dirt_rock", DIRT_SRC, path, outline=(0, 7)))
    corner = [(1930, 895), (2150, 860), (2150, 1210), (1900, 1210), (1990, 1070), (2020, 960)]
    L.append(poly("grass_strip", GRASS_SRC, corner, tint=(1.0, 1.0, 0.85)))
    L += scatter(corner, ["grass_tuft1", "grass_tuft3"], (72, 54), (0.35, 0.5), (0.9, 1.0, 0.8))
    for x, y, s in [(1470, 1150, 0.9), (1530, 1000, 0.7), (1640, 1070, 0.8), (1780, 950, 0.6), (1840, 1120, 0.9), (1930, 990, 0.7)]:
        L.append(pebble(x, y, s))
    for i in range(12):  # grey stones along the path's left edge
        t = i / 11
        L.append(spr("dirt_rock", round(1325 + 170 * t), round(910 + 300 * t), 0.14, round(rng.uniform(0, 90), 1),
                     tint=(0.62, 0.66, 0.72)))

    # ------------------------------------------------------------ dirt ground under the vases
    ground = [(280, 1040), (540, 990), (640, 956), (760, 946), (870, 975), (960, 1040), (1060, 1140), (1100, 1210), (280, 1210)]
    L.append(poly("dirt_rock", DIRT_SRC, ground, outline=(1, 7)))
    for x, y, s in [(620, 1180, 0.7), (740, 1150, 0.55), (905, 1150, 0.6), (560, 1060, 0.45), (980, 1180, 0.45), (455, 1195, 0.6)]:
        L.append(pebble(x, y, s))

    # ------------------------------------------------------------ extra menu entries in the 16:9 extension
    L += [
        spr("user_bar", 1955, 898, 0.66, 3, button="editor", label="Level Editor", ui=True),
        spr("user_bar", 1955, 966, 0.66, -4, button="achievements", label="Achievements", ui=True),
        spr("user_bar", 1955, 1034, 0.66, 2, button="quick_play", label="Quick Play", ui=True),
        spr("user_bar", 1955, 1102, 0.66, -2, button="social", label="Social", ui=True),
        spr("user_bar", 1955, 1170, 0.66, 3, button="credits", label="[CREDITS]", ui=True),
    ]

    # ------------------------------------------------------------ spritesheet pieces at their mockup positions
    L += [
        fit("island"),
        spr("leaf1", 430, 372, 0.85, -25),
        fit("bush_skull"),
        fit("shop_key", button="store", fade=True),
        fit("almanac", button="almanac", fade=True),
        fit("tombstone", ui=True, name_bar=True),
        fit("skull_wings", ui=True),
        fit("btn_adventure", button="adventure", ui=True, level_plaque=True),
        fit("btn_minigames", button="minigame", ui=True),
        fit("btn_puzzle", button="puzzle", ui=True),
    ]
    px, py, ps, pr = FITS["btn_puzzle"]
    d = 170 * ps / 2 + 6 + 182 * 0.85 / 2   # survival sits beside puzzle in the tombstone's third slot
    a = math.radians(pr)
    L.append(spr("btn_survival", round(px + math.cos(a) * d, 1), round(py + math.sin(a) * d, 1), 0.85, pr, button="survival", ui=True))
    L += [
        spr("grass_tuft2", 520, 990, 0.4, 5),
        fit("vase_help", button="help", ui=True),
        fit("vase_options", button="options", ui=True),
        spr("flower_pink", 838, 915, 0.72, 15, ui=True, flower=True),
        fit("vase_quit", button="quit", ui=True),
        spr("flower_red", 908, 1030, 0.35, flower=True),
        fit("zen_garden", button="zen_garden", ui=True),
        spr("flower_purple", 1122, 1128, 0.3, 10, flower=True),
        spr("flower_red", 1100, 1130, 0.35, flower=True),
        spr("flower_purple", 542, 1142, 0.9, 10, flower=True),
        spr("flower_red", 482, 1128, 1.75, -5, tint=(0.85, 0.5, 0.55), flower=True),
        spr("grass_tuft3", 70, 1170, 1.3),
        spr("grass_tuft2", 190, 1150, 1.1, 5),
        spr("grass_tuft1", 250, 1180, 0.9),
    ]
    return L


# ---------------------------------------------------------------- GDScript emission
def num(v):
    return repr(round(float(v), 4))


def gd_value(key, v):
    if key in ("pos", "scale"):
        return f"Vector2({num(v[0])}, {num(v[1])})"
    if key == "src":
        return f"Rect2({', '.join(num(c) for c in v)})"
    if key == "tint":
        return f"Color({', '.join(num(c) for c in v)})"
    if key == "outline":
        return f"Vector2i({v[0]}, {v[1]})"
    if key == "poly":
        return "[" + ", ".join(f"Vector2({num(x)}, {num(y)})" for x, y in v) + "]"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return f'"{v}"'
    return num(v)


def emit(layout):
    lines = [
        "class_name MainMenuLayout",
        "extends RefCounted",
        "## GENERATED by tools/menu_layout/build_layout.py - edit that script, not this file.",
        "## Main menu scene in design pixels (DESIGN_SIZE, drawn at DESIGN_SCALE). Draw order is list order.",
        "## Sprite keys: img, pos (centre), scale, rot (clockwise degrees), src, tint, mirror, additive,",
        "## cloud, flower, button, label, ui (slides in), fade (fades in), level_plaque, name_bar.",
        "## Polygon keys: poly, img, src (texture region stretched over the polygon's bounds), tint, outline (edge range).",
        "",
        f"const DESIGN_SIZE := Vector2({DESIGN_W}, {DESIGN_H})",
        f"const DESIGN_SCALE := {DESIGN_SCALE}",
        "",
        "const ENTRIES := [",
    ]
    order = ["poly", "img", "pos", "scale", "rot", "src", "tint", "mirror", "additive", "outline"]
    for e in layout:
        keys = [k for k in order if k in e] + sorted(k for k in e if k not in order)
        if "rot" in e and e["rot"] == 0 and "poly" not in e:
            keys.remove("rot")
        if "scale" in e and tuple(e["scale"]) == (1.0, 1.0):
            keys.remove("scale")
        body = ", ".join(f'"{k}": {gd_value(k, e[k])}' for k in keys)
        lines.append(f"\t{{{body}}},")
    lines.append("]")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    layout = build()
    with open(OUT_GD, "w", encoding="utf-8", newline="\n") as f:
        f.write(emit(layout))
    print(f"{len(layout)} entries -> {os.path.relpath(OUT_GD, ROOT)}")

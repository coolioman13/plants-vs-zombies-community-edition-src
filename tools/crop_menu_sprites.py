"""Cuts the main-menu spritesheet into individual PNGs under assets/crop/.

python tools/crop_menu_sprites.py [path/to/spritesheet.png]

Sprites are found by alpha connected components (the sheet has a dark, blotchy background-removal
halo, so faint pixels are dropped and the remaining edge is re-feathered). Text baked into the sheet
that the game draws itself ("user" name bars, "LVL 0-0" plaques) is painted out, and a brightened
"_highlight" copy is written for every clickable sprite.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

SHEET = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\nik\Downloads\f3cd6c7e-09f1-40b2-9a34-e48469b64a30.png"
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "crop")

# name -> a point inside the sprite's solid area (sheet pixels)
SPRITES = {
    "tree_of_wisdom": (320, 250),
    "island": (1000, 120),
    "almanac": (100, 380),
    "flower_red": (340, 350),
    "flower_pink": (445, 350),
    "flower_purple": (590, 365),
    "leaf1": (700, 365),
    "leaf2": (778, 360),
    "leaf3": (760, 420),
    "tombstone": (220, 700),
    "skull_wings": (545, 455),
    "shop_key": (890, 480),
    "btn_adventure": (565, 560),
    "btn_minigames": (565, 670),
    "btn_puzzle": (480, 772),
    "btn_survival": (660, 765),
    "user_bar": (570, 862),
    "vase_help": (825, 650),
    "vase_options": (948, 700),
    "vase_quit": (1065, 700),
    "zen_garden": (1330, 690),
    "bush_berries": (850, 840),
    "bush_plain": (1040, 850),
    "bush_skull": (1270, 850),
    "grass_strip": (430, 1030),
    "dirt_mound": (890, 1010),
    "dirt_rock": (1100, 1010),
    "grass_tuft1": (1305, 985),
    "grass_tuft2": (1232, 1030),
    "grass_tuft3": (1365, 1040),
}
HIGHLIGHT = ["btn_adventure", "btn_minigames", "btn_puzzle", "btn_survival", "vase_help", "vase_options", "vase_quit",
             "zen_garden", "shop_key", "almanac", "user_bar", "tree_of_wisdom"]
PAD = 2


def quit_vase_mask(rgba: np.ndarray) -> np.ndarray:
    # The quit vase's flower overlaps the island's hanging root; split them by hand, using the petal
    # colour (plus its outline) where they touch.
    h, w = rgba.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    r, g = rgba[:, :, 0].astype(np.int32), rgba[:, :, 1].astype(np.int32)
    zone = (yy >= 540) & (yy < 620) & (xx >= 1090) & (xx < 1125)
    pink = zone & (r > 150) & (r - g > 40)
    pink = ndimage.binary_dilation(pink, iterations=3) & zone
    return ((yy >= 540) & (xx < 1090)) | ((yy >= 620) & (xx < 1130)) | pink


def main() -> None:
    rgba = np.array(Image.open(SHEET).convert("RGBA"))
    h, w = rgba.shape[:2]
    alpha = rgba[:, :, 3].astype(np.float32)

    core = alpha > 64
    labels, _ = ndimage.label(core)
    island_id = labels[120, 1000]
    labels[(labels == island_id) & quit_vase_mask(rgba)] = labels.max() + 1
    quit_id = labels.max()

    # Every visible pixel belongs to its nearest solid component.
    _, (iy, ix) = ndimage.distance_transform_edt(labels == 0, return_indices=True)
    owner = labels[iy, ix]

    # Re-feather the edge: drop the halo, ramp alpha 48..160 -> 0..255.
    clean_alpha = np.clip((alpha - 48.0) / (160.0 - 48.0), 0.0, 1.0) * 255.0

    os.makedirs(OUT, exist_ok=True)
    for name, (px, py) in SPRITES.items():
        cid = quit_id if name == "vase_quit" else labels[py, px]
        assert cid != 0, name
        mask = (owner == cid) & (clean_alpha > 0)
        speck_lab, speck_n = ndimage.label(mask)
        speck_sizes = ndimage.sum(mask, speck_lab, range(1, speck_n + 1))
        mask &= np.isin(speck_lab, [i + 1 for i, size in enumerate(speck_sizes) if size >= 40])
        ys, xs = np.nonzero(mask)
        x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + 1 + PAD, w)
        y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + 1 + PAD, h)
        out = rgba[y0:y1, x0:x1].copy()
        out[:, :, 3] = np.where(mask[y0:y1, x0:x1], clean_alpha[y0:y1, x0:x1], 0).astype(np.uint8)
        paint_out_text(name, out)
        Image.fromarray(out).save(os.path.join(OUT, name + ".png"))
        if name in HIGHLIGHT:
            Image.fromarray(highlight(out)).save(os.path.join(OUT, name + "_highlight.png"))
        print(f"{name:16s} sheet=({x0},{y0}) size={x1 - x0}x{y1 - y0}")


def erase_text(img: np.ndarray, box) -> None:
    """Paints light glyphs inside a dark name/level pill with the pill colour. Light blobs touching the
    box edge belong to the pill's border and are left alone."""
    x0, y0, x1, y1 = box
    region = img[y0:y1, x0:x1]
    rgb = region[:, :, :3].astype(np.int32)
    lum = rgb.sum(axis=2)
    lab, n = ndimage.label(lum > 240)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])))
    glyphs = np.isin(lab, [i for i in range(1, n + 1) if i not in edge])
    border = np.isin(lab, [i for i in edge if i != 0])
    fill = np.median(rgb[(lum < 150) & ~ndimage.binary_dilation(glyphs, iterations=5)], axis=0).astype(np.uint8)
    # the glyphs' own dark outline is a shade darker than the pill, so take a wide margin around them
    glyphs = ndimage.binary_dilation(glyphs, iterations=4) & ~ndimage.binary_dilation(border, iterations=2)
    region[glyphs, :3] = fill


def paint_out_text(name: str, img: np.ndarray) -> None:
    """Boxes are local to each crop (see the sizes this script prints)."""
    if name == "tombstone":
        erase_text(img, (190, 575, 280, 618))   # player name on the base
        erase_text(img, (204, 249, 276, 267))   # level plaque over the first slot
    elif name == "user_bar":
        erase_text(img, (100, 24, 205, 58))
    elif name == "btn_adventure":
        erase_text(img, (127, 18, 197, 36))


def highlight(img: np.ndarray) -> np.ndarray:
    out = img.copy()
    rgb = out[:, :, :3].astype(np.float32)
    out[:, :, :3] = np.clip(rgb * 1.12 + 28.0, 0, 255).astype(np.uint8)
    return out


if __name__ == "__main__":
    main()

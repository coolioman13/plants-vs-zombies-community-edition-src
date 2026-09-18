"""One-time asset preparation for formats Godot can't import.
- .gif images -> .png (same base name; PopCap loader treats extensions as interchangeable)
- .au sounds  -> .ogg (needs ffmpeg on PATH)
Music stems are produced separately by tools/render_music.py.
"""
import pathlib, subprocess
from PIL import Image
ROOT = pathlib.Path(__file__).resolve().parent.parent
for gif in list(ROOT.glob("images/**/*.gif")) + list(ROOT.glob("data/*.gif")) + list(ROOT.glob("particles/*.gif")) + list(ROOT.glob("reanim/*.gif")):
    png = gif.with_suffix(".png")
    if png.exists():
        continue
    im = Image.open(gif)
    # PopCap reads alpha masks from the blue channel; palette GIFs convert losslessly to RGB(A).
    im = im.convert("RGBA")
    im.save(png)
    print("gif ->", png.relative_to(ROOT))
for au in ROOT.glob("sounds/*.au"):
    ogg = au.with_suffix(".ogg")
    if ogg.exists():
        continue
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(au), "-c:a", "libvorbis", "-q:a", "6", str(ogg)], check=True)
    print("au  ->", ogg.relative_to(ROOT))

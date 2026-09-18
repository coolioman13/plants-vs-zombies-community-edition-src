"""Renders PvZ's tracker music (mainmusic.mo3 / mainmusic_hihats.mo3) into looping OGG stems.

PvZ plays one MO3 module through BASS and mutes/unmutes channel groups at runtime to layer drums and
hi-hats (Music.cpp). Godot can't play MO3, so every tune is pre-rendered per channel group from the
same start order, with identical lengths, plus a timeline of (sample, order, row) so the game can
switch layers on exactly the same musical boundaries the original did.

Requires a 64-bit bass.dll (BASS 2.4, which decodes MO3) and ffmpeg on PATH.
Usage: python tools/render_music.py [path\\to\\bass.dll]
"""
import ctypes, json, os, pathlib, struct, subprocess, sys, wave

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASS_DLL = sys.argv[1] if len(sys.argv) > 1 else r"C:\Program Files (x86)\Steam\steamapps\common\GarrysMod\bin\win64\bass.dll"
OUT = ROOT / "music"
RATE = 44100
CHUNK = 64  # samples per decode step (~1.5ms) for accurate order/row timing

BASS_SAMPLE_FLOAT = 0x100
BASS_MUSIC_RAMP = 0x200
BASS_MUSIC_POSRESET = 0x8000
BASS_MUSIC_DECODE = 0x200000
BASS_POS_MUSIC_ORDER = 1
BASS_ATTRIB_MUSIC_PSCALER = 0x102
BASS_ATTRIB_MUSIC_VOL_CHAN = 0x200
BASS_DATA_FLOAT = 0x40000000

bass = ctypes.WinDLL(BASS_DLL)
bass.BASS_Init.argtypes = [ctypes.c_int, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_void_p]
bass.BASS_MusicLoad.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint64, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32]
bass.BASS_MusicLoad.restype = ctypes.c_uint32
bass.BASS_MusicFree.argtypes = [ctypes.c_uint32]
bass.BASS_ChannelSetAttribute.argtypes = [ctypes.c_uint32, ctypes.c_uint32, ctypes.c_float]
bass.BASS_ChannelSetPosition.argtypes = [ctypes.c_uint32, ctypes.c_uint64, ctypes.c_uint32]
bass.BASS_ChannelGetPosition.argtypes = [ctypes.c_uint32, ctypes.c_uint32]
bass.BASS_ChannelGetPosition.restype = ctypes.c_uint64
bass.BASS_ChannelGetData.argtypes = [ctypes.c_uint32, ctypes.c_void_p, ctypes.c_uint32]
bass.BASS_ChannelGetData.restype = ctypes.c_uint32
bass.BASS_ErrorGetCode.restype = ctypes.c_int
if not bass.BASS_Init(0, RATE, 0, None, None):
    raise SystemExit("BASS_Init failed %d" % bass.BASS_ErrorGetCode())

def load(path):
    p = str(path).encode("mbcs")
    h = bass.BASS_MusicLoad(False, p, 0, 0, BASS_MUSIC_DECODE | BASS_SAMPLE_FLOAT | BASS_MUSIC_RAMP | BASS_MUSIC_POSRESET, RATE)
    if not h:
        raise SystemExit("BASS_MusicLoad failed for %s: %d" % (path, bass.BASS_ErrorGetCode()))
    bass.BASS_ChannelSetAttribute(h, BASS_ATTRIB_MUSIC_PSCALER, 1.0)
    return h

def set_channels(h, groups, count=30):
    for ch in range(count):
        on = any(a <= ch <= b for a, b in groups)
        bass.BASS_ChannelSetAttribute(h, BASS_ATTRIB_MUSIC_VOL_CHAN + ch, 1.0 if on else 0.0)

def get_pos(h):
    v = bass.BASS_ChannelGetPosition(h, BASS_POS_MUSIC_ORDER)
    return v & 0xFFFF, (v >> 16) & 0xFFFF

def render(module, start_order, groups, max_samples=None, detect_loop=True):
    """Returns (float32 stereo bytes, timeline, loop_start_sample)."""
    h = load(module)
    set_channels(h, groups)
    bass.BASS_ChannelSetPosition(h, start_order & 0xFFFF, BASS_POS_MUSIC_ORDER)
    buf = (ctypes.c_float * (CHUNK * 2))()
    data = bytearray()
    timeline = []
    seen = {}
    loop_start = 0
    total = 0
    last = None
    limit = max_samples if max_samples is not None else RATE * 900
    while total < limit:
        pos = get_pos(h)
        if pos != last:
            if detect_loop and max_samples is None and pos in seen and last is not None:
                loop_start = seen[pos]
                break
            seen.setdefault(pos, total)
            timeline.append([total, pos[0], pos[1]])
            last = pos
        want = min(CHUNK, limit - total)
        got = bass.BASS_ChannelGetData(h, buf, (want * 2 * 4) | BASS_DATA_FLOAT)
        if got == 0xFFFFFFFF or got == 0:
            break
        data += bytes(buf)[:got]
        total += got // 8
    bass.BASS_MusicFree(h)
    return data, timeline, loop_start, total

def write_ogg(name, data):
    wav = OUT / (name + ".wav")
    ints = bytearray()
    for (sample,) in struct.iter_unpack("<f", data):
        ints += struct.pack("<h", max(-32768, min(32767, int(sample * 32767))))
    with wave.open(str(wav), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(ints))
    ogg = OUT / (name + ".ogg")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "7", str(ogg)], check=True)
    wav.unlink()

MAIN = ROOT / "sounds" / "mainmusic.mo3"
HIHATS = ROOT / "sounds" / "mainmusic_hihats.mo3"
ALL = [(0, 29)]

# tune -> (start order, main groups, drums groups, hihat groups (from hihats module))
TUNES = {
    "grasswalk":     (0x00, [(0, 23)], [(24, 26)], [(27, 27)]),
    "wateryg":       (0x5E, [(0, 17)], [(25, 28)], [(18, 24), (29, 29)]),
    "rigormormist":  (0x7D, [(0, 15)], [(16, 22)], [(23, 23)]),
    "grazetheroof":  (0xB8, [(0, 17)], [(18, 20)], [(21, 21)]),
    "moongrains":    (0x30, ALL, None, None),
    "chooseseeds":   (0x7A, ALL, None, None),
    "crazydave":     (0x98, ALL, None, None),
    "zengarden":     (0xDD, ALL, None, None),
    "cerebrawl":     (0xB1, ALL, None, None),
    "loonboon":      (0xA6, ALL, None, None),
    "ultimatebattle":(0xD4, ALL, None, None),
    "brainiacmaniac":(0x9E, ALL, None, None),
}

def main():
    OUT.mkdir(exist_ok=True)
    only = set(os.environ.get("ONLY", "").split(",")) - {""}
    meta = {}
    for name, (order, main_g, drum_g, hihat_g) in TUNES.items():
        if only and name not in only:
            continue
        data, timeline, loop_start, total = render(MAIN, order, main_g)
        print("%-15s %.1fs loop@%.2fs" % (name, total / RATE, loop_start / RATE))
        write_ogg(name + "_main", data)
        entry = {"length": total, "loop_start": loop_start, "timeline": timeline, "rate": RATE}
        if drum_g:
            d, _, _, _ = render(MAIN, order, drum_g, max_samples=total)
            write_ogg(name + "_drums", d)
        if hihat_g:
            hh, _, _, _ = render(HIHATS, order, hihat_g, max_samples=total)
            write_ogg(name + "_hihats", hh)
        meta[name] = entry
    # Moongrains burst: the drum module jumps to order 76 or 77 (Music::UpdateMusicBurst, scheme 2).
    for burst_order in (76, 77):
        if only and "moongrains" not in only:
            continue
        data, timeline, loop_start, total = render(MAIN, burst_order, ALL)
        name = "moongrains_burst%d" % burst_order
        print("%-15s %.1fs loop@%.2fs" % (name, total / RATE, loop_start / RATE))
        write_ogg(name, data)
        meta[name] = {"length": total, "loop_start": loop_start, "timeline": timeline, "rate": RATE}
    existing = {}
    meta_path = OUT / "music.json"
    if meta_path.exists():
        existing = json.loads(meta_path.read_text())
    existing.update(meta)
    meta_path.write_text(json.dumps(existing))

if __name__ == "__main__":
    main()

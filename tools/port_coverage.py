"""Reports which decomp methods have no snake_case counterpart in the Godot port.
usage: python tools/port_coverage.py [ClassName ...]"""
import re, sys, os, glob
DECOMP = r"C:\Users\nik\Music\PVZ-QEWide-Tweaks-main"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def snake(n):
    n = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1_\2', n)
    n = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', n)
    return n.lower()

gd_funcs = set()
for f in glob.glob(os.path.join(ROOT, 'src', '**', '*.gd'), recursive=True):
    for m in re.finditer(r'^\s*(?:static\s+)?func\s+(\w+)', open(f, encoding='utf-8').read(), re.M):
        gd_funcs.add(m.group(1))

cpps = glob.glob(os.path.join(DECOMP, 'Lawn', '**', '*.cpp'), recursive=True) + [os.path.join(DECOMP, 'LawnApp.cpp')]
want = set(sys.argv[1:])
total_missing = 0
for cpp in sorted(cpps):
    src = open(cpp, encoding='latin1').read()
    by_class = {}
    for m in re.finditer(r'^[\w\*&<>:\s]*?\b(\w+)::(~?\w+)\s*\(', src, re.M):
        cls, fn = m.group(1), m.group(2)
        if fn.startswith('~') or fn == cls:
            continue
        by_class.setdefault(cls, []).append(fn)
    for cls, fns in by_class.items():
        if want and cls not in want:
            continue
        missing = sorted({f for f in fns if snake(f) not in gd_funcs})
        total_missing += len(missing)
        if missing:
            print(f"{cls} ({os.path.basename(cpp)}): {len(missing)}/{len(set(fns))} missing")
            print("   " + ", ".join(missing))
print("total missing:", total_missing)

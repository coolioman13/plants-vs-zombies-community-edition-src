"""Two-process multiplayer test: starts a headless host and client on localhost, lets both auto-play a match and
checks that their boards stayed identical (NETHASH lines), that chat works and that the client is sent back to the
menu when the host leaves.

python tools/net_test.py [path/to/godot_console.exe] [coop|versus] [seconds] [corrupt|clientleave|hostend]
"""
import os
import re
import subprocess
import sys
import threading

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = sys.argv[1] if len(sys.argv) > 1 else "godot"
MODE = sys.argv[2] if len(sys.argv) > 2 else "coop"
SECONDS = sys.argv[3] if len(sys.argv) > 3 else "40"
VARIANT = sys.argv[4] if len(sys.argv) > 4 else ""   # corrupt | clientleave | hostend
CORRUPT = VARIANT == "corrupt"   # client breaks its board once: checks the resync
PORT = "24651"


def run(role, out):
    cmd = [GODOT, "--headless", "--path", ROOT, "res://tools/net_test.tscn", "--", role, PORT, MODE, SECONDS] + ([VARIANT] if VARIANT else [])
    p = subprocess.run(cmd, capture_output=True, text=True, errors="replace")
    out[role] = (p.returncode, p.stdout + p.stderr)


def main():
    out = {}
    host = threading.Thread(target=run, args=("host", out))
    host.start()
    import time
    time.sleep(9)
    client = threading.Thread(target=run, args=("client", out))
    client.start()
    host.join()
    client.join()
    ok = True
    hashes = {}
    for role in ("host", "client"):
        code, log = out[role]
        interesting = [l for l in log.splitlines() if l.startswith(("PASS", "FAIL", "RESULT", "PHASE", "SCRIPT ERROR", "net:", "CORRUPTED"))]
        print(f"===== {role} (exit {code})")
        print("\n".join(interesting))
        errors = [l for l in log.splitlines() if "SCRIPT ERROR" in l]
        if code != 0 or errors or any(l.startswith("FAIL") for l in interesting):
            ok = False
            if errors:
                idx = log.find("SCRIPT ERROR")
                print(log[idx: idx + 1500])
            else:
                tail = [l for l in log.splitlines() if l.strip() and "leaked" not in l and not l.strip().startswith("at:") and "NETHASH" not in l]
                print("\n".join(tail[-25:]))
        hashes[role] = dict((int(f), v) for f, v in re.findall(r"NETHASH (\d+) (-?\d+)", log))
    common = sorted(set(hashes["host"]) & set(hashes["client"]))
    mismatched = [f for f in common if hashes["host"][f] != hashes["client"][f]]
    print(f"===== compared {len(common)} checksums, {len(mismatched)} mismatched" + (f" (first at frame {mismatched[0]})" if mismatched else ""))
    if CORRUPT:
        # the drift must be detected and repaired: mismatches are allowed only right after the corruption
        late = [f for f in mismatched if f > (mismatched[0] + 1000 if mismatched else 0)]
        resynced = "resyncs=1" in out["client"][1] or "resyncs=2" in out["client"][1]
        print(f"===== corruption test: resynced={resynced}, mismatches that stayed unrepaired={len(late)}")
        if not mismatched or late or not resynced:
            ok = False
    elif not common or mismatched:
        ok = False
    print("NET TEST", "PASSED" if ok else "FAILED")
    sys.exit(0 if ok else 1)


main()

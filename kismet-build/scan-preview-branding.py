#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("kismet-build/work/live-rootfs-edit")
TERMS = [
    b"Install Ubuntu",
    b"Welcome to Ubuntu",
    b"Preparing Ubuntu",
    b"Ubuntu 24.04.3 LTS",
    b"Ubuntu 24.04",
]
SKIP_PARTS = {
    "/usr/share/locale/",
    "/usr/share/locale-langpack/",
    "/var/lib/dpkg/",
    "/var/lib/apt/",
    "/usr/lib/python3/dist-packages/DistUpgrade/",
    "/usr/lib/python3/dist-packages/HweSupportStatus/",
    "/var/log/",
}
SKIP_SUFFIX_PATHS = {
    "/usr/libexec/gnome-initial-setup",
}
SKIP_SUFFIXES = {
    ".pyc", ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".svgz", ".ttf", ".otf", ".woff", ".woff2", ".so", ".a", ".o",
}

hits: list[tuple[str, list[str]]] = []
for path in ROOT.rglob("*"):
    if not path.is_file():
        continue
    sp = "/" + path.as_posix().lstrip("/")
    if any(sp.endswith(suffix) for suffix in SKIP_SUFFIX_PATHS):
        continue
    if any(part in sp for part in SKIP_PARTS):
        continue
    if path.suffix.lower() in SKIP_SUFFIXES:
        continue
    try:
        data = path.read_bytes()
    except Exception:
        continue
    found = [term.decode("utf-8", "ignore") for term in TERMS if term in data]
    if found:
        hits.append((sp, found))

if not hits:
    print("No non-whitelisted Ubuntu branding hits found.")
    raise SystemExit(0)

for path, found in hits:
    print(path)
    for term in found:
        print(f"  {term}")
raise SystemExit(1)

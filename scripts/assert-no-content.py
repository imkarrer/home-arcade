#!/usr/bin/env python3
"""Fail if staged or tracked files look like game content or secrets."""
import subprocess
import sys

FORBIDDEN_EXT = {
    ".zip",
    ".7z",
    ".rar",
    ".sfc",
    ".smc",
    ".z64",
    ".n64",
    ".v64",
    ".iso",
    ".cue",
    ".bin",
    ".img",
    ".ima",
    ".dosz",
    ".chd",
    ".rvz",
    ".wad",
    ".nes",
    ".dll",
    ".exe",
    ".so",
    ".dylib",
}
FORBIDDEN_NAMES = {"hub.json"}
FORBIDDEN_DIRS = ("roms/", "cores/", "saves/", "secrets/")


def tracked():
    out = subprocess.check_output(["git", "ls-files", "-z"], text=True)
    return [p for p in out.split("\0") if p]


def main() -> int:
    bad = []
    for path in tracked():
        lower = path.replace("\\", "/").lower()
        if any(lower == d or lower.startswith(d) for d in FORBIDDEN_DIRS):
            bad.append(path)
            continue
        name = lower.rsplit("/", 1)[-1]
        if name in FORBIDDEN_NAMES:
            bad.append(path)
            continue
        for ext in FORBIDDEN_EXT:
            if lower.endswith(ext):
                bad.append(path)
                break
    if bad:
        print("refusing to keep game content or secrets in git:")
        for p in bad:
            print(f"  {p}")
        return 1
    print("ok: no roms, zips, cores, or hub.json in git")
    return 0


if __name__ == "__main__":
    sys.exit(main())

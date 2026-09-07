#!/usr/bin/env python3
"""Download Mindustry server/client and a Windows JRE onto the hub. Not for git."""
import shutil
import urllib.request
import zipfile
from pathlib import Path

VER = "v159.7"
BASE = f"https://github.com/Anuken/Mindustry/releases/download/{VER}/"
JRE = "https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jre/hotspot/normal/eclipse?project=jdk"

srv = Path("/var/lib/arcade/mindustry")
cli = Path("/srv/arcade/apps/windows/mindustry")
jre = Path("/srv/arcade/apps/windows/jre")
tmp = Path("/tmp/arcade-mindustry")
tmp.mkdir(parents=True, exist_ok=True)
srv.mkdir(parents=True, exist_ok=True)
cli.mkdir(parents=True, exist_ok=True)


def pull(url: str, dest: Path) -> None:
    print("get", dest.name, flush=True)
    dest.parent.mkdir(parents=True, exist_ok=True)
    urllib.request.urlretrieve(url, dest)
    print(" ok", dest, dest.stat().st_size, flush=True)


pull(BASE + "server-release.jar", srv / "server-release.jar")
pull(BASE + "Mindustry.jar", cli / "Mindustry.jar")

zpath = tmp / "jre.zip"
pull(JRE, zpath)
unpack = tmp / "jre-unpack"
if unpack.exists():
    shutil.rmtree(unpack)
unpack.mkdir()
with zipfile.ZipFile(zpath) as z:
    z.extractall(unpack)
inners = [p for p in unpack.iterdir() if p.is_dir()]
src = inners[0] if len(inners) == 1 else unpack
if jre.exists():
    shutil.rmtree(jre)
shutil.copytree(src, jre)
java = jre / "bin" / "java.exe"
if not java.is_file():
    raise SystemExit(f"java.exe missing under {jre}")
print("jre", java)

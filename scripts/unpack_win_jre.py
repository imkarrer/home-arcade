#!/usr/bin/env python3
import shutil
import zipfile
from pathlib import Path

zpath = Path("/tmp/arcade-mindustry/jre.zip")
unpack = Path("/tmp/arcade-mindustry/jre-unpack")
jre = Path("/srv/arcade/apps/windows/jre")
if unpack.exists():
    shutil.rmtree(unpack)
unpack.mkdir(parents=True)
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

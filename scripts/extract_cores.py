import zipfile
from pathlib import Path

dest = Path("/srv/arcade/cores/windows/x86_64")
dest.mkdir(parents=True, exist_ok=True)
for name in ("mupen.zip", "snes.zip", "dosbox_pure.zip"):
    zipfile.ZipFile(Path("/tmp/arcade-cores") / name).extractall(dest)
print("ok", list(dest.iterdir()))

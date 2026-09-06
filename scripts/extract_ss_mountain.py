import zipfile
from pathlib import Path

src = Path("/srv/arcade/roms/dos/ss_treasure_mountain.zip")
dest = Path("/srv/arcade/roms/dos/ss_treasure_mountain")
dest.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(src) as z:
    z.extractall(dest)
print("extracted", dest, "sst", (dest / "SST.EXE").exists())

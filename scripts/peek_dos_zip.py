import zipfile
from pathlib import Path

p = Path("/srv/arcade/roms/dos/ss_treasure_mountain.zip")
print(p, "exists" if p.exists() else "MISSING", p.stat().st_size if p.exists() else "")
if p.exists() and zipfile.is_zipfile(p):
    names = zipfile.ZipFile(p).namelist()
    print("files", len(names))
    for n in names[:40]:
        print(n)
else:
    print("not a zip")

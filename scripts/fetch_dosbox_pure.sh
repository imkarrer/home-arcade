#!/bin/sh
set -eu
curl -fsSL -o /tmp/dosbox_pure.zip \
  https://buildbot.libretro.com/nightly/windows/x86_64/latest/dosbox_pure_libretro.dll.zip
python3 - <<'PY'
import zipfile
zipfile.ZipFile("/tmp/dosbox_pure.zip").extractall("/srv/arcade/cores/windows/x86_64")
print("extracted")
PY
chown arcade:arcade /srv/arcade/cores/windows/x86_64/dosbox_pure_libretro.dll
ls -l /srv/arcade/cores/windows/x86_64

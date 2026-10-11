#!/usr/bin/env python3
"""Copy each catalog "web" game that has a "page" into www/games/<id>/, from
the GitHub commit its "source" pins.

Web games ride in www/ because that is what reaches the stations without a
hand step: arcade-library-sync copies main's www/ into /srv/arcade, and
sync.ps1 pulls it to every PC, where arcade-agent.ps1 serves it. Only games
whose license lets us copy them get a "page"; the rest use "url" and are
played from the author's own site.

To move a game to a newer upstream commit, change the sha in its "source"
and run this again (inside the flox environment, for python3):

    flox activate -- python3 scripts/vendor_web_games.py
"""
from __future__ import annotations

import io
import json
import re
import shutil
import tarfile
import urllib.request
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
SOURCE_RE = re.compile(r"^https://github\.com/([\w.-]+)/([\w.-]+)/tree/([0-9a-f]{40})$")


def vendor(game: dict) -> None:
    m = SOURCE_RE.match(game["source"])
    if not m:
        raise SystemExit(f"{game['id']}: source must be https://github.com/<owner>/<repo>/tree/<full sha>")
    owner, repo, sha = m.groups()
    dest = ROOT / "www" / "games" / game["id"]
    url = f"https://codeload.github.com/{owner}/{repo}/tar.gz/{sha}"
    print(f"get {owner}/{repo}@{sha[:12]} -> {dest.relative_to(ROOT)}", flush=True)
    data = urllib.request.urlopen(url).read()
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tar:
        for member in tar.getmembers():
            # Drop the tarball's <repo>-<sha>/ prefix and anything hidden
            # (.gitignore, .github/).
            parts = PurePosixPath(member.name).parts[1:]
            if not parts or any(p.startswith(".") for p in parts) or not member.isfile():
                continue
            member.name = str(PurePosixPath(*parts))
            tar.extract(member, dest, filter="data")
    # A menu that finds its games by listing the folder (Mika's Playhouse)
    # asks for __games.json first; the agent serves files, not listings.
    pages = sorted(
        p.relative_to(dest).as_posix()
        for p in dest.rglob("*.html")
        if p.relative_to(dest).as_posix() != "index.html"
    )
    (dest / "__games.json").write_text(json.dumps(pages, indent=1) + "\n", encoding="utf-8")
    page = ROOT / game["page"]
    if not page.is_file():
        raise SystemExit(f"{game['id']}: {game['page']} is not in {owner}/{repo}@{sha[:12]}")
    print(f" ok {len(pages)} pages", flush=True)


def main() -> None:
    games = json.loads((ROOT / "catalog" / "games.json").read_text(encoding="utf-8"))["games"]
    for game in games:
        if game.get("kind") == "web" and game.get("page"):
            vendor(game)


if __name__ == "__main__":
    main()

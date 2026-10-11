#!/usr/bin/env python3
"""Copy each catalog "web" game that has a "page" into www/games/<id>/, from
the GitHub commit its "source" pins.

Web games ride in www/ because that is what reaches the stations without a
hand step: arcade-library-sync copies main's www/ into /srv/arcade, and
sync.ps1 pulls it to every PC, where arcade-agent.ps1 serves it. Only games
whose license lets us copy them get a "page"; the rest use "url" and are
played from the author's own site.

A game with scripts/vendor_patches/<id>.json gets that file's "replace"
pairs applied to its .html and .js after every download (Sofi's Games is
Hebrew upstream; the arcade plays it in English). A pair that no longer
matches stops the script, so a new upstream commit cannot quietly undo one.

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
    patch(game["id"], dest)
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


def patch(game_id: str, dest: Path) -> None:
    table = ROOT / "scripts" / "vendor_patches" / f"{game_id}.json"
    if not table.is_file():
        return
    pairs = json.loads(table.read_text(encoding="utf-8"))["replace"]
    # Longest first, so a short string never edits inside a longer one.
    order = sorted(pairs, key=len, reverse=True)
    used = set()
    for path in sorted(p for p in dest.rglob("*") if p.suffix in (".html", ".js")):
        text = path.read_text(encoding="utf-8")
        new = text
        for old in order:
            if old in new:
                new = new.replace(old, pairs[old])
                used.add(old)
        if new != text:
            path.write_text(new, encoding="utf-8")
    missing = [old for old in pairs if old not in used]
    if missing:
        raise SystemExit(f"{game_id}: {table.relative_to(ROOT)} no longer matches upstream: {missing}")
    print(f" patched {len(used)} strings", flush=True)


def main() -> None:
    games = json.loads((ROOT / "catalog" / "games.json").read_text(encoding="utf-8"))["games"]
    for game in games:
        if game.get("kind") == "web" and game.get("page"):
            vendor(game)


if __name__ == "__main__":
    main()

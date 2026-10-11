#!/usr/bin/env python3
"""Source-only checks. No ROMs, no box, no RetroArch."""
from __future__ import annotations

import ast
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ALLOWED_CORES = {
    "mupen64plus_next_libretro.dll",
    "snes9x_libretro.dll",
    "dosbox_pure_libretro.dll",
}
ALLOWED_MODES = {"solo", "host", "join"}
DOS_CORE = "dosbox_pure_libretro.dll"
ID_RE = re.compile(r"^[a-z0-9_]+$")


def load_catalog() -> list[dict]:
    data = json.loads((ROOT / "catalog" / "games.json").read_text(encoding="utf-8"))
    games = data["games"]
    if not isinstance(games, list):
        raise AssertionError("catalog.games must be a list")
    return games


def layout_names() -> set[str]:
    names = set()
    for line in (ROOT / "metadata" / "crops" / "_layouts.yaml").read_text(encoding="utf-8").splitlines():
        if not line or line.startswith(" ") or line.startswith("#") or line.startswith("-"):
            continue
        if ":" in line:
            names.add(line.split(":", 1)[0].strip())
    return names


def yaml_field(text: str, key: str) -> list[str]:
    found = []
    for line in text.splitlines():
        stripped = line.split("#", 1)[0].strip()
        if stripped.startswith(f"{key}:"):
            found.append(stripped.split(":", 1)[1].strip())
    return found


class CatalogTests(unittest.TestCase):
    def test_games_have_unique_ids_and_required_fields(self):
        seen = set()
        for game in load_catalog():
            gid = game["id"]
            self.assertRegex(gid, ID_RE)
            self.assertNotIn(gid, seen)
            seen.add(gid)
            self.assertTrue(game["title"].strip())
            modes = game.get("modes")
            if modes is not None:
                self.assertTrue(modes)
                self.assertTrue(set(modes) <= ALLOWED_MODES)
            if game.get("kind") == "web":
                self.assertEqual(modes, ["solo"], f"{gid}: a web game only has Play")
                self.assertEqual(("page" in game) + ("url" in game), 1, f"{gid}: page or url, not both")
                self.assertNotIn("rom", game)
                self.assertNotIn("exe", game)
                continue
            if game.get("kind") == "native" or game.get("exe"):
                self.assertTrue(game["exe"])
                self.assertFalse(Path(game["exe"]).is_absolute())
                continue
            self.assertIn(game["core"], ALLOWED_CORES)
            self.assertTrue(str(game["rom"]).startswith("roms/"))
            if game["core"] == DOS_CORE:
                self.assertTrue(game.get("boot"), f"{gid} needs a boot file")

    def test_native_mode_args_and_local_server(self):
        for game in load_catalog():
            if "args_by_mode" in game:
                self.assertIsInstance(game["args_by_mode"], dict)
                self.assertTrue(set(game["args_by_mode"].keys()) <= set(game["modes"]))
                for mode, args in game["args_by_mode"].items():
                    self.assertIsInstance(args, list)
                    self.assertTrue(args)
                    self.assertTrue(all(isinstance(arg, str) for arg in args))
            if "local_server" in game:
                self.assertIn("solo", game["modes"])
                local_server = game["local_server"]
                self.assertTrue(local_server["exe"].startswith("apps/"))
                self.assertFalse(Path(local_server["exe"]).is_absolute())
                self.assertIsInstance(local_server["port"], int)
                # Check for either args or args_by_mode
                if "args" in local_server:
                    self.assertIsInstance(local_server["args"], list)
                    for arg in local_server["args"]:
                        self.assertIsInstance(arg, str)
                elif "args_by_mode" in local_server:
                    self.assertIsInstance(local_server["args_by_mode"], dict)
                    for mode, args in local_server["args_by_mode"].items():
                        self.assertIsInstance(args, list)
                        for arg in args:
                            self.assertIsInstance(arg, str)
                else:
                    self.fail(f"local_server must have either 'args' or 'args_by_mode'")
            if game["id"] == "freeciv":
                self.assertIn("args_by_mode", game)
                self.assertIn("local_server", game)
                # Verify the freeciv-host.serv file exists and contains the correct line
                serv_file = ROOT / "catalog" / "freeciv-host.serv"
                self.assertTrue(serv_file.is_file())
                # Read the file and check that it contains the expected command line
                content = serv_file.read_text(encoding="utf-8")
                self.assertIn("cmdlevel hack first", content)
                # Verify the local_server args_by_mode contains host key with 0.0.0.0 and --read
                local_server = game["local_server"]
                args_by_mode = local_server["args_by_mode"]
                self.assertIn("host", args_by_mode)
                host_args = args_by_mode["host"]
                self.assertIn("--bind", host_args)
                bind_index = host_args.index("--bind")
                self.assertTrue(bind_index + 1 < len(host_args))
                self.assertEqual(host_args[bind_index + 1], "0.0.0.0")
                self.assertIn("--read", host_args)
                read_index = host_args.index("--read")
                self.assertTrue(read_index + 1 < len(host_args))
                self.assertEqual(host_args[read_index + 1], "{root}/catalog/freeciv-host.serv")
                # Verify the solo args contain 127.0.0.1 and --read
                self.assertIn("solo", args_by_mode)
                solo_args = args_by_mode["solo"]
                self.assertIn("--bind", solo_args)
                bind_index = solo_args.index("--bind")
                self.assertTrue(bind_index + 1 < len(solo_args))
                self.assertEqual(solo_args[bind_index + 1], "127.0.0.1")
                self.assertIn("--read", solo_args)
                read_index = solo_args.index("--read")
                self.assertTrue(read_index + 1 < len(solo_args))
                self.assertEqual(solo_args[read_index + 1], "{root}/catalog/freeciv-local.serv")
                # Verify freeciv_family entry has {hub} in args
                freeciv_family = None
                for g in load_catalog():
                    if g["id"] == "freeciv_family":
                        freeciv_family = g
                        break
                self.assertIsNotNone(freeciv_family)
                self.assertIn("{hub}", freeciv_family["args"])

    def test_mode_labels(self):
        for game in load_catalog():
            if "mode_labels" in game:
                self.assertTrue(set(game["mode_labels"].keys()) <= set(game["modes"]))
                for key, value in game["mode_labels"].items():
                    self.assertIsInstance(value, str)
                    self.assertTrue(value.strip())

    def test_native_env_values_are_strings(self):
        for game in load_catalog():
            if "env" not in game:
                continue
            self.assertIsInstance(game["env"], dict)
            for name, value in game["env"].items():
                self.assertRegex(name, r"^[A-Z][A-Z0-9_]*$")
                self.assertIsInstance(value, str)

    def test_mindustry_saves_in_the_profile(self):
        mindustry = next(g for g in load_catalog() if g["id"] == "mindustry")
        self.assertTrue(mindustry["env"]["MINDUSTRY_DATA_DIR"].startswith("{saves}/"))

    def test_every_game_is_on_a_shelf(self):
        shelves = json.loads((ROOT / "catalog" / "games.json").read_text(encoding="utf-8"))["shelves"]
        ids = [s["id"] for s in shelves]
        self.assertEqual(len(ids), len(set(ids)))
        for shelf in shelves:
            self.assertRegex(shelf["id"], ID_RE)
            self.assertTrue(shelf["title"].strip())
        for game in load_catalog():
            self.assertIn(game.get("shelf"), ids, f"{game['id']} is on no shelf")
            if "icon" in game:
                self.assertTrue(game["icon"].strip())

    def test_rom_paths_are_not_absolute(self):
        for game in load_catalog():
            if game.get("kind") in ("native", "web") or game.get("exe"):
                continue
            self.assertFalse(Path(game["rom"]).is_absolute())
            for alt in game.get("rom_alts") or []:
                self.assertFalse(Path(alt).is_absolute())
                self.assertTrue(alt.startswith("roms/"))


class WebGameTests(unittest.TestCase):
    """Web games: copies under www/games/<id>/ (scripts/vendor_web_games.py)
    for what we may copy, the author's site for what we may not."""

    def web_games(self) -> list[dict]:
        return [g for g in load_catalog() if g.get("kind") == "web"]

    def test_pages_come_from_a_pinned_commit(self):
        for game in self.web_games():
            if "page" not in game:
                continue
            gid = game["id"]
            self.assertTrue(game["page"].startswith(f"www/games/{gid}/"), gid)
            self.assertTrue((ROOT / game["page"]).is_file(), f"{gid}: run scripts/vendor_web_games.py")
            self.assertRegex(game["source"], r"^https://github\.com/[\w.-]+/[\w.-]+/tree/[0-9a-f]{40}$")

    def test_url_games_name_their_source(self):
        for game in self.web_games():
            if "url" in game:
                self.assertTrue(game["url"].startswith("https://"), game["id"])
                self.assertTrue(game["source"].startswith("https://github.com/"), game["id"])

    def test_every_copy_is_in_the_catalog_and_licensed(self):
        pages = {g["id"] for g in self.web_games() if "page" in g}
        games_dir = ROOT / "www" / "games"
        copies = {p.name for p in games_dir.iterdir() if p.is_dir()} if games_dir.is_dir() else set()
        self.assertEqual(copies, pages)
        for gid in copies:
            d = games_dir / gid
            readme = (d / "README.md").read_text(encoding="utf-8") if (d / "README.md").is_file() else ""
            self.assertTrue((d / "LICENSE").is_file() or "MIT" in readme, f"{gid}: no license to copy it under")

    def test_games_list_matches_the_copy(self):
        # Mika's Playhouse finds its games through __games.json.
        for game in self.web_games():
            if "page" not in game:
                continue
            d = ROOT / "www" / "games" / game["id"]
            listed = json.loads((d / "__games.json").read_text(encoding="utf-8"))
            found = sorted(p.relative_to(d).as_posix() for p in d.rglob("*.html"))
            found.remove("index.html")
            self.assertEqual(listed, found, game["id"])

    def test_agent_types_every_file_it_serves(self):
        agent = (ROOT / "windows" / "arcade-agent.ps1").read_text(encoding="utf-8")
        typed = set(re.findall(r'"(\.[a-z0-9]+)"\s*=', agent))
        exts = {p.suffix.lower() for p in (ROOT / "www").rglob("*") if p.is_file() and p.suffix}
        self.assertEqual(exts - typed, set())


class PlayerTests(unittest.TestCase):
    def test_family_roster(self):
        data = json.loads((ROOT / "catalog" / "players.json").read_text(encoding="utf-8"))
        players = data["players"]
        ids = [p["id"] for p in players]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual([p["name"] for p in players], ["Dad", "Mom", "Calvin", "Ivy", "Faye"])
        for p in players:
            # The launcher's id for a name, and what sync accepts as a folder.
            self.assertEqual(p["id"], re.sub(r"[^a-z0-9]+", "-", p["name"].lower()).strip("-"))
            self.assertRegex(p["id"], r"^[a-z0-9-]{1,24}$")


class CropTests(unittest.TestCase):
    def test_layout_templates_exist(self):
        names = layout_names()
        self.assertIn("vertical_halves", names)
        self.assertIn("horizontal_halves", names)
        self.assertIn("quadrants", names)

    def test_crop_manifests_match_filename_and_layouts(self):
        known = layout_names()
        crop_dir = ROOT / "metadata" / "crops"
        for path in sorted(crop_dir.glob("*.yaml")):
            if path.name.startswith("_"):
                continue
            text = path.read_text(encoding="utf-8")
            game_ids = yaml_field(text, "game_id")
            self.assertEqual(game_ids, [path.stem], path.name)
            self.assertTrue(yaml_field(text, "core"), path.name)
            layouts = yaml_field(text, "use_layout")
            self.assertTrue(layouts, path.name)
            for name in layouts:
                self.assertIn(name, known, f"{path.name} unknown layout {name}")


class WwwTests(unittest.TestCase):
    def test_kid_ui_files_cross_link(self):
        html = (ROOT / "www" / "index.html").read_text(encoding="utf-8")
        js = (ROOT / "www" / "app.js").read_text(encoding="utf-8")
        self.assertIn("app.js", html)
        self.assertIn("style.css", html)
        self.assertTrue((ROOT / "www" / "style.css").is_file())
        self.assertIn("/api/games", js)
        self.assertIn("/api/play", js)
        self.assertIn("/api/players", js)
        self.assertIn("/api/player", js)
        self.assertIn('id="player"', html)
        self.assertIn("#/play/", js)


class HubExampleTests(unittest.TestCase):
    def test_example_is_not_a_real_password_file(self):
        data = json.loads((ROOT / "windows" / "hub.json.example").read_text(encoding="utf-8"))
        self.assertEqual(data["hub"], "192.168.1.50")
        self.assertEqual(data["share"], "arcade")
        self.assertEqual(data["user"], "arcade")
        self.assertIn("smb-password", data["password"])


class FlakeAndWindowsTests(unittest.TestCase):
    def test_tree_is_manifest_only(self):
        # Inverted 19 Sep 2026 (homelab ADR 0009): the box runs this tenant
        # from .flox/, homelab holds the unit skeleton, and this tree carries
        # no Nix at all. A flake or module reappearing here would be a
        # second spelling of what homelab declares.
        self.assertFalse((ROOT / "flake.nix").exists())
        self.assertFalse((ROOT / "modules").exists())
        self.assertTrue((ROOT / ".flox" / "env" / "manifest.toml").is_file())
        self.assertTrue((ROOT / ".flox" / "env" / "manifest.lock").is_file())

    def test_windows_launchers_parse_as_text(self):
        for name in ("arcade-agent.ps1", "arcade-launch.ps1", "sync.ps1", "play.ps1"):
            path = ROOT / "windows" / name
            text = path.read_text(encoding="utf-8")
            self.assertTrue(text.strip(), name)
            self.assertNotIn("\x00", text)

    def test_shader_present(self):
        self.assertTrue((ROOT / "shaders" / "arcade_split_crop.slang").is_file())


class ScriptSyntaxTests(unittest.TestCase):
    def test_python_scripts_compile(self):
        for path in sorted((ROOT / "scripts").glob("*.py")):
            source = path.read_text(encoding="utf-8")
            ast.parse(source, filename=str(path))


if __name__ == "__main__":
    unittest.main()

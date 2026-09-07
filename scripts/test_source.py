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
            if game.get("kind") == "native" or game.get("exe"):
                self.assertTrue(game["exe"])
                self.assertFalse(Path(game["exe"]).is_absolute())
                continue
            self.assertIn(game["core"], ALLOWED_CORES)
            self.assertTrue(str(game["rom"]).startswith("roms/"))
            if game["core"] == DOS_CORE:
                self.assertTrue(game.get("boot"), f"{gid} needs a boot file")

    def test_rom_paths_are_not_absolute(self):
        for game in load_catalog():
            if game.get("kind") == "native" or game.get("exe"):
                continue
            self.assertFalse(Path(game["rom"]).is_absolute())
            for alt in game.get("rom_alts") or []:
                self.assertFalse(Path(alt).is_absolute())
                self.assertTrue(alt.startswith("roms/"))


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


class HubExampleTests(unittest.TestCase):
    def test_example_is_not_a_real_password_file(self):
        data = json.loads((ROOT / "windows" / "hub.json.example").read_text(encoding="utf-8"))
        self.assertEqual(data["hub"], "192.168.1.50")
        self.assertEqual(data["share"], "arcade")
        self.assertEqual(data["user"], "arcade")
        self.assertIn("smb-password", data["password"])


class FlakeAndWindowsTests(unittest.TestCase):
    def test_flake_exports_hub_module(self):
        text = (ROOT / "flake.nix").read_text(encoding="utf-8")
        self.assertIn("nixosModules.arcade-hub", text)
        self.assertIn("./modules/arcade-hub.nix", text)
        self.assertTrue((ROOT / "modules" / "arcade-hub.nix").is_file())

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

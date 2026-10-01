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
        self.assertIn("/api/players", js)
        self.assertIn("/api/player", js)
        self.assertIn('id="player"', html)


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

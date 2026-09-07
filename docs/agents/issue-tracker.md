# Issue tracker: Beads (`bd`)

Issues and specs for this repo live in [Beads](https://github.com/gastownhall/beads), a git-friendly, dependency-aware task tracker built for AI coding agents. Data lives under `.beads/` in this repo and is committed to git so the task graph travels with the code.

If `bd` isn't on PATH yet, install it (Windows): `irm https://raw.githubusercontent.com/gastownhall/beads/main/install.ps1 | iex`, then run `bd init --quiet` once at the repo root.

## Conventions

- **Create an issue**: `bd create "<title>" -p <priority>` (add `-d "<description>"` for a body). Use `--type` to mark epics/tasks where the distinction matters.
- **Read an issue**: `bd show <id>`
- **List issues**: `bd list` (filter with its status/label flags; add `--json` for machine-readable output when scripting)
- **What's actionable right now**: `bd ready` — unblocked, unclaimed work
- **Comment on an issue**: `bd comment <id> "<text>"`
- **Apply / remove labels**: `bd label <id> ...` (run `bd label --help` for exact add/remove syntax — flags aren't pinned here since `bd` wasn't installed at setup time)
- **Claim**: `bd update <id> --claim` (atomically sets assignee + in_progress)
- **Close**: `bd close <id>`, optionally with a closing comment via `bd comment` first
- **Dependencies / blocking**: `bd dep add <child> <parent>` — `<child>` is blocked by `<parent>`. `bd blocked` lists everything currently gated on an open dependency.

Run `bd <command> --help` for exact flags when a convention above is underspecified — this file was written before `bd` was installed locally, so flag names weren't verified against a live install.

## When a skill says "publish to the issue tracker"

Run `bd create` for the item (or `bd create` once per ticket for a batch).

## When a skill says "fetch the relevant ticket"

Run `bd show <id>`. The user will normally pass the id (`bd-xxxx`, or a hierarchical child like `bd-xxxx.1`) directly.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a parent/epic issue; **children** are its sub-issues.

- **Map**: `bd create "<effort> map" --type epic`, holding the Notes / Decisions-so-far / Fog body in its description.
- **Child ticket**: `bd create "<question>" --type task`, created as a child of the map (hierarchical id, e.g. `bd-xxxx.1`). A label records the ticket type (`research`/`prototype`/`grilling`/`task`).
- **Blocking**: `bd dep add <child> <blocker>` for each dependency. A ticket is unblocked when `bd show <child>` reports no open blockers (cross-check with `bd blocked`).
- **Frontier**: `bd ready`, scoped to the map's children — first by creation order wins.
- **Claim**: `bd update <id> --claim` before any work.
- **Resolve**: `bd comment <id> "<answer>"`, then `bd close <id>`, then append a context pointer (gist + link) to the map's Decisions-so-far.

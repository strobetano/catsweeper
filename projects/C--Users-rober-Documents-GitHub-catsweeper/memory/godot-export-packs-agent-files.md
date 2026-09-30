---
name: godot-export-packs-agent-files
description: Godot exports of this project pack agent/session files (even a session .key) into the game unless the agent folders are in the preset's exclude_filter — check the packed list after every export
metadata:
  type: project
---

Both export presets use `export_filter="all_resources"`, and the repo root is also the Claude config dir, so an export packs whatever Godot recognises there: `sessions/*.json` and `sessions/*.key`, `tasks/*.json`, `cache/`, `plugins/`, `skills/` manifests and fonts, `settings.json`. On 2026-09-30 the first build-10 web export contained all of these; I added `backups/*,cache/*,plugins/*,projects/*,session-env/*,sessions/*,shell-snapshots/*,skills/*,tasks/*,settings.json,PublisherKit/*` to the `exclude_filter` of both presets in `export_presets.cfg` and re-exported. Build 9 (public since 2026-09-21) only carried the harmless `settings.json`.

**Why:** A session key or transcript inside a public APK / web build is a leak, and nothing in the export flow warns about it.

**How to apply:** After every export, list the `Storing File:` lines of the export log (or grep `index.pck` for `sessions/`, `tasks/`, `.key`) and compare with `.godot-vibe/delivery-20260908/build10/packed_old.txt` — 62 entries is the clean game. If the agent tooling grows a new top-level folder, add it to both presets' `exclude_filter`. Related: [[studio-auto-checkpoints]], [[marketing-art-pipeline]].

---
name: arsenal-deliverable
description: The Nekodoku publisher page on Arsenal (the user's own product) — what is on it, how its files are derived, and the API quirks hit when updating it
metadata:
  type: reference
---

Nekodoku's publisher-facing page lives on Arsenal (`https://arsenal.strobetano.com`, the user's own studio-workspace product; source in `C:\Users\rober\Documents\GitHub\arsenal`), deliverable id `cmubb7tav006ss56n8gwpqoi1`, published. The user pastes a fresh scoped bearer token with each request — never store it. State after 2026-09-30: Builds = Android APK + Web build at 1.0.9 (build 10); Documents = Release notes, Controls, Store listing copy (ReportLab PDFs); Marketing = packshot PSD + icons zip, store assets zip per language; cover set; gallery = the five raw 900x1400 gameplay captures; no trailer.

- Replace files in place (`POST .../items/<id>/file`) so ids and public URLs stay; new zips go in as `kind=file`, section `Marketing`.
- Cover = the English `Apple_Universal_Cover_5244x2950.png` resized to 1920x1080 with PIL LANCZOS, saved as JPEG quality 90 `optimize=True` (reproduces the old cover byte for byte).
- Uploads go through Cloudflare: a request body over 100 MB is refused with a 413 HTML page, whatever the brief says about 5 GB. Split big zips (store assets are one zip per language, ~97 MB each).
- Read-back without the token: `/api/public/deliverables/<publicToken>/cover`, `/images/<imageId>`, `/items/<itemId>/download`. Use `curl`; Python `urllib` gets 403. In Git Bash give `curl -F file=@` a `C:/...` path, not `/c/...` (exit 26).
- Release notes generator: `.godot-vibe/delivery-20260908/build10/make_release_notes.py`; zips: `make_zips.py` there.

Related: [[marketing-art-pipeline]], [[godot-export-packs-agent-files]], [[publisher-packshot-convention]].

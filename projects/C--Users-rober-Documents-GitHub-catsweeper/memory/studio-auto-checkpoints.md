---
name: studio-auto-checkpoints
description: The user's studio tool auto-commits the whole repo at every prompt ("studio checkpoint: <prompt>") and syncs to GitHub, so anything left in the repo gets committed
metadata:
  type: project
---

Every prompt the user sends is preceded by an automatic commit named `studio checkpoint: <first words of the prompt>`, made with everything in the working tree (`git add -A` style — it swept in `cache/`, `plugins/`, and the session transcript under `projects/`). Pushes show up as `chore: synchronize with remote`. The repo root doubles as the Claude config dir, which is why those folders live there.

**Why:** Seen on 2026-09-30: two checkpoint commits appeared on `main` between prompts without any commit from me, and previously untracked config folders became tracked.

**How to apply:** Do not commit or push unless asked — the next checkpoint picks up tracked-file changes anyway. Never leave scratch files in the repo: work in `%TEMP%` or in `.godot-vibe/delivery-20260908/` (excluded via `.git/info/exclude`). Watch the transcript size: `projects/.../*.jsonl` is committed too and GitHub rejects files over 100 MB. See [[marketing-art-pipeline]].

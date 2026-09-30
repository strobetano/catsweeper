---
name: marketing-art-pipeline
description: Where the Nekodoku store art and packshot PSD come from and how to rebuild them (masters, renderer, retouch script, PSD scripts, dependency gotchas)
metadata:
  type: reference
---

All store art derives from two painted masters (AI-generated, then retouched), delivered at `C:\Users\rober\Desktop\Nekodoku_App_Store_Package\01_App_Store_Assets\Shared\Hero\` (`Nekodoku_Hero_Master.png` 1536x1024, `Nekodoku_Portrait_Master.png` 1024x1536). Working folder: `.godot-vibe/delivery-20260908/` (git-excluded).

- 38 localized store images: copy the masters to `composition-inputs/Nekodoku_Muted_{Landscape,Portrait}_Master.png`, run `node render_marketing.cjs` (output in `muted-art-output/01_App_Store_Assets/`), then copy into the Desktop package. The render is deterministic: a re-render differs from the delivered PNGs only where a master changed. `muted-art-output/deliver_muted_art.py` has stale build-hash asserts — copy by hand with sha checks instead.
- The renderer needs `playwright-core` at `%TEMP%\nekodoku-web-release\node_modules\` and Windows wipes it; restore by copying `%LOCALAPPDATA%\npm-cache\_npx\e41f203b7505f1fb\node_modules\playwright-core` (1.59.1, matches chromium-1217). Never run `chrome.exe --version` on Windows: it opens a browser window.
- Packshot PSD (`PublisherKit/packshot/nekodoku-packshot-2048.psd`, tracked): scripts in `packshot-psd/` — run `segment.py`, `inpaint.py`, `build_layers.py`, `make_psd.py <out.psd>` in that order from one folder holding `big-lama.pt` (LaMa, from github.com/Sanster/models release `add_big_lama`). It crops the left 1024 px of the landscape master and upscales 2x.
- `fix_paw.py <src_dir> <dst_dir>` is the 2026-09-30 retouch that removed the cat's third front paw; the untouched originals are in `before-paw-fix/`.

Related: [[publisher-packshot-convention]], [[check-generated-art-anatomy]], [[studio-auto-checkpoints]].

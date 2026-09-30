---
name: publisher-packshot-convention
description: What the publisher (Cyril) means by "packshot" and the layout the user already uses for it across games
metadata:
  type: project
---

"Packshot" for the publisher contact Cyril = the square key art of the game, wanted as a PSD with separate layers. The user's established layout is `PublisherKit/packshot/<game>-packshot-2048.psd`: 2048x2048, 8-bit RGB, named layers bottom-to-top (background, character/dressing, title) plus a merged preview.

**Why:** The precedent is the Strobeat kit in `C:\Users\rober\Documents\GitHub\spordbeat\PublisherKit\packshot\` (PSD + PNG + `layers/` folder); the Nekodoku one was built to match on 2026-09-29.

**How to apply:** For any new publisher asset request, look at that Strobeat kit first and mirror its names and sizes. How the Nekodoku PSD is built: [[marketing-art-pipeline]].

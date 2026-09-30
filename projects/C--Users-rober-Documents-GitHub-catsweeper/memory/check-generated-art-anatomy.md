---
name: check-generated-art-anatomy
description: User caught a cat with three front paws in delivered key art — check anatomy of generated or retouched character art before handing it over
metadata:
  type: feedback
---

Before delivering any generated or retouched character art, count limbs and check the pose makes physical sense. On 2026-09-30 the user spotted that the waving Nekodoku cat had its raised paw plus two front paws on the ground, and wanted it fixed "on all assets" (both hero masters, the 38 store images, the packshot PSD).

**Why:** The art had already gone out to the publisher (Cyril); the mistake came from the AI-generated masters and nobody checked it, including me when I built the PSD from that painting.

**How to apply:** Zoom in on hands, paws, legs, tails and eyes of every character before calling art done, and compare against the in-game sprite (`assets/art/catsweeper_chibi_states.png`, which is correct: one paw waving, one on the ground). A fix to a master must be propagated to everything rendered from it — see [[marketing-art-pipeline]].

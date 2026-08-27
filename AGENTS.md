<!-- BEGIN godot-vibe-os -->
## Godot Vibe OS

Use the `godot_*` MCP tools for live editor state. Do not guess NodePaths or Godot APIs, and do not hand-edit `.tscn`/`.tres` when a dedicated editor tool exists.

- Start with `godot_orient({ task: "<current request>" })`. It validates and refreshes the generated project map in `.godot-vibe/brain/` and returns the parts relevant to your task — answer from that map (and `godot_query_project_brain` for follow-ups) before scanning the project by hand.
- Resolve ‘this’ or ‘selected’ with `godot_inspect_selected`.
- Verify unfamiliar engine APIs with `godot_reflect` before writing code.
- Read scripts first and pass their sha256 to `godot_apply_text_edits`.
- After text changes, run `godot_refresh_filesystem`, then `godot_verify`. Import/syntax checks are not unit tests; run `godot_test_run` when the project has a test runner.
- For runtime bugs, use `godot_debug_run`; it only stops play sessions it starts and a clean verdict covers only its bounded observation window.
- Scene writes use editor UndoRedo; file writes are snapshotted and action-logged under `.godot-vibe/`.

Diagnose setup with `gvibe doctor --project=.`.
<!-- END godot-vibe-os -->

---
name: godot-verify
description: >
  How to verify GDScript/scenes in this project without manual editor testing:
  Godot AI MCP (live editor: state, logs, run/stop), headless syntax/type
  check, and the runtime log file as a fallback. Use when you've edited
  .gd/.tscn/.tres files and need to verify correctness before reporting done.
---

## Preferred: Godot AI MCP (editor is open)

The `godot-ai` MCP server talks to the running editor (session `rpgmatch`). Tools are deferred:
load schemas first with `ToolSearch("select:mcp__godot-ai__editor_state,mcp__godot-ai__logs_read,...")`.

1. `session_manage(op="list")` — confirm a session is connected and `readiness` is `ready`.
2. `editor_state` — `is_playing`, open scene, and `game_status.status`
   (`stopped` / live / `break`). `break` means the game is parked in a remote-debugger break
   (usually a boot-time parse error) and will not resume by itself: call
   `project_manage(op="stop")`.
3. `logs_read(source=...)`:
   - `editor` — parse errors, GDScript reload warnings, `push_error`/`push_warning` from `.gd` files
     (also Debugger Errors-tab rows). Read this right after editing scripts; it replaces
     `--check-only` when the editor is open and the latter would hang on the lock.
   - `game` — stdout/stderr of the running game, current run only (pass `since_run_id` for older runs).
   - `plugin` — MCP traffic only; rarely useful for gameplay bugs.
   - `all` — plugin + editor + game.
4. Boot-time parse/load errors are **never** in the `game` log. If `game` is clean but the response
   carries `editor_errors_hint`, the run lost scripts — read `source="editor"`.
5. If the editor reports an unexpected `EDITOR_NOT_READY (state=playing)` after the game stopped,
   call `editor_state` once to resync, then retry.

Use `project_run` to start the game and `project_manage(op="stop")` to stop it; always stop it
before finishing so the user's editor is left in the state it was found in.

Fall back to the sections below when no session is connected.

## Headless syntax/type check

Local binary: `~/dev/godot/bin/godot.macos.editor.arm64`.

```
~/dev/godot/bin/godot.macos.editor.arm64 --headless --check-only --path .
```

Run from `rpgmatch` root. Empty output + exit code 0 = no compile/type errors — more reliable than
live IDE diagnostics (which can lie temporarily on just-created files, e.g. "not declared in scope"
for an existing method, until reindexing catches up — don't rush to fix, re-read the file or rerun
this check instead).

**Lock pitfall**: if a project editor instance is already open (common here — the user often keeps an
embedded player running), a second `--check-only` process hangs on the lock instead of running fast
or erroring. If it hangs with no CPU growth for ~10s, just kill it — the hang itself says nothing
about whether there are errors.

**New `class_name` pitfall**: a freshly added file with `class_name` (new global class) won't resolve
in `--check-only` until `.godot/global_script_class_cache.cfg` is rebuilt — you'll get
"Could not find type X in the current scope" across every dependent file even though the code is
correct. Rebuild without opening the UI:

```
~/dev/godot/bin/godot.macos.editor.arm64 --headless --path . --editor --quit-after 3
```

(doesn't hang on the lock as hard as `--check-only`, even with an editor already open). Then rerun
`--check-only`.

## Headless simulations

For gameplay logic (battles, generation, balance), run a `SceneTree` script from the scratchpad:

```
~/dev/godot/bin/godot.macos.editor.arm64 --headless --path . -s /path/to/sim.gd
```

- Script: `extends SceneTree`, logic in `_init()`, end with `quit()`.
- Build `TurnContext` by hand (`resolver`, `score_tracker`, `swap_controller`, `detonate_controller`,
  `shuffle_controller`), then `mode.build_phases(ctx, level)` or a hand-made phase list.
- The default `AnimationDriver` is instant, so a whole battle runs synchronously inside `start()`;
  cap turns (e.g. kill one side after N turns) to guarantee termination.
- macOS has no `timeout`: run in background and `pkill -f <script>` after a fixed sleep.
- Deep synchronous recursion may print "Stack underflow" at exit; it does not occur in the real game.

## Runtime errors when the editor is already open

If check-only is unavailable (locked) and you need actual play-time failures — the user often already
runs an embedded player (`ps aux | grep godot` shows a process with
`--scene res://game/game_root.tscn --embedded`). Godot writes a runtime log separate from check-only:

```
~/Library/Application Support/Godot/app_userdata/rpgmatch/logs/godot.log
```

(older timestamped runs sit alongside it). Check the most recently modified file — it has the real
push_error/traces from the last play session.

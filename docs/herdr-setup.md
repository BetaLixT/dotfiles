# Herdr setup

Verified against **herdr 0.8.2** (`herdr-bin 0.8.2-1`) on this machine, not
recalled from memory. Originally written 2026-08-27 to `/tmp`, which is tmpfs —
it was lost on the 2026-08-31 reboot, hence living in the repo now.

## Files

| Item | Path |
|---|---|
| Config | `herdr/config.toml` (repo) |
| Symlink | `~/.config/herdr/config.toml` -> repo file |
| Install wiring | block in `install-sway-arch.sh` |

Link the **file, not the directory** — `~/.config/herdr/` also holds
`herdr.sock`, `herdr-client.sock`, `session.json`, `*.log`, `.plugins.lock`.
Symlinking the directory would drag runtime state and sockets into git.

## Keybindings

Aligned with `~/.tmux.conf`. Nothing in `.tmux.conf` was modified.

| Action | Herdr default | Now | tmux equivalent |
|---|---|---|---|
| `prefix` | `ctrl+b` | **`ctrl+a`** | `set -g prefix2 C-a` |
| `split_vertical` (pane RIGHT) | `prefix+v` | **`prefix+_`** | `bind _ split-window -h` |
| `split_horizontal` (pane BELOW) | `prefix+minus` | unchanged | `bind - split-window -v` |
| `detach` | `prefix+q` | **`prefix+d`** | tmux convention |

Already matching tmux, left alone: `focus_pane_*` (`prefix+h/j/k/l`),
`navigate_pane_*` (bare `h/j/k/l`), `new_tab` (`prefix+c`), `close_pane`
(`prefix+x`), `next_tab`/`previous_tab` (`prefix+n`/`p`), `switch_tab`
(`prefix+1..9`), `zoom` (`prefix+z`), `copy_mode` (`prefix+[`).

**Naming:** Herdr names a split by divider orientation, same as the user does —
`-` horizontal = below, `_` vertical = right. tmux's `-h`/`-v` flag letters are
the inverted ones. If the tmux column above looks backwards, it is correct.

**Prefix collision:** Herdr claims the chord first, so `ctrl+a` no longer reaches
tmux from inside a Herdr pane. tmux's built-in `ctrl+b` still does.

## Gotchas (verified empirically)

**Invalid key names fail silently.** Herdr logs
`invalid keybinding: keys.X = "..."; disabling binding` and runs on with the
action unbound. Always confirm `herdr config check` prints exactly `config: ok`.

Tested for the underscore key:

```
prefix+_            -> config: ok
prefix+underscore   -> invalid keybinding; disabling binding   <-- silently lost
prefix+shift+minus  -> config: ok
```

Use the literal `_`. The "punctuation written as words" rule holds for `minus`
but **not** for `underscore`.

**Use the version-pinned reference,** not the docs site:
<https://raw.githubusercontent.com/herdrdev/herdr/v0.8.2/docs/next/website/src/data/config-reference.json>

## Persistence

| Scenario | Layout / tabs / panes / cwd | Processes |
|---|---|---|
| detach -> reattach | kept | **kept running** |
| `herdr server stop` -> start | restored from snapshot | lost |
| reboot | restored from snapshot | lost |

- Snapshot: `~/.config/herdr/session.json` — workspaces, tabs, pane tree, focus,
  per-pane `cwd`. No process state.
- **Event-driven**, rewritten on layout change, not on a timer. An old mtime
  means "nothing changed", not "stale".
- `[session] resume_agents_on_restore` defaults **true**; Claude Code supports
  native resume.
- `[experimental] pane_history = true` also restores scrollback. Not enabled.
- **No systemd user unit exists** — Herdr does not auto-start at boot. Run
  `herdr` and it restores from the snapshot.

## Driving agents

```bash
herdr tab create --workspace w1 --cwd "$PWD" --label NAME --no-focus
herdr agent start NAME --kind claude --pane <root_pane_id>
herdr agent prompt NAME "..." --wait --timeout 300000
herdr agent read NAME --source recent --lines 160     # visible viewport truncates
herdr agent get NAME
```

- `agent_status: blocked` **can be a false positive** at an idle prompt — check
  `interactive_ready`. When it is real, the CLI genuinely refuses to write.
- `agent read --source recent` is refused with `agent_not_idle` while the agent
  is working; use `--source visible`.
- Do **not** run bare `herdr` for discovery — it launches/attaches the TUI. Print
  a command group instead (`herdr pane`, `herdr agent`).
- Control commands require `HERDR_ENV=1`, i.e. running inside a Herdr pane. This
  is environment-dependent and can change between sessions.

Agent kinds in 0.8.2: `pi|claude|codex|gemini|cursor|devin|agy|cline|omp|
mastracode|opencode|copilot|kimi|kiro|droid|amp|grok|hermes|kilo|qodercli|qwen|maki`

## Open

`herdr server reload-config` has never been run and it is unverified whether the
user ran it manually, so the live server may still be on `ctrl+b`.

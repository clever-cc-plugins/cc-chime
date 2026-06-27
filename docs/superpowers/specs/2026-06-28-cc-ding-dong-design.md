# cc-ding-dong Design Spec

**Date:** 2026-06-28
**Status:** Approved

## Summary

A Claude Code plugin that plays audio notifications on every Claude turn-end, distinguishing between "task complete" (Claude finished doing work) and "input required" (Claude is asking a question). Requires no skill invocation — install means active, uninstall means silent.

---

## Architecture

Two plugin deliverables plus one cc-plugins system extension.

### Plugin files (`plugins/cc-ding-dong/`)

```
.claude-plugin/
  plugin.json          ← manifest, extended with "hooks" section
scripts/
  notify.sh            ← macOS + Linux audio script
  notify.ps1           ← Windows audio script (PowerShell)
```

No `skills/` directory.

### cc-plugins system extension

The cc-plugins installer must learn to process a `hooks` section in `plugin.json`. On install it merges the declared hooks into `~/.claude/settings.json`, replacing `{plugin_dir}` with the absolute installed path. On uninstall it removes those exact entries. Existing Stop hooks from the user's own config or other plugins are preserved (append, not replace).

---

## `plugin.json` format

```json
{
  "name": "cc-ding-dong",
  "description": "Plays audio notifications when tasks complete or user input is required",
  "author": { "name": "Michael van Laar" },
  "homepage": "https://github.com/MichaelvanLaar/cc-ding-dong",
  "repository": "https://github.com/MichaelvanLaar/cc-ding-dong",
  "license": "MIT",
  "hooks": {
    "global": {
      "Stop": [
        {
          "type": "command",
          "command": "{plugin_dir}/scripts/notify.sh"
        }
      ]
    }
  }
}
```

- `hooks.global` scope signals these hooks target `~/.claude/settings.json` (not a project-level file)
- `{plugin_dir}` is resolved by the installer to the absolute path of the installed plugin directory (e.g. `~/.claude/plugins/cc-ding-dong`)
- On Windows the installer substitutes `notify.ps1` instead of `notify.sh`

---

## Notification script

### Sound distinction heuristic

The Claude Code `Stop` hook delivers a JSON payload on stdin containing the session transcript. The script reads the last assistant message and checks whether it contains a `?` character:

- Contains `?` → **input required** sound
- No `?` → **task complete** sound

JSON parsing is handled by Python 3 (more universally available than `jq`). If Python is unavailable, falls back to a grep on the raw JSON tail. If both fail, defaults to the "task complete" sound.

### Cross-platform audio

| OS      | Task complete                                                | Input required                                                                     |
| ------- | ------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| macOS   | `afplay /System/Library/Sounds/Glass.aiff`                   | `afplay /System/Library/Sounds/Tink.aiff`                                          |
| Linux   | `paplay complete.oga` → `aplay complete.oga` → `printf '\a'` | `paplay dialog-information.oga` → `aplay dialog-information.oga` → `printf '\a\a'` |
| Windows | `[console]::Beep(880,400)`                                   | `[console]::Beep(660,300)`                                                         |

Linux paths are under `/usr/share/sounds/freedesktop/stereo/`. The cascade of fallbacks handles the variation in Linux audio systems across distros.

### Execution model

- The script runs detached (`&`) so Claude Code's next turn starts immediately
- Every audio command is followed by `2>/dev/null` — no terminal noise on failure
- Script always exits `0` — a failed notification must never block or abort Claude Code

---

## Error handling

| Failure                 | Behaviour                                     |
| ----------------------- | --------------------------------------------- |
| JSON parse error        | Default to "task complete" sound              |
| Audio command not found | Try next fallback; if all fail, exit silently |
| Script itself errors    | Exit 0, no output to stderr                   |

---

## Testing

Manual only (no automated test harness for audio output).

**Unit-level (script in isolation):**

```bash
# task-complete path
echo '{}' | bash scripts/notify.sh

# input-required path
echo '{"transcript":[{"role":"assistant","content":"What would you like to do?"}]}' \
  | bash scripts/notify.sh
```

**Windows:**

```powershell
echo '{}' | pwsh scripts/notify.ps1
```

**End-to-end:**

1. Install the plugin
2. Run a Claude Code task to completion → confirm task-complete sound
3. Ask Claude a question that prompts a clarifying question back → confirm input-required sound

---

## Out of scope

- Volume control
- Muting / pause without uninstalling
- Custom sound files
- Per-project enable/disable
- Bundled audio files (relies entirely on OS-provided sounds)

# cc-ding-dong Design Spec

**Date:** 2026-06-28
**Status:** Approved (corrected 2026-06-28 after schema verification)

## Summary

A Claude Code plugin that plays audio notifications on every Claude turn-end, distinguishing between "task complete" (Claude finished doing work) and "input required" (Claude is asking a question). Requires no skill invocation — install means active, uninstall means silent.

---

## Architecture

Two plugin deliverables. No cc-plugins system extension is needed: Claude Code natively processes the `hooks` section in `plugin.json` and injects/removes hooks automatically on install/uninstall.

### Plugin files (`plugins/cc-ding-dong/`)

```
.claude-plugin/
  plugin.json          ← manifest with "hooks" section
scripts/
  notify.sh            ← macOS + Linux audio script (also handles Windows via PowerShell delegation)
  notify.ps1           ← Windows PowerShell audio script (for native Windows without Git Bash)
```

No `skills/` directory.

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
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh\""
          }
        ]
      }
    ]
  }
}
```

- `${CLAUDE_PLUGIN_ROOT}` is a Claude Code variable resolved to the plugin's installation directory
- Claude Code automatically adds this hook to `~/.claude/settings.json` on install and removes it on uninstall

---

## Notification script

### Sound distinction heuristic

The Claude Code `Stop` hook delivers a JSON payload on stdin. The payload contains a `transcript_path` field — a file path pointing to a `.jsonl` file holding the session transcript. Each line is a JSON message object.

The script:

1. Reads `transcript_path` from the stdin JSON
2. Reads the `.jsonl` file and finds the last assistant message
3. Checks whether that message contains a `?` character:
   - Contains `?` → **input required** sound
   - No `?` → **task complete** sound

JSON parsing is handled by Python 3 (more universally available than `jq`). If Python is unavailable, defaults to "task complete" sound. All errors default to "task complete".

### Cross-platform audio

| OS      | Task complete                                                | Input required                                                                     |
| ------- | ------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| macOS   | `afplay /System/Library/Sounds/Glass.aiff`                   | `afplay /System/Library/Sounds/Tink.aiff`                                          |
| Linux   | `paplay complete.oga` → `aplay complete.oga` → `printf '\a'` | `paplay dialog-information.oga` → `aplay dialog-information.oga` → `printf '\a\a'` |
| Windows | `[console]::Beep(880,400)`                                   | `[console]::Beep(660,300)` × 2                                                     |

Linux paths are under `/usr/share/sounds/freedesktop/stereo/`. The cascade of fallbacks handles variation in Linux audio systems across distros.

On Windows via Git Bash (`$OSTYPE` is `msys*`/`cygwin*`/`mingw*`), `notify.sh` delegates to `notify.ps1` via `powershell.exe`. Native Windows without Git Bash would use `notify.ps1` directly, but this requires a separate hook entry in `plugin.json` — deferred to a future enhancement; the current design covers Git Bash on Windows.

### Execution model

- The audio command runs in the background (`&`) inside the script — the hook exits immediately, the sound plays independently
- Every audio command is followed by `2>/dev/null` — no terminal noise on failure
- Script always exits `0` — a failed notification must never block or abort Claude Code

---

## Error handling

| Failure                                     | Behaviour                                     |
| ------------------------------------------- | --------------------------------------------- |
| JSON parse error                            | Default to "task complete" sound              |
| `transcript_path` missing or file not found | Default to "task complete" sound              |
| Audio command not found                     | Try next fallback; if all fail, exit silently |
| Script itself errors                        | Exit 0, no output to stderr                   |

---

## Testing

Manual only (no automated test harness for audio output).

**Unit-level (script in isolation):**

```bash
# Create test transcript file
echo '{"role":"assistant","content":"Here is the completed task."}' > /tmp/cc-ding-dong-test.jsonl

# task-complete path
echo '{"transcript_path":"/tmp/cc-ding-dong-test.jsonl"}' \
  | bash plugins/cc-ding-dong/scripts/notify.sh

# input-required path
echo '{"role":"assistant","content":"What would you like to do?"}' > /tmp/cc-ding-dong-test.jsonl
echo '{"transcript_path":"/tmp/cc-ding-dong-test.jsonl"}' \
  | bash plugins/cc-ding-dong/scripts/notify.sh

# fallback path (no transcript file)
echo '{}' | bash plugins/cc-ding-dong/scripts/notify.sh
```

**Windows:**

```powershell
pwsh plugins/cc-ding-dong/scripts/notify.ps1 "task-complete"
pwsh plugins/cc-ding-dong/scripts/notify.ps1 "input-required"
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
- Native Windows without Git Bash (deferred — needs separate `plugin.json` hook entry for `.ps1`)

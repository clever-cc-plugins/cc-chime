# cc-ding-dong

A [Claude Code](https://claude.ai/code) plugin that plays audio notifications at the end of every Claude turn — a distinct sound for "task complete" and another for "input required."

No skills to invoke. Install means active, uninstall means silent.

---

## What it does

Every time Claude finishes a turn, `cc-ding-dong` plays a short sound:

| Situation                           | Sound                   |
| ----------------------------------- | ----------------------- |
| Claude finished work and is waiting | **Task complete** tone  |
| Claude is asking you a question     | **Input required** tone |

This lets you step away while Claude works and come back only when needed — without keeping an eye on the terminal.

---

## Installation

Open Claude Code in any project and run:

```
/plugin marketplace add MichaelvanLaar/cc-plugins
/plugin install cc-ding-dong@cc-ding-dong
```

Claude Code wires the hook into `~/.claude/settings.json` automatically. No further setup is required.

### Keeping it current

Auto-update for third-party marketplaces is off by default. To enable it:

1. Run `/plugin` in Claude Code
2. Go to the **Marketplaces** tab
3. Toggle auto-update for `MichaelvanLaar/cc-plugins`

Once enabled, Claude Code updates the plugin on startup whenever a new version is available.

### Uninstalling

```
/plugin uninstall cc-ding-dong@cc-ding-dong
```

Claude Code removes the hook automatically. To remove the marketplace as well:

```
/plugin marketplace remove cc-plugins
```

---

## How it works

The plugin registers a `Stop` hook that fires at the end of every Claude turn. When triggered:

1. Reads `transcript_path` from the hook payload (a `.jsonl` file of the session transcript)
2. Finds the last assistant message in that transcript
3. Checks whether it contains a `?` character:
   - Contains `?` → **input required** sound
   - No `?` → **task complete** sound
4. Plays the appropriate sound for the current OS and exits immediately

JSON parsing uses Python 3, which is more universally available than `jq`. If Python 3 is not found, the script defaults to the task-complete sound. All errors default to task-complete — a notification failure never blocks or aborts Claude Code.

### Sounds by platform

| OS          | Task complete                                   | Input required                                          |
| ----------- | ----------------------------------------------- | ------------------------------------------------------- |
| **macOS**   | `Glass.aiff` (via `afplay`)                     | `Tink.aiff` (via `afplay`)                              |
| **Linux**   | `complete.oga` (paplay → aplay → terminal bell) | `dialog-information.oga` (paplay → aplay → double bell) |
| **Windows** | `Beep(880 Hz, 400 ms)`                          | `Beep(660 Hz, 300 ms)` × 2                              |

Linux sounds come from `/usr/share/sounds/freedesktop/stereo/`. The cascade of fallbacks handles variation in Linux audio systems across distros. On Windows, the script runs via Git Bash and delegates to `notify.ps1` through `powershell.exe`.

---

## Requirements

- **Claude Code** (CLI or IDE extension)
- **Python 3** — for transcript parsing (optional; falls back gracefully if missing)
- **macOS** — `afplay` (built-in on all macOS versions)
- **Linux** — PulseAudio (`paplay`) or ALSA (`aplay`) recommended; falls back to terminal bell
- **Windows** — Git Bash + PowerShell (both typically available in a standard Windows dev setup)

---

## Testing

To verify the plugin is working after installation, run these commands manually:

```bash
# Create a test transcript
echo '{"role":"assistant","content":"Here is the completed task."}' > /tmp/cc-ding-dong-test.jsonl

# Task-complete path — should play the Glass / complete sound
echo '{"transcript_path":"/tmp/cc-ding-dong-test.jsonl"}' \
  | bash ~/.claude/plugins/cc-ding-dong/scripts/notify.sh

# Input-required path — should play the Tink / dialog sound
echo '{"role":"assistant","content":"What would you like to do?"}' > /tmp/cc-ding-dong-test.jsonl
echo '{"transcript_path":"/tmp/cc-ding-dong-test.jsonl"}' \
  | bash ~/.claude/plugins/cc-ding-dong/scripts/notify.sh

# Fallback path (no transcript file) — should play the task-complete sound
echo '{}' | bash ~/.claude/plugins/cc-ding-dong/scripts/notify.sh
```

**On Windows (PowerShell):**

```powershell
pwsh ~/.claude/plugins/cc-ding-dong/scripts/notify.ps1 "task-complete"
pwsh ~/.claude/plugins/cc-ding-dong/scripts/notify.ps1 "input-required"
```

**End-to-end:**

1. Install the plugin
2. Run a Claude Code task to completion → confirm task-complete sound
3. Ask Claude something that prompts a clarifying question back → confirm input-required sound

---

## Contributing

Issues and pull requests are welcome. If you'd like to improve cross-platform support, add sound options, or fix a distro-specific audio issue, please open an issue first so we can align on the approach.

---

## License

[MIT](LICENSE) — Copyright (c) 2026 Michael van Laar

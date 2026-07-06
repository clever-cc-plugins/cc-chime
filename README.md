# cc-chime

A [Claude Code](https://claude.ai/code) plugin that plays an audio notification at the end of every Claude turn, so you can step away while Claude works and come back when it's done.

No skills to invoke. Install means active, uninstall means silent.

---

## What it does

Every time Claude finishes a turn, `cc-chime` plays a short doorbell sound.

This lets you work on something else while Claude runs and return only when you hear the signal — without keeping an eye on the terminal.

---

## Installation

Open Claude Code in any project and run:

```
/plugin marketplace add MichaelvanLaar/cc-plugins
/plugin install cc-chime@cc-plugins
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
/plugin uninstall cc-chime@cc-plugins
```

Claude Code removes the hook automatically. To remove the marketplace as well:

```
/plugin marketplace remove cc-plugins
```

---

## How it works

The plugin registers a `Stop` hook that fires at the end of every Claude turn. When triggered, it plays `audio/task-completed.wav` for the current OS and exits immediately.

All errors are suppressed — a notification failure never blocks or aborts Claude Code.

### Bundled audio file

The plugin ships one WAV file (mono, 44100 Hz, 16-bit, loudness-normalized to −18 LUFS):

| Event         | File                       | Source                                                                                      |
| ------------- | -------------------------- | ------------------------------------------------------------------------------------------- |
| Turn complete | `audio/task-completed.wav` | Doorbell — "task-complete.wav" by kwahmah_02 ([CC BY 3.0](https://freesound.org/s/319041/)) |

### Playback by platform

| OS          | Playback command                          | Fallback      |
| ----------- | ----------------------------------------- | ------------- |
| **macOS**   | `afplay` (built-in)                       | —             |
| **Linux**   | `paplay` → `aplay`                        | terminal bell |
| **Windows** | `System.Media.SoundPlayer` via PowerShell | console beep  |

On Windows, the script runs via Git Bash and delegates to `notify.ps1` through `powershell.exe`.

---

## Requirements

- **Claude Code** (CLI or IDE extension)
- **macOS** — `afplay` (built-in on all macOS versions)
- **Linux** — PulseAudio (`paplay`) or ALSA (`aplay`) recommended; falls back to terminal bell
- **Windows** — Git Bash + PowerShell (both typically available in a standard Windows dev setup)

---

## Testing

To verify the plugin is working after installation, run this command manually:

```bash
bash ~/.claude/plugins/cc-chime/scripts/notify.sh < /dev/null
```

**On Windows (PowerShell):**

```powershell
$root = "$env:USERPROFILE\.claude\plugins\cc-chime"
pwsh "$root\scripts\notify.ps1" "$root\audio\task-completed.wav"
```

**End-to-end:**

1. Install the plugin
2. Run a Claude Code task to completion → confirm you hear the doorbell sound

---

## Contributing

Issues and pull requests are welcome. If you'd like to improve cross-platform support, add sound options, or fix a distro-specific audio issue, please open an issue first so we can align on the approach.

---

## Audio attribution

See [ATTRIBUTION.md](ATTRIBUTION.md) for the license and source of the bundled audio file.

The task-complete sound ("task-complete.wav" by kwahmah_02) is used under [Creative Commons Attribution 3.0](https://creativecommons.org/licenses/by/3.0/).

---

## License

[MIT](LICENSE) — Copyright (c) 2026 Michael van Laar

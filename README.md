<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/clever-cc-plugins/.github/main/assets/logo-dark.svg" />
    <img src="https://raw.githubusercontent.com/clever-cc-plugins/.github/main/assets/logo.svg" width="220" alt="clever [cc] plugins" />
  </picture>
</p>

# <img src="assets/icon.svg" width="40" height="40" align="top" alt="" />&nbsp;cc-chime

A [Claude Code](https://claude.ai/code) plugin that plays a short sound at the end of every Claude turn and whenever Claude needs your input. Start a long task, go make coffee, and come back when the doorbell rings.

It has no skills to invoke. Installing it turns it on, and uninstalling it turns it off.

---

## What It Does

Every time Claude finishes a turn, `cc-chime` plays a short doorbell sound. It plays the same sound when Claude waits for you, for example at a permission prompt or a question.

You can work on something else while Claude runs and come back when you hear the signal, without watching the terminal. The doorbell fits: someone is standing at your terminal and wants in. The plugin can't tell a big task from a one-line reply, so every turn rings.

---

## Installation

Open Claude Code in any project and run:

```
/plugin marketplace add clever-cc-plugins/marketplace
/plugin install cc-chime@clever-cc-plugins
```

The plugin declares its hooks in its own `plugin.json`, and Claude Code registers them when it loads the plugin. You don't need to edit any settings file.

### Keeping It Current

Auto-update is off by default for third-party marketplaces. To switch it on:

1. Run `/plugin` in Claude Code
2. Open the **Marketplaces** tab
3. Toggle auto-update for `clever-cc-plugins/marketplace`

Once it's on, Claude Code updates the plugin on startup whenever a new version is available.

### Uninstalling

```
/plugin uninstall cc-chime@clever-cc-plugins
```

Claude Code removes the hooks together with the plugin. To remove the marketplace as well (this uninstalls every plugin you installed from it):

```
/plugin marketplace remove clever-cc-plugins
```

---

## How It Works

The plugin registers a `Stop` hook that fires at the end of every Claude turn and a `Notification` hook that fires when Claude needs your input (permission prompts, questions asked via skills). Both play the same sound, `audio/task-completed.wav`, with the player for your OS. The player runs in the background, so the hook returns immediately.

The script suppresses all errors, so a failed notification never blocks or aborts Claude Code.

### Bundled Audio File

The plugin ships one WAV file (mono, 44100 Hz, 16-bit, loudness-normalized to −18 LUFS):

| Event                         | File                       | Source                                                                                     |
| ----------------------------- | -------------------------- | ------------------------------------------------------------------------------------------ |
| Turn complete, input required | `audio/task-completed.wav` | Doorbell, "task-complete.wav" by kwahmah_02 ([CC BY 3.0](https://freesound.org/s/319041/)) |

### Playback by Platform

| OS          | Playback command                          | Fallback      |
| ----------- | ----------------------------------------- | ------------- |
| **macOS**   | `afplay` (built-in)                       | None          |
| **Linux**   | `paplay`, then `aplay`                    | Terminal bell |
| **Windows** | `System.Media.SoundPlayer` via PowerShell | Console beep  |

On Windows, the script runs via Git Bash and hands the sound to `notify.ps1` through `powershell.exe`.

---

## Requirements

- **Claude Code** (CLI or IDE extension)
- **macOS:** `afplay` (built into every macOS version)
- **Linux:** PulseAudio (`paplay`) or ALSA (`aplay`) recommended, with the terminal bell as a fallback
- **Windows:** Git Bash and PowerShell (both come with a typical Windows dev setup)

---

## Testing

To check that the plugin works after installation, run its script by hand. This finds the installed copy and plays the sound:

```bash
bash "$(find ~/.claude/plugins -path '*cc-chime*' -name notify.sh | head -n 1)" < /dev/null
```

**On Windows (PowerShell):**

```powershell
$script = Get-ChildItem "$env:USERPROFILE\.claude\plugins" -Recurse -Filter notify.ps1 | Where-Object FullName -Like '*cc-chime*' | Select-Object -First 1
powershell.exe -NonInteractive -File $script.FullName (Join-Path $script.Directory.Parent.FullName 'audio\task-completed.wav')
```

**End to end:**

1. Install the plugin
2. Run a Claude Code task to completion and confirm that you hear the doorbell

---

## Contributing

Issues and pull requests are welcome. If you'd like to improve cross-platform support, add sound options, or fix a distro-specific audio problem, please open an issue first so we can agree on the approach.

---

## Audio Attribution

[ATTRIBUTION.md](ATTRIBUTION.md) lists the license and source of the bundled audio file. The sound ("task-complete.wav" by kwahmah_02) is used under [Creative Commons Attribution 3.0](https://creativecommons.org/licenses/by/3.0/).

---

## License

[MIT](LICENSE), Copyright (c) 2026 Michael van Laar

---

<p align="center">
  Part of the <a href="https://github.com/clever-cc-plugins">clever-cc-plugins</a> family · <a href="https://github.com/clever-cc-plugins/marketplace">marketplace</a> · <a href="https://github.com/clever-cc-plugins/cc-config">cc-config</a> · <a href="https://github.com/clever-cc-plugins/cc-concept">cc-concept</a> · <a href="https://github.com/clever-cc-plugins/cc-content">cc-content</a> · <a href="https://github.com/clever-cc-plugins/cc-career">cc-career</a> · <a href="https://github.com/clever-cc-plugins/cc-coach">cc-coach</a> · <a href="https://github.com/clever-cc-plugins/cc-handoff">cc-handoff</a> · <a href="https://github.com/clever-cc-plugins/cc-chef">cc-chef</a>
</p>

# cc-ding-dong Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Claude Code plugin that plays OS-native audio when a Claude turn ends, using two distinct sounds for "task complete" vs. "input required".

**Architecture:** A single `Stop` hook in `plugin.json` points to `scripts/notify.sh`. The script reads `transcript_path` from the hook's stdin payload, opens the `.jsonl` transcript file, checks the last assistant message for a `?`, then plays the appropriate OS-native sound in the background and exits 0. Claude Code injects/removes the hook automatically on plugin install/uninstall — no installer changes needed.

**Tech Stack:** Bash, Python 3 (JSON parsing), PowerShell (Windows audio), OS-native audio tools (`afplay` / `paplay` / `aplay` / `[console]::Beep`).

## Global Constraints

- Plugin must add zero external dependencies
- Script must always exit 0 — a notification failure must never block Claude Code
- Audio runs in background (`&`) inside the script so the hook returns immediately
- No bundled audio files — use OS-provided sounds only
- All audio commands followed by `2>/dev/null`
- Cross-platform: macOS, Linux (freedesktop sounds), Windows via Git Bash

---

## File Structure

| Action | Path                                                | Responsibility                                    |
| ------ | --------------------------------------------------- | ------------------------------------------------- |
| Modify | `plugins/cc-ding-dong/.claude-plugin/plugin.json`   | Add `hooks.Stop` section                          |
| Create | `plugins/cc-ding-dong/scripts/notify.sh`            | macOS + Linux audio; Windows delegation to `.ps1` |
| Create | `plugins/cc-ding-dong/scripts/notify.ps1`           | Windows PowerShell audio                          |
| Delete | `plugins/cc-ding-dong/skills/cc-ding-dong/SKILL.md` | Placeholder — no skill needed                     |
| Delete | `plugins/cc-ding-dong/skills/` (dir)                | Follows from SKILL.md removal                     |

---

### Task 1: Update `plugin.json` with Stop hook

**Files:**

- Modify: `plugins/cc-ding-dong/.claude-plugin/plugin.json`

**Interfaces:**

- Produces: `${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh` as the hook command (consumed by Tasks 2–3)

- [ ] **Step 1: Read the current file**

```bash
cat plugins/cc-ding-dong/.claude-plugin/plugin.json
```

- [ ] **Step 2: Write the updated manifest**

Replace the file content with:

```json
{
  "name": "cc-ding-dong",
  "description": "Plays audio notifications when tasks complete or user input is required",
  "author": {
    "name": "Michael van Laar"
  },
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

- [ ] **Step 3: Verify the JSON is valid**

```bash
python3 -c "import json; json.load(open('plugins/cc-ding-dong/.claude-plugin/plugin.json')); print('valid')"
```

Expected output: `valid`

- [ ] **Step 4: Commit**

```bash
git add plugins/cc-ding-dong/.claude-plugin/plugin.json
git commit -m "✨ feat(plugin): add Stop hook to plugin manifest"
```

---

### Task 2: Write `notify.sh`

**Files:**

- Create: `plugins/cc-ding-dong/scripts/notify.sh`

**Interfaces:**

- Consumes: stdin JSON with `{"transcript_path": "/path/to/session.jsonl", ...}`
- Transcript `.jsonl`: each line is `{"role":"assistant"|"user", "content":"..." | [...blocks]}`
- Produces: audio output via OS-native tool; exits 0

- [ ] **Step 1: Create the scripts directory**

```bash
mkdir -p plugins/cc-ding-dong/scripts
```

- [ ] **Step 2: Write notify.sh**

```bash
cat > plugins/cc-ding-dong/scripts/notify.sh << 'SCRIPTEOF'
#!/usr/bin/env bash

# Determine sound type by parsing transcript_path from the Stop hook payload
SOUND_TYPE="task-complete"

if command -v python3 >/dev/null 2>&1; then
  SOUND_TYPE=$(python3 - <<'PYEOF' 2>/dev/null
import sys, json, os

try:
    data = json.load(sys.stdin)
    transcript_path = data.get('transcript_path', '')
    last_text = ''

    if transcript_path and os.path.exists(transcript_path):
        with open(transcript_path, 'r', encoding='utf-8') as f:
            lines = [l.strip() for l in f if l.strip()]
        for line in reversed(lines):
            try:
                msg = json.loads(line)
                if msg.get('role') == 'assistant':
                    content = msg.get('content', '')
                    if isinstance(content, str):
                        last_text = content
                    elif isinstance(content, list):
                        for block in content:
                            if isinstance(block, dict) and block.get('type') == 'text':
                                last_text += block.get('text', '')
                    break
            except (json.JSONDecodeError, KeyError, TypeError):
                continue

    print('input-required' if '?' in last_text else 'task-complete')
except Exception:
    print('task-complete')
PYEOF
  ) || SOUND_TYPE="task-complete"
fi

# Play sound — audio command runs in background so hook exits immediately
case "$OSTYPE" in
  darwin*)
    if [ "$SOUND_TYPE" = "input-required" ]; then
      afplay /System/Library/Sounds/Tink.aiff 2>/dev/null &
    else
      afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
    fi
    ;;
  linux*)
    if [ "$SOUND_TYPE" = "input-required" ]; then
      SOUND_FILE="/usr/share/sounds/freedesktop/stereo/dialog-information.oga"
      ( paplay "$SOUND_FILE" 2>/dev/null ||
        aplay  "$SOUND_FILE" 2>/dev/null ||
        printf '\a\a' ) &
    else
      SOUND_FILE="/usr/share/sounds/freedesktop/stereo/complete.oga"
      ( paplay "$SOUND_FILE" 2>/dev/null ||
        aplay  "$SOUND_FILE" 2>/dev/null ||
        printf '\a' ) &
    fi
    ;;
  msys*|cygwin*|mingw*)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    powershell.exe -NonInteractive -File "$SCRIPT_DIR/notify.ps1" "$SOUND_TYPE" 2>/dev/null &
    ;;
esac

exit 0
SCRIPTEOF
```

- [ ] **Step 3: Make executable**

```bash
chmod +x plugins/cc-ding-dong/scripts/notify.sh
```

- [ ] **Step 4: Test — task-complete path**

```bash
echo '{"role":"assistant","content":"Here is the completed result."}' \
  > /tmp/cc-ding-dong-test.jsonl
echo '{"transcript_path":"/tmp/cc-ding-dong-test.jsonl"}' \
  | bash plugins/cc-ding-dong/scripts/notify.sh
echo "Exit code: $?"
```

Expected: exit code 0; task-complete sound plays (Glass.aiff on macOS, or terminal bell on Linux without freedesktop sounds).

- [ ] **Step 5: Test — input-required path**

```bash
echo '{"role":"assistant","content":"What would you like to do?"}' \
  > /tmp/cc-ding-dong-test.jsonl
echo '{"transcript_path":"/tmp/cc-ding-dong-test.jsonl"}' \
  | bash plugins/cc-ding-dong/scripts/notify.sh
echo "Exit code: $?"
```

Expected: exit code 0; input-required sound plays (Tink.aiff on macOS).

- [ ] **Step 6: Test — fallback path (no transcript)**

```bash
echo '{}' | bash plugins/cc-ding-dong/scripts/notify.sh
echo "Exit code: $?"
```

Expected: exit code 0; task-complete sound plays (falls back to default).

- [ ] **Step 7: Test — assistant message with content blocks (array format)**

```bash
printf '{"role":"assistant","content":[{"type":"text","text":"Should I proceed?"},{"type":"tool_use","id":"x","name":"Bash","input":{}}]}\n' \
  > /tmp/cc-ding-dong-test.jsonl
echo '{"transcript_path":"/tmp/cc-ding-dong-test.jsonl"}' \
  | bash plugins/cc-ding-dong/scripts/notify.sh
echo "Exit code: $?"
```

Expected: exit code 0; input-required sound plays (the text block contains `?`).

- [ ] **Step 8: Commit**

```bash
git add plugins/cc-ding-dong/scripts/notify.sh
git commit -m "✨ feat(scripts): add cross-platform notify.sh audio script"
```

---

### Task 3: Write `notify.ps1`

**Files:**

- Create: `plugins/cc-ding-dong/scripts/notify.ps1`

**Interfaces:**

- Consumes: optional `$SoundType` param (`"task-complete"` or `"input-required"`), passed by `notify.sh` on Windows
- Produces: audio via `[console]::Beep`; exits 0

- [ ] **Step 1: Write notify.ps1**

```powershell
cat > plugins/cc-ding-dong/scripts/notify.ps1 << 'PSEOF'
param(
    [string]$SoundType = "task-complete"
)

try {
    if ($SoundType -eq "input-required") {
        [console]::Beep(660, 300)
        Start-Sleep -Milliseconds 120
        [console]::Beep(660, 300)
    } else {
        [console]::Beep(880, 400)
    }
} catch {
    # Suppress all errors — notification failure must not surface
}

exit 0
PSEOF
```

- [ ] **Step 2: Verify syntax (if PowerShell is available)**

```bash
if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -NonInteractive -Command "
    \$null = Get-Command -Name 'notify.ps1' -ErrorAction SilentlyContinue
    try { \$ast = [System.Management.Automation.Language.Parser]::ParseFile(
      'plugins/cc-ding-dong/scripts/notify.ps1', [ref]\$null, [ref]\$null)
      Write-Host 'Syntax OK'
    } catch { Write-Host \"Syntax error: \$_\" }
  "
else
  echo "pwsh not available — skipping syntax check (Windows-only script)"
fi
```

Expected: `Syntax OK` if pwsh is present, or the skip message.

- [ ] **Step 3: Test (if PowerShell is available)**

```bash
if command -v pwsh >/dev/null 2>&1; then
  pwsh -NonInteractive -File plugins/cc-ding-dong/scripts/notify.ps1 "task-complete"
  echo "Exit code: $?"
  pwsh -NonInteractive -File plugins/cc-ding-dong/scripts/notify.ps1 "input-required"
  echo "Exit code: $?"
else
  echo "pwsh not available — Windows test deferred"
fi
```

Expected: exit code 0 for both (beep sounds on Windows; silent on Linux/macOS since `[console]::Beep` is a no-op there).

- [ ] **Step 4: Commit**

```bash
git add plugins/cc-ding-dong/scripts/notify.ps1
git commit -m "✨ feat(scripts): add Windows PowerShell notify.ps1 audio script"
```

---

### Task 4: Remove placeholder skills directory

**Files:**

- Delete: `plugins/cc-ding-dong/skills/cc-ding-dong/SKILL.md`
- Delete: `plugins/cc-ding-dong/skills/` (empty after SKILL.md removed)

The `sync-config-table.sh` pre-commit hook will auto-update `CLAUDE.md`'s Key Config Files table when the file is removed.

- [ ] **Step 1: Remove the directory**

```bash
rm -rf plugins/cc-ding-dong/skills
```

- [ ] **Step 2: Verify removal**

```bash
ls plugins/cc-ding-dong/
```

Expected: only `.claude-plugin/` and `scripts/` are present.

- [ ] **Step 3: Stage and commit**

```bash
git add -A plugins/cc-ding-dong/skills
git commit -m "🔥 chore(plugin): remove placeholder skills directory"
```

Note: if the pre-commit hook auto-updates `CLAUDE.md`, it will be included in the commit automatically.

---

### Task 5: Manual end-to-end verification

No automated test harness exists for audio output. Perform these checks after Tasks 1–4 are committed.

- [ ] **Step 1: Confirm plugin files are in place**

```bash
ls plugins/cc-ding-dong/.claude-plugin/
ls plugins/cc-ding-dong/scripts/
```

Expected:

```
.claude-plugin/:  plugin.json
scripts/:         notify.sh  notify.ps1
```

- [ ] **Step 2: Confirm scripts are executable**

```bash
test -x plugins/cc-ding-dong/scripts/notify.sh && echo "notify.sh: executable" || echo "notify.sh: NOT executable"
```

Expected: `notify.sh: executable`

- [ ] **Step 3: Validate plugin.json**

```bash
python3 -c "
import json
with open('plugins/cc-ding-dong/.claude-plugin/plugin.json') as f:
    p = json.load(f)
hooks = p.get('hooks', {}).get('Stop', [])
assert len(hooks) == 1, 'Expected one Stop hook group'
cmds = hooks[0].get('hooks', [])
assert len(cmds) == 1, 'Expected one hook command'
cmd = cmds[0].get('command', '')
assert 'CLAUDE_PLUGIN_ROOT' in cmd, 'Missing CLAUDE_PLUGIN_ROOT'
assert 'notify.sh' in cmd, 'Missing notify.sh reference'
print('plugin.json: valid')
"
```

Expected: `plugin.json: valid`

- [ ] **Step 4: Smoke-test the full notification flow**

```bash
# Build a realistic multi-line transcript
cat > /tmp/cc-ding-dong-e2e.jsonl << 'EOF'
{"role":"user","content":"Write a hello world script."}
{"role":"assistant","content":"Done. I've created hello.sh with the content you need."}
EOF

echo '{"transcript_path":"/tmp/cc-ding-dong-e2e.jsonl"}' \
  | bash plugins/cc-ding-dong/scripts/notify.sh
echo "task-complete test exit: $?"

cat > /tmp/cc-ding-dong-e2e.jsonl << 'EOF'
{"role":"user","content":"Write a script."}
{"role":"assistant","content":"Which language would you prefer — Python or Bash?"}
EOF

echo '{"transcript_path":"/tmp/cc-ding-dong-e2e.jsonl"}' \
  | bash plugins/cc-ding-dong/scripts/notify.sh
echo "input-required test exit: $?"
```

Expected: both exit 0; two different sounds play (or two terminal bells with different counts if no sound system is available).

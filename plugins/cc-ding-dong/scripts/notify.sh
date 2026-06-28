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

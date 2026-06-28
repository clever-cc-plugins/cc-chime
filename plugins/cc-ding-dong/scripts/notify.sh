#!/usr/bin/env bash

# Capture the Stop hook payload from stdin before any subshell runs
PAYLOAD=$(cat)
SOUND_TYPE="task-complete"

if command -v python3 >/dev/null 2>&1; then
  # Pass payload via env var so the heredoc can still supply the Python source
  SOUND_TYPE=$(_NOTIFY_PAYLOAD="$PAYLOAD" python3 - <<'PYEOF' 2>/dev/null
import sys, json, os

try:
    data = json.loads(os.environ.get('_NOTIFY_PAYLOAD', '{}'))
    transcript_path = data.get('transcript_path', '')
    last_text = ''

    if transcript_path and os.path.exists(transcript_path):
        with open(transcript_path, 'r', encoding='utf-8') as f:
            lines = [l.strip() for l in f if l.strip()]
        for line in reversed(lines):
            try:
                msg = json.loads(line)
                # Real format: {type:'assistant', message:{role:'assistant', content:[...]}}
                # Flat format: {role:'assistant', content:'...'} (used in test transcripts)
                if msg.get('type') == 'assistant':
                    inner = msg.get('message', {})
                elif msg.get('role') == 'assistant':
                    inner = msg
                else:
                    continue
                content = inner.get('content', '')
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

# Resolve bundled audio directory relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIO_DIR="$(dirname "$SCRIPT_DIR")/audio"

if [ "$SOUND_TYPE" = "input-required" ]; then
  SOUND_FILE="$AUDIO_DIR/input-required.wav"
else
  SOUND_FILE="$AUDIO_DIR/task-completed.wav"
fi

# Play sound — audio command runs in background so hook exits immediately
case "$OSTYPE" in
  darwin*)
    afplay "$SOUND_FILE" 2>/dev/null &
    ;;
  linux*)
    ( paplay "$SOUND_FILE" 2>/dev/null ||
      aplay  "$SOUND_FILE" 2>/dev/null ||
      printf '\a' ) &
    ;;
  msys*|cygwin*|mingw*)
    powershell.exe -NonInteractive -File "$SCRIPT_DIR/notify.ps1" "$SOUND_TYPE" "$SOUND_FILE" 2>/dev/null &
    ;;
esac

exit 0

#!/usr/bin/env bash

# Resolve bundled audio directory relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIO_DIR="$(dirname "$SCRIPT_DIR")/audio"
SOUND_FILE="$AUDIO_DIR/task-completed.wav"

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
    powershell.exe -NonInteractive -File "$SCRIPT_DIR/notify.ps1" "$SOUND_FILE" 2>/dev/null &
    ;;
esac

exit 0

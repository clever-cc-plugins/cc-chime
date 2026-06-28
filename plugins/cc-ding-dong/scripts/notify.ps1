param(
    [string]$SoundType = "task-complete",
    [string]$SoundFile = ""
)

try {
    if ($SoundFile -and (Test-Path $SoundFile)) {
        $player = New-Object System.Media.SoundPlayer $SoundFile
        $player.PlaySync()
    } else {
        # Fallback to console beeps when bundled file is not accessible
        if ($SoundType -eq "input-required") {
            [console]::Beep(660, 300)
            Start-Sleep -Milliseconds 120
            [console]::Beep(660, 300)
        } else {
            [console]::Beep(880, 400)
        }
    }
} catch {
    # Suppress all errors — notification failure must not surface
}

exit 0

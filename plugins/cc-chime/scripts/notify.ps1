param(
    [string]$SoundFile = ""
)

try {
    if ($SoundFile -and (Test-Path $SoundFile)) {
        $player = New-Object System.Media.SoundPlayer $SoundFile
        $player.PlaySync()
    } else {
        [console]::Beep(880, 400)
    }
} catch {
    # Suppress all errors — notification failure must not surface
}

exit 0

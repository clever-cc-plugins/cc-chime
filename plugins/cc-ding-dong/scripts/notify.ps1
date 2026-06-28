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

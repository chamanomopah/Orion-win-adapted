# VoiceServer Windows Shutdown Script
# PAI v2.5 - Cross-Platform Voice Notification Server

$ErrorActionPreference = "Stop"

$VoiceDir = "$env:USERPROFILE\.claude\VoiceServer"
$PidFile = "$VoiceDir\voice.pid"

if (-not (Test-Path $PidFile)) {
    Write-Host "VoiceServer is not running (no PID file found)" -ForegroundColor Yellow
    exit 0
}

try {
    $pid = Get-Content $PidFile -ErrorAction Stop
    $process = Get-Process -Id $pid -ErrorAction SilentlyContinue

    if ($process) {
        Write-Host "Stopping VoiceServer (PID: $pid)..." -ForegroundColor Yellow

        # Try graceful shutdown first
        $process.CloseMainWindow() | Out-Null
        Start-Sleep -Seconds 1

        if (-not $process.HasExited) {
            # Force kill if graceful shutdown failed
            $process.Kill()
            Start-Sleep -Milliseconds 500
        }

        if ($process.HasExited) {
            Remove-Item $PidFile -Force
            Write-Host "VoiceServer stopped successfully" -ForegroundColor Green
        } else {
            Write-Host "Warning: VoiceServer may still be running" -ForegroundColor Yellow
        }
    } else {
        Write-Host "VoiceServer process not found (stale PID file)" -ForegroundColor Yellow
        Remove-Item $PidFile -Force
    }
} catch {
    Write-Host "Error stopping VoiceServer: $_" -ForegroundColor Red
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    exit 1
}

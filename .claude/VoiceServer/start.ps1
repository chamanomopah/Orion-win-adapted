# VoiceServer Windows Startup Script
# PAI v2.5 - Cross-Platform Voice Notification Server

$ErrorActionPreference = "Stop"

$VoiceDir = "$env:USERPROFILE\.claude\VoiceServer"
$PidFile = "$VoiceDir\voice.pid"
$LogFile = "$VoiceDir\voice.log"
$Port = 8888

Write-Host "Starting VoiceServer..." -ForegroundColor Green

# Check if already running
if (Test-Path $PidFile) {
    try {
        $oldPid = Get-Content $PidFile -ErrorAction Stop
        $process = Get-Process -Id $oldPid -ErrorAction SilentlyContinue

        if ($process) {
            Write-Host "VoiceServer is already running (PID: $oldPid)" -ForegroundColor Yellow
            exit 1
        } else {
            Remove-Item $PidFile -Force
        }
    } catch {
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }
}

# Check if Python is installed
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
}

if (-not $pythonCmd) {
    Write-Host "Error: Python not found. Please install Python 3.8+" -ForegroundColor Red
    exit 1
}

Write-Host "Using Python: $($pythonCmd.Source)" -ForegroundColor Cyan

# Check if uvicorn is installed
$uvicornCmd = Get-Command uvicorn -ErrorAction SilentlyContinue
if (-not $uvicornCmd) {
    Write-Host "Installing uvicorn..." -ForegroundColor Yellow
    & $pythonCmd.Source -m pip install uvicorn fastapi
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to install uvicorn" -ForegroundColor Red
        exit 1
    }
}

# Check if server.py exists
if (-not (Test-Path "$VoiceDir\server.py")) {
    Write-Host "Error: server.py not found in $VoiceDir" -ForegroundColor Red
    exit 1
}

# Start the server using uvicorn
Write-Host "Starting uvicorn server on port $Port..." -ForegroundColor Cyan

$env:PYTHONUNBUFFERED = "1"

# Start process in background
$processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
$processStartInfo.FileName = $pythonCmd.Source
$processStartInfo.Arguments = "-m uvicorn server:app --host 127.0.0.1 --port $Port --log-level info"
$processStartInfo.WorkingDirectory = $VoiceDir
$processStartInfo.UseShellExecute = $false
$processStartInfo.RedirectStandardOutput = $true
$processStartInfo.RedirectStandardError = $true
$processStartInfo.CreateNoWindow = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $processStartInfo
$process.Start() | Out-Null

# Save PID
$process.Id | Out-File -FilePath $PidFile -Encoding utf8

# Wait a moment for startup
Start-Sleep -Seconds 2

# Check if still running
if ($process.HasExited) {
    Write-Host "Error: VoiceServer failed to start" -ForegroundColor Red
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue

    # Try to read error output
    $errorOutput = $process.StandardError.ReadToEnd()
    if ($errorOutput) {
        Write-Host "Error output: $errorOutput" -ForegroundColor Red
    }

    exit 1
}

Write-Host "VoiceServer started successfully (PID: $($process.Id))" -ForegroundColor Green
Write-Host "Logs: $LogFile" -ForegroundColor Cyan
Write-Host "Health check: http://127.0.0.1:$Port/health" -ForegroundColor Cyan

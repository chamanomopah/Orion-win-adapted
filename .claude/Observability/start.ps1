# Observability Dashboard - Windows Startup Script
# PAI v2.5 - Cross-Platform System Monitoring

$ErrorActionPreference = "Stop"

$ObsDir = "$env:USERPROFILE\.claude\Observability"
$PidFile = "$ObsDir\dashboard.pid"
$Port = 8889

Write-Host "Starting PAI Observability Dashboard..." -ForegroundColor Green

# Create Observability directory if it doesn't exist
if (-not (Test-Path $ObsDir)) {
    New-Item -ItemType Directory -Path $ObsDir -Force | Out-Null
}

# Check if already running
if (Test-Path $PidFile) {
    try {
        $oldPid = Get-Content $PidFile -ErrorAction Stop
        $process = Get-Process -Id $oldPid -ErrorAction SilentlyContinue

        if ($process) {
            Write-Host "Dashboard is already running (PID: $oldPid)" -ForegroundColor Yellow
            Write-Host "Access at: http://localhost:$Port" -ForegroundColor Cyan
            exit 1
        } else {
            Remove-Item $PidFile -Force
        }
    } catch {
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }
}

# Try to find dashboard implementation
$dashboardScript = $null
$command = $null

# Check for Python dashboard
$pyDashboard = "$ObsDir\dashboard.py"
if (Test-Path $pyDashboard) {
    $dashboardScript = $pyDashboard
    $command = Get-Command python -ErrorAction SilentlyContinue
    if (-not $command) {
        $command = Get-Command python3 -ErrorAction SilentlyContinue
    }
}

# Check for Node.js dashboard
if (-not $dashboardScript) {
    $jsDashboard = "$ObsDir\dashboard.js"
    if (Test-Path $jsDashboard) {
        $dashboardScript = $jsDashboard
        $command = Get-Command node -ErrorAction SilentlyContinue
    }
}

if (-not $dashboardScript -or -not $command) {
    Write-Host "Warning: No dashboard implementation found" -ForegroundColor Yellow
    Write-Host "Create one of the following:" -ForegroundColor Cyan
    Write-Host "  - $ObsDir\dashboard.py (Python)" -ForegroundColor White
    Write-Host "  - $ObsDir\dashboard.js (Node.js)" -ForegroundColor White
    Write-Host ""
    Write-Host "For now, starting a simple HTTP server for manual monitoring..." -ForegroundColor Yellow

    # Start simple Python HTTP server
    $command = Get-Command python -ErrorAction SilentlyContinue
    if (-not $command) {
        $command = Get-Command python3 -ErrorAction SilentlyContinue
    }

    if ($command) {
        $env:PORT = $Port
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = $command.Source
        $processStartInfo.Arguments = "-m http.server $Port"
        $processStartInfo.WorkingDirectory = $ObsDir
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        $process.Start() | Out-Null

        $process.Id | Out-File -FilePath $PidFile -Encoding utf8

        Start-Sleep -Seconds 1

        if ($process.HasExited) {
            Write-Host "Error: Failed to start HTTP server" -ForegroundColor Red
            Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
            exit 1
        }

        Write-Host "Simple HTTP server started (PID: $($process.Id))" -ForegroundColor Green
        Write-Host "Access at: http://localhost:$Port" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Note: This is a basic file server. Create a proper dashboard for full monitoring." -ForegroundColor Yellow
    } else {
        Write-Host "Error: Python not found" -ForegroundColor Red
        exit 1
    }

    # Open browser
    Start-Sleep -Seconds 1
    Start-Process "http://localhost:$Port"
    exit 0
}

# Start the actual dashboard
Write-Host "Using dashboard: $dashboardScript" -ForegroundColor Cyan
Write-Host "Using interpreter: $($command.Source)" -ForegroundColor Cyan

$env:PORT = $Port
$processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
$processStartInfo.FileName = $command.Source
$processStartInfo.Arguments = "`"$dashboardScript`""
$processStartInfo.WorkingDirectory = $ObsDir
$processStartInfo.UseShellExecute = $false
$processStartInfo.RedirectStandardOutput = $true
$processStartInfo.RedirectStandardError = $true
$processStartInfo.CreateNoWindow = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $processStartInfo
$process.Start() | Out-Null

$process.Id | Out-File -FilePath $PidFile -Encoding utf8

Start-Sleep -Seconds 2

if ($process.HasExited) {
    Write-Host "Error: Dashboard failed to start" -ForegroundColor Red
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "Dashboard started (PID: $($process.Id))" -ForegroundColor Green
Write-Host "Access at: http://localhost:$Port" -ForegroundColor Cyan

# Wait a moment then open browser
Start-Sleep -Seconds 1
Start-Process "http://localhost:$Port"

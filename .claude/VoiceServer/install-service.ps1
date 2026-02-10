# Install VoiceServer as Windows Service using NSSM
# PAI v2.5 - Windows Service Installation

$ErrorActionPreference = "Stop"

$ServiceName = "PAIVoiceServer"
$VoiceDir = "$env:USERPROFILE\.claude\VoiceServer"
$StartupScript = "$VoiceDir\start.ps1"
$StopScript = "$VoiceDir\stop.ps1"

Write-Host "PAI VoiceServer - Windows Service Installation" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Error: This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "Please right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Check if VoiceServer scripts exist
if (-not (Test-Path $StartupScript)) {
    Write-Host "Error: Start script not found: $StartupScript" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $StopScript)) {
    Write-Host "Error: Stop script not found: $StopScript" -ForegroundColor Red
    exit 1
}

# Check if NSSM is available
$nssm = Get-Command nssm -ErrorAction SilentlyContinue

if (-not $nssm) {
    Write-Host "NSSM not found. Installing..." -ForegroundColor Yellow

    # Try to install NSSM via winget
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Host "Installing NSSM via winget..." -ForegroundColor Cyan
        winget install nssm --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        $nssm = Get-Command nssm -ErrorAction SilentlyContinue
    }
}

if (-not $nssm) {
    Write-Host "Error: NSSM not found. Please install manually:" -ForegroundColor Red
    Write-Host "  1. Download from: https://nssm.cc/download" -ForegroundColor Yellow
    Write-Host "  2. Extract and add to PATH" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or use winget: winget install nssm" -ForegroundColor Cyan
    exit 1
}

Write-Host "Using NSSM: $($nssm.Source)" -ForegroundColor Green
Write-Host ""

# Check if service already exists
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "Service already exists: $ServiceName" -ForegroundColor Yellow
    $response = Read-Host "Remove and reinstall? (y/N)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Host "Removing existing service..." -ForegroundColor Cyan
        & nssm remove $ServiceName confirm
        Start-Sleep -Seconds 1
    } else {
        Write-Host "Installation cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# Install service
Write-Host "Installing service..." -ForegroundColor Cyan

& nssm install $ServiceName powershell.exe -ExecutionPolicy Bypass -File $StartupScript
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to install service" -ForegroundColor Red
    exit 1
}

# Configure service
Write-Host "Configuring service..." -ForegroundColor Cyan

& nssm set $ServiceName AppDirectory $VoiceDir
& nssm set $ServiceName DisplayName "PAI Voice Notification Server"
& nssm set $ServiceName Description "Voice notification server for PAI v2.5 - Local TTS with emotional inference"
& nssm set $ServiceName Start SERVICE_AUTO_START

# Configure service recovery
& nssm set $ServiceName AppRestartDelay 5000
& nssm set $ServiceName AppThrottle 1500
& nssm set $ServiceName AppExit Default Restart
& nssm set $ServiceName AppRestartDelay 5000

# Set stdout/stderr logging
$logDir = "$VoiceDir\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

& nssm set $ServiceName StdoutLog "$logDir\service-out.log"
& nssm set $ServiceName StderrLog "$logDir\service-err.log"

Write-Host ""
Write-Host "Service installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Service Management Commands:" -ForegroundColor Cyan
Write-Host "  Start service:   Start-Service $ServiceName" -ForegroundColor White
Write-Host "  Stop service:    Stop-Service $ServiceName" -ForegroundColor White
Write-Host "  Check status:    Get-Service $ServiceName" -ForegroundColor White
Write-Host "  View logs:       Get-Content $logDir\service-out.log" -ForegroundColor White
Write-Host "  Remove service:  nssm remove $ServiceName confirm" -ForegroundColor White
Write-Host ""
Write-Host "Starting service now..." -ForegroundColor Cyan

try {
    Start-Service $ServiceName
    Start-Sleep -Seconds 2

    $service = Get-Service $ServiceName
    if ($service.Status -eq 'Running') {
        Write-Host "Service started successfully!" -ForegroundColor Green
    } else {
        Write-Host "Warning: Service status is $($service.Status)" -ForegroundColor Yellow
        Write-Host "Check logs for errors" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error: Failed to start service" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "You can start the service manually:" -ForegroundColor Cyan
    Write-Host "  Start-Service $ServiceName" -ForegroundColor White
}

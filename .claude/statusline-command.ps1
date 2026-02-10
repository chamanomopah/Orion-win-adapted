# PAI v2.5 Status Line - PowerShell Version
# Equivalent to statusline-command.sh for Windows
#
# Usage: This script reads JSON from stdin and displays system status
# It's designed to be called by Claude Code hooks

param(
    [string]$Mode = "normal",
    [switch]$Debug
)

$ErrorActionPreference = "SilentlyContinue"

# ============================================================================
# CONFIGURATION
# ============================================================================

$PAI_DIR = if ($env:USERPROFILE) { "$env:USERPROFILE\.claude" } else { "$env:HOME\.claude" }
$SETTINGS_FILE = "$PAI_DIR\settings.json"

# ============================================================================
# COLOR FUNCTIONS
# ============================================================================

function Get-Color {
    param([string]$Name)

    $colors = @{
        reset = "`e[0m"
        bold = "`e[1m"
        cyan = "`e[38;2;6;182;212m"
        green = "`e[38;2;34;197;94m"
        yellow = "`e[38;2;234;179;8m"
        red = "`e[38;2;239;68;68m"
        blue = "`e[38;2;59;130;246m"
        gray = "`e[38;2;100;116;139m"
    }

    return $colors[$Name]
}

# ============================================================================
# GIT STATUS
# ============================================================================

function Get-GitStatus {
    $gitDir = git rev-parse --git-dir 2>$null
    if (-not $gitDir) {
        return ""
    }

    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if (-not $branch) {
        return ""
    }

    $status = git status --porcelain 2>$null
    $hasChanges = $status -and $status.Length -gt 0

    $symbol = if ($hasChanges) { "*" } else { "" }
    return "$branch$symbol"
}

# ============================================================================
# CURRENT DIRECTORY
# ============================================================================

function Get-CurrentDirectory {
    $path = (Get-Location).Path
    $home = $env:USERPROFILE

    if ($path.StartsWith($home)) {
        $path = $path.Replace($home, "~")
    }

    # Limit length
    if ($path.Length -gt 40) {
        $parts = $path.Split('\')
        $path = "$($parts[0])\...\$($parts[-1])"
    }

    return $path
}

# ============================================================================
# PAI INFO
# ============================================================================

function Get-PaiInfo {
    if (Test-Path $SETTINGS_FILE) {
        try {
            $settings = Get-Content $SETTINGS_FILE | ConvertFrom-Json
            return $settings.daidentity.name
        } catch {
            return "PAI"
        }
    }

    return "PAI"
}

# ============================================================================
# DATE/TIME
# ============================================================================

function Get-DateTime {
    return Get-Date -Format "HH:mm:ss"
}

# ============================================================================
# WINDOW SIZE
# ============================================================================

function Get-WindowSize {
    try {
        $ui = $Host.UI.RawUI
        return $ui.WindowSize.Width
    } catch {
        return 80
    }
}

# ============================================================================
# STATUS LINE DISPLAY
# ============================================================================

function Show-StatusLine {
    $width = Get-WindowSize
    $leftPad = 1
    $rightPad = 1

    # Get data
    $paiInfo = Get-PaiInfo
    $gitStatus = Get-GitStatus
    $currentDir = Get-CurrentDirectory
    $dateTime = Get-DateTime

    # Build left side
    $leftParts = @($paiInfo, $gitStatus, $currentDir)
    $leftText = $leftParts -join " | "

    # Build right side
    $rightText = $dateTime

    # Combine with padding
    $totalText = "$leftText | $rightText"

    # Apply colors
    $c = @{
        cyan = Get-Color "cyan"
        reset = Get-Color "reset"
    }

    $coloredLine = "$($c.cyan)$totalText$($c.reset)"

    # Write status line
    Write-Host "`r$coloredLine" -NoNewline
}

# ============================================================================
# MAIN LOOP
# ============================================================================

try {
    # Read JSON input from stdin (if available)
    $inputJson = ""
    if ($input.MoveNext) {
        $inputLines = @($input)
        if ($inputLines.Count -gt 0) {
            $inputJson = $inputLines -join ""
        }
    }

    # Parse JSON if available
    if ($inputJson) {
        try {
            $data = $inputJson | ConvertFrom-Json

            # Extract relevant info
            if ($data.workspace.current_dir) {
                Set-Location $data.workspace.current_dir
            }

            # Show status
            Show-StatusLine
        } catch {
            # Fallback to simple display
            Show-StatusLine
        }
    } else {
        # No JSON input, just show current status once
        Show-StatusLine
        Write-Host ""
    }

} catch {
    Write-Host "Status line error: $_" -ForegroundColor Red
}

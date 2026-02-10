# Chore: Windows Compatibility - Core PAI Systems

## Chore Description

Adapt the core PAI v2.5 infrastructure systems from Mac/Linux to Windows. This includes the installation wizard, PAI skill components, VoiceServer with audio playback, Observability dashboard, status line scripts, and configuration files.

**Scope**: Core infrastructure that enables PAI to function, including installation, configuration, voice notifications, system monitoring, and user interaction.

## Relevant Files

### Installation & Configuration
- `.claude/INSTALL.ts` ⚠️ **CRITICAL** - Installation wizard with Unix commands
- `.claude/INSTALL.md` - Installation documentation
- `.claude/settings.json` - Configuration template

### PAI Core Skill
- `.claude/skills/PAI/SKILL.md` - Core system documentation
- `.claude/skills/PAI/Components/` - System components
- `.claude/skills/PAI/Tools/` - PAI tools and utilities

### VoiceServer
- `.claude/VoiceServer/server.py` - Python voice notification server
- `.claude/VoiceServer/start.sh` - Unix startup script
- `.claude/VoiceServer/stop.sh` - Unix shutdown script
- `.claude/VoiceServer/README.md` - Voice server documentation

### Observability
- `.claude/Observability/start.sh` - Dashboard startup script
- `.claude/Observability/README.md` - Monitoring documentation

### Status Line Scripts
- `.claude/statusline-command.sh` ⚠️ **CRITICAL** - Bash script for status display
- `.claude/statusline-debug.sh` - Debug script

### Infrastructure
- `.claude/agents/` - Agent definitions
- `.claude/lib/` - Shared utilities
- `.claude/MEMORY/` - Learning capture system

## Step by Step Tasks

### 1. Completely Rewrite INSTALL.ts
**File**: `.claude/INSTALL.ts` ⚠️ **HIGHEST PRIORITY**

**Current Issues:**
```typescript
// Line 118: Unix permission command
spawnSync('chmod', ['-R', '755', targetDir]);

// Line 122: Unix ownership command
spawnSync('chown', ['-R', `${uid}:${gid}`, targetDir]);

// Line 132: Unix find with chmod
spawnSync('find', [targetDir, '-name', pattern, '-exec', 'chmod', '755', '{}', ';']);

// Line 241: Unix curl with bash
spawnSync('curl', ['-fsSL', 'https://bun.sh/install', '|', 'bash']);

// Line 263/281: Unix shell sourcing
spawnSync('source', ['~/.zshrc']);
```

**New Cross-Platform Implementation:**

```typescript
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { spawnSync } from 'child_process';
import * as readline from 'readline';

const PLATFORM = process.platform;
const IS_WINDOWS = PLATFORM === 'win32';
const IS_MAC = PLATFORM === 'darwin';
const IS_LINUX = PLATFORM === 'linux';

const HOME = IS_WINDOWS
  ? process.env.USERPROFILE || os.homedir()
  : process.env.HOME || os.homedir();

const CLAUDE_DIR = path.join(HOME, '.claude');

// Cross-platform permission setting
function setPermissions(targetDir: string): void {
  if (IS_WINDOWS) {
    // Windows: Use icacls if needed, or skip (default permissions usually OK)
    console.log('Setting Windows permissions...');
    // Optionally: run icacls command
    spawnSync('icacls', [targetDir, '/grant', `${process.env.USERNAME}:(OI)(CI)F`], {
      shell: true
    });
  } else {
    // Unix: chmod
    spawnSync('chmod', ['-R', '755', targetDir]);
    spawnSync('chown', ['-R', `${process.env.USER}:${process.env.USER}`, targetDir]);
  }
}

// Cross-platform file search
function findExecutableFiles(dir: string, pattern: string): string[] {
  const results: string[] = [];

  function walk(currentPath: string) {
    const files = fs.readdirSync(currentPath);
    for (const file of files) {
      const fullPath = path.join(currentPath, file);
      const stat = fs.statSync(fullPath);

      if (stat.isDirectory()) {
        walk(fullPath);
      } else if (file.match(pattern)) {
        results.push(fullPath);
      }
    }
  }

  walk(dir);
  return results;
}

// Cross-platform executable permission
function makeExecutable(filePath: string): void {
  if (IS_WINDOWS) {
    // Windows: check if needs .exe extension
    if (!filePath.endsWith('.exe') && !filePath.endsWith('.bat') && !filePath.endsWith('.ps1')) {
      const renamed = filePath + '.exe';
      if (fs.existsSync(filePath) && !fs.existsSync(renamed)) {
        fs.renameSync(filePath, renamed);
      }
    }
  } else {
    // Unix: chmod +x
    spawnSync('chmod', ['+x', filePath]);
  }
}

// Cross-platform Bun installation
function installBun(): boolean {
  if (IS_WINDOWS) {
    // Windows: Use PowerShell installer
    const result = spawnSync('powershell', [
      '-Command',
      'irm bun.sh/install.ps1 | iex'
    ], { shell: true });

    return result.status === 0;
  } else {
    // Unix: Use curl with bash
    const result = spawnSync('curl', ['-fsSL', 'https://bun.sh/install'], {
      stdio: 'pipe'
    });

    if (result.status === 0) {
      const installScript = spawnSync('bash', ['-'], {
        input: result.stdout
      });
      return installScript.status === 0;
    }
  }

  return false;
}

// Cross-platform shell reloading
function reloadShell(): void {
  console.log('\n⚠️  Please restart your terminal/shell for changes to take effect.');

  if (IS_MAC) {
    console.log('   Run: source ~/.zshrc');
  } else if (IS_LINUX) {
    console.log('   Run: source ~/.bashrc or source ~/.zshrc');
  } else if (IS_WINDOWS) {
    console.log('   Close and reopen PowerShell or Command Prompt');
    console.log('   Or run: refreshenv');
  }
}

// Main installation function
async function install(): Promise<void> {
  console.log('🤖 PAI v2.5 Installation Wizard');
  console.log(`Platform: ${PLATFORM}`);

  // Get user information
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  const name = await question(rl, 'Your name: ');
  const projectsDir = await question(rl, 'Projects directory (default: ~/Projects): ', '~/Projects');

  rl.close();

  // Create directories
  console.log('\n📁 Creating directories...');
  const dirs = [
    CLAUDE_DIR,
    path.join(CLAUDE_DIR, 'MEMORY'),
    path.join(CLAUDE_DIR, 'WORK'),
    path.join(CLAUDE_DIR, 'STATE'),
    path.join(CLAUDE_DIR, 'USER')
  ];

  for (const dir of dirs) {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
      console.log(`  Created: ${dir}`);
    }
  }

  // Set permissions
  console.log('\n🔐 Setting permissions...');
  setPermissions(CLAUDE_DIR);

  // Find and make executable files executable
  console.log('\n🔧 Setting executable permissions...');
  const execFiles = findExecutableFiles(CLAUDE_DIR, '\\.(ts|js|sh|py)$');
  for (const file of execFiles) {
    makeExecutable(file);
  }

  // Create settings.json
  console.log('\n⚙️  Creating configuration...');
  const settings = {
    daidentity: {
      name: 'PAI',
      version: '2.5.0'
    },
    principal: {
      name: name,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone
    },
    projects: {
      defaultDirectory: path.resolve(HOME, projectsDir.replace('~', HOME))
    },
    platform: PLATFORM,
    installDate: new Date().toISOString()
  };

  fs.writeFileSync(
    path.join(CLAUDE_DIR, 'settings.json'),
    JSON.stringify(settings, null, 2),
    'utf8'
  );

  // Configure shell
  console.log('\n🐚 Configuring shell...');
  if (IS_WINDOWS) {
    configurePowerShell();
  } else {
    configureUnixShell();
  }

  console.log('\n✅ Installation complete!');
  reloadShell();
}

function question(rl: readline.Interface, query: string, defaultVal?: string): Promise<string> {
  return new Promise((resolve) => {
    rl.question(`${query}${defaultVal ? ` [${defaultVal}]` : ''}`, (answer) => {
      resolve(answer || defaultVal || '');
    });
  });
}

// PowerShell configuration
function configurePowerShell(): void {
  const powershellConfig = `
# PAI v2.5 Configuration
export PAI_HOME="$env:USERPROFILE\\.claude"
export PATH="$PATH;$PAI_HOME\\bin"
`;

  const profilePath = path.join(HOME, 'Documents', 'PowerShell', 'Microsoft.PowerShell_profile.ps1');

  try {
    let content = '';
    if (fs.existsSync(profilePath)) {
      content = fs.readFileSync(profilePath, 'utf8');
    }

    if (!content.includes('PAI v2.5')) {
      fs.appendFileSync(profilePath, powershellConfig, 'utf8');
      console.log('  Added PAI configuration to PowerShell profile');
    }
  } catch (error) {
    console.warn('  Could not configure PowerShell profile:', error.message);
  }
}

// Unix shell configuration
function configureUnixShell(): void {
  const shellConfig = `
# PAI v2.5 Configuration
export PAI_HOME="$HOME/.claude"
export PATH="$PATH:$PAI_HOME/bin"
`;

  const zshrcPath = path.join(HOME, '.zshrc');
  const bashrcPath = path.join(HOME, '.bashrc');

  if (fs.existsSync(zshrcPath)) {
    let content = fs.readFileSync(zshrcPath, 'utf8');
    if (!content.includes('PAI v2.5')) {
      fs.appendFileSync(zshrcPath, shellConfig, 'utf8');
      console.log('  Added PAI configuration to ~/.zshrc');
    }
  } else if (fs.existsSync(bashrcPath)) {
    let content = fs.readFileSync(bashrcPath, 'utf8');
    if (!content.includes('PAI v2.5')) {
      fs.appendFileSync(bashrcPath, shellConfig, 'utf8');
      console.log('  Added PAI configuration to ~/.bashrc');
    }
  }
}

install().catch(console.error);
```

### 2. Create PowerShell Status Line Script
**File**: `.claude/statusline-command.ps1` (NEW FILE)

**Convert from bash to PowerShell:**

```powershell
# PAI v2.5 Status Line - PowerShell Version
# Equivalent to statusline-command.sh for Windows

param(
    [string]$Mode = "normal",
    [switch]$Debug
)

$ErrorActionPreference = "SilentlyContinue"

# Color schemes
$colors = @{
    reset = "`e[0m"
    bold = "`e[1m"
    dim = "`e[2m"

    # Foreground colors
    black = "`e[30m"
    red = "`e[31m"
    green = "`e[32m"
    yellow = "`e[33m"
    blue = "`e[34m"
    magenta = "`e[35m"
    cyan = "`e[36m"
    white = "`e[37m"

    # Background colors
    bg_black = "`e[40m"
    bg_red = "`e[41m"
    bg_green = "`e[42m"
    bg_yellow = "`e[43m"
    bg_blue = "`e[44m"
    bg_magenta = "`e[45m"
    bg_cyan = "`e[46m"
    bg_white = "`e[47m"
}

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

function Get-PaiInfo {
    $paiHome = "$env:USERPROFILE\.claude"
    $settingsFile = "$paiHome\settings.json"

    if (Test-Path $settingsFile) {
        try {
            $settings = Get-Content $settingsFile | ConvertFrom-Json
            return $settings.daidentity.name
        } catch {
            return "PAI"
        }
    }

    return "PAI"
}

function Get-DateTime {
    return Get-Date -Format "HH:mm:ss"
}

function Get-WindowSize {
    $ui = $Host.UI.RawUI
    return $ui.WindowSize.Width
}

function Show-StatusLine {
    $width = Get-WindowSize
    $leftPad = 1
    $rightPad = 1

    # Build left side
    $paiInfo = Get-PaiInfo
    $gitStatus = Get-GitStatus
    $currentDir = Get-CurrentDirectory

    $leftParts = @($paiInfo, $gitStatus, $currentDir)
    $leftText = $leftParts -join " | "
    $leftText = $leftText.PadRight($width / 2)

    # Build right side
    $dateTime = Get-DateTime
    $rightText = $dateTime.PadLeft($width / 2)

    # Combine
    $statusLine = "$leftText$rightText"

    # Apply colors
    $coloredLine = "$($colors.bold)$($colors.cyan)$statusLine$($colors.reset)"

    # Write status line
    Write-Host "`r$coloredLine" -NoNewline
}

# Main loop
try {
    while ($true) {
        Show-StatusLine
        Start-Sleep -Milliseconds 100
    }
} catch {
    Write-Host "Status line error: $_" -ForegroundColor Red
}
```

### 3. Adapt VoiceServer for Windows
**Files**:
- `.claude/VoiceServer/server.py`
- `.claude/VoiceServer/start.sh` → Create `start.ps1`
- `.claude/VoiceServer/stop.sh` → Create `stop.ps1`

**Windows Startup Script (start.ps1):**

```powershell
# VoiceServer Windows Startup Script

$VoiceDir = "$env:USERPROFILE\.claude\VoiceServer"
$PidFile = "$VoiceDir\voice.pid"
$LogFile = "$VoiceDir\voice.log"

# Check if already running
if (Test-Path $PidFile) {
    $oldPid = Get-Content $PidFile
    $process = Get-Process -Id $oldPid -ErrorAction SilentlyContinue

    if ($process) {
        Write-Host "VoiceServer is already running (PID: $oldPid)" -ForegroundColor Yellow
        exit 1
    } else {
        Remove-Item $PidFile
    }
}

# Start the server
Write-Host "Starting VoiceServer..." -ForegroundColor Green

# Use uvicorn (Python HTTP server)
$env:PYTHONUNBUFFERED = "1"
$process = Start-Process -FilePath "uvicorn" -ArgumentList @(
    "server:app",
    "--host", "127.0.0.1",
    "--port", "8888",
    "--log-level", "info"
) -PassThru -RedirectStandardOutput $LogFile -RedirectStandardError $LogFile -NoNewWindow

# Save PID
$process.Id | Out-File -FilePath $PidFile -Encoding utf8

Write-Host "VoiceServer started (PID: $($process.Id))" -ForegroundColor Green
Write-Host "Logs: $LogFile"
Write-Host "Health check: http://127.0.0.1:8888/health"
```

**Windows Shutdown Script (stop.ps1):**

```powershell
# VoiceServer Windows Shutdown Script

$VoiceDir = "$env:USERPROFILE\.claude\VoiceServer"
$PidFile = "$VoiceDir\voice.pid"

if (-not (Test-Path $PidFile)) {
    Write-Host "VoiceServer is not running" -ForegroundColor Yellow
    exit 1
}

$pid = Get-Content $PidFile
$process = Get-Process -Id $pid -ErrorAction SilentlyContinue

if ($process) {
    Write-Host "Stopping VoiceServer (PID: $pid)..." -ForegroundColor Yellow
    Stop-Process -Id $pid -Force
    Remove-Item $PidFile
    Write-Host "VoiceServer stopped" -ForegroundColor Green
} else {
    Write-Host "VoiceServer process not found" -ForegroundColor Red
    Remove-Item $PidFile
}
```

**Update server.py for Windows audio:**

```python
import platform
import subprocess
import os

def play_audio(audio_file: str):
    """Play audio file on Windows, Mac, or Linux"""
    system = platform.system()

    if system == "Windows":
        # Windows: use powershell with media player
        cmd = [
            "powershell",
            "-Command",
            f"(New-Object Media.SoundPlayer '{audio_file}').PlaySync()"
        ]
        subprocess.run(cmd, shell=True)
    elif system == "Darwin":
        # macOS: afplay
        subprocess.run(["afplay", audio_file])
    else:
        # Linux: paplay (PulseAudio) or aplay (ALSA)
        try:
            subprocess.run(["paplay", audio_file], check=False)
        except FileNotFoundError:
            subprocess.run(["aplay", audio_file], check=False)
```

### 4. Adapt Observability Dashboard for Windows
**File**: `.claude/Observability/start.sh` → Create `start.ps1`

```powershell
# Observability Dashboard - Windows Startup

$ObsDir = "$env:USERPROFILE\.claude\Observability"
$PidFile = "$ObsDir\dashboard.pid"
$Port = 8889

# Check if already running
if (Test-Path $PidFile) {
    $oldPid = Get-Content $PidFile
    $process = Get-Process -Id $oldPid -ErrorAction SilentlyContinue

    if ($process) {
        Write-Host "Observability dashboard is already running (PID: $oldPid)" -ForegroundColor Yellow
        Write-Host "Access at: http://localhost:$Port"
        exit 1
    } else {
        Remove-Item $PidFile
    }
}

# Start dashboard
Write-Host "Starting Observability Dashboard..." -ForegroundColor Green

# Determine how to start (Python, Node, etc.)
$command = "python"
$script = "$ObsDir\dashboard.py"

if (-not (Test-Path $script)) {
    # Try alternate implementations
    $script = "$ObsDir\dashboard.js"
    $command = "node"
}

if (-not (Test-Path $script)) {
    Write-Host "Dashboard script not found" -ForegroundColor Red
    exit 1
}

$env:PORT = $Port
$process = Start-Process -FilePath $command -ArgumentList $script -PassThru -NoNewWindow

# Save PID
$process.Id | Out-File -FilePath $PidFile -Encoding utf8

Write-Host "Dashboard started (PID: $($process.Id))" -ForegroundColor Green
Write-Host "Access at: http://localhost:$Port"

# Wait a moment then open browser
Start-Sleep -Seconds 2
Start-Process "http://localhost:$Port"
```

### 5. Update settings.json for Windows
**File**: `.claude/settings.json`

```json
{
  "daidentity": {
    "name": "PAI",
    "version": "2.5.0",
    "personality": "helpful AI assistant"
  },
  "principal": {
    "name": "YOUR_NAME_HERE",
    "timezone": "America/New_York",
    "platform": "windows"
  },
  "projects": {
    "defaultDirectory": "C:\\Users\\YOUR_NAME\\Projects",
    "aliases": {}
  },
  "voice": {
    "enabled": true,
    "voiceId": "default",
    "serverUrl": "http://localhost:8888"
  },
  "observability": {
    "enabled": true,
    "dashboardUrl": "http://localhost:8889",
    "metricsCollection": true
  },
  "terminal": {
    "preferred": "windows-terminal",
    "fallback": "powershell"
  },
  "techStack": {
    "language": "TypeScript",
    "runtime": "Bun",
    "packageManager": "bun",
    "testFramework": "bun test",
    "linter": "biome"
  },
  "hooks": {
    "enabled": true,
    "shell": "powershell"
  },
  "paths": {
    "home": "C:\\Users\\YOUR_NAME",
    "claude": "C:\\Users\\YOUR_NAME\\.claude",
    "projects": "C:\\Users\\YOUR_NAME\\Projects",
    "temp": "C:\\Users\\YOUR_NAME\\AppData\\Local\\Temp"
  },
  "platform": "win32",
  "installDate": "2026-02-10T00:00:00Z"
}
```

### 6. Create Windows Service Wrapper for VoiceServer
**File**: `.claude/VoiceServer/install-service.ps1` (NEW)

```powershell
# Install VoiceServer as Windows Service using NSSM
# Requires: NSSM (Non-Sucking Service Manager)
# Download: https://nssm.cc/download

$ServiceName = "PAIVoiceServer"
$VoiceDir = "$env:USERPROFILE\.claude\VoiceServer"
$StartupScript = "$VoiceDir\start.ps1"

# Check if NSSM is available
$nssm = Get-Command nssm -ErrorAction SilentlyContinue

if (-not $nssm) {
    Write-Host "NSSM not found. Installing..." -ForegroundColor Yellow
    winget install nssm
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# Install service
& nssm install $ServiceName powershell.exe -ExecutionPolicy Bypass -File $StartupScript
& nssm set $ServiceName AppDirectory $VoiceDir
& nssm set $ServiceName DisplayName "PAI Voice Notification Server"
& nssm set $ServiceName Description "Voice notification server for PAI v2.5"
& nssm set $ServiceName Start SERVICE_AUTO_START

Write-Host "Service installed successfully" -ForegroundColor Green
Write-Host "Start service: Start-Service $ServiceName"
Write-Host "Stop service: Stop-Service $ServiceName"
Write-Host "Remove service: nssm remove $ServiceName confirm"
```

### 7. Update PAI Skill Documentation
**File**: `.claude/skills/PAI/SKILL.md`

Add Windows-specific sections:

```markdown
## Platform Support

PAI v2.5 supports multiple platforms:

### Windows
- **Required**: Windows 10/11
- **Shell**: PowerShell (primary), Command Prompt (legacy)
- **Installation**: Run `bun run INSTALL.ts` in PowerShell
- **Service**: VoiceServer can run as Windows Service (NSSM)
- **Status Line**: Use `statusline-command.ps1`
- **Paths**: Use backslashes or forward slashes (Node.js normalizes)

### macOS
- **Required**: macOS 10.15+
- **Shell**: zsh (default), bash
- **Installation**: Run `bun run INSTALL.ts` in Terminal
- **Service**: VoiceServer uses launchd
- **Status Line**: Use `statusline-command.sh`

### Linux
- **Required**: Any modern distribution
- **Shell**: bash, zsh
- **Installation**: Run `bun run INSTALL.ts` in Terminal
- **Service**: VoiceServer uses systemd
- **Status Line**: Use `statusline-command.sh`
```

### 8. Create Windows Installation Documentation
**File**: `.claude/INSTALL-Windows.md` (NEW)

```markdown
# PAI v2.5 - Windows Installation Guide

## Prerequisites

1. **Windows 10/11** (Windows 7/8 not supported)
2. **PowerShell 5.1 or later** (included with Windows 10/11)
3. **Node.js 18+** or **Bun runtime**
4. **Git** (optional, for version control)

## Quick Install

### Option 1: Using Bun (Recommended)

```powershell
# 1. Install Bun (if not already installed)
powershell -c "irm bun.sh/install.ps1 | iex"

# 2. Navigate to PAI directory
cd C:\Users\YOUR_NAME\Downloads\Orion\Personal_AI_Infrastructure-main\Releases\v2.5

# 3. Run installation wizard
cd .claude
bun run INSTALL.ts
```

### Option 2: Using Node.js

```powershell
# 1. Install Node.js from https://nodejs.org/

# 2. Navigate to PAI directory
cd C:\Users\YOUR_NAME\Downloads\Orion\Personal_AI_Infrastructure-main\Releases\v2.5

# 3. Run installation wizard
cd .claude
node INSTALL.ts
```

## Installation Wizard

The wizard will prompt for:

1. **Your name**: Used for personalization
2. **Projects directory**: Default is `C:\Users\YOUR_NAME\Projects`
3. **AI name**: What to call your assistant (default: Kai)
4. **ElevenLabs API key**: Optional, for voice notifications

## Post-Installation

### 1. Restart PowerShell

Close and reopen PowerShell to load new environment variables.

### 2. Verify Installation

```powershell
# Check PAI directory
Test-Path $env:USERPROFILE\.claude

# View settings
Get-Content $env:USERPROFILE\.claude\settings.json

# Check PAI version
pai --version
```

### 3. Start VoiceServer (Optional)

```powershell
cd $env:USERPROFILE\.claude\VoiceServer
.\start.ps1
```

### 4. Start Observability Dashboard (Optional)

```powershell
cd $env:USERPROFILE\.claude\Observability
.\start.ps1
```

## Optional: Install as Windows Service

Run VoiceServer as a background service:

```powershell
cd $env:USERPROFILE\.claude\VoiceServer
.\install-service.ps1

# Start service
Start-Service PAIVoiceServer

# Check status
Get-Service PAIVoiceServer
```

## Troubleshooting

### Execution Policy Error

If you see "cannot run scripts", enable PowerShell scripts:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Path Too Long Errors

Windows has a 260 character path limit. Enable long paths:

```powershell
# Run as Administrator
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
    -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

### VoiceServer Won't Start

Check if port 8888 is already in use:

```powershell
netstat -ano | findstr :8888

# Kill process using port (replace PID)
taskkill /F /PID <PID>
```

### Git Commands Not Found

Install Git for Windows:

```powershell
winget install Git.Git
```

## Uninstall

```powershell
# Stop services
Stop-Service PAIVoiceServer

# Remove service
nssm remove PAIVoiceServer confirm

# Remove PAI directory
Remove-Item -Recurse -Force $env:USERPROFILE\.claude

# Remove PowerShell profile config
# Edit: $env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
# Remove PAI-related lines
```

## Next Steps

1. Read the main README.md
2. Explore skills in `.claude\skills\`
3. Configure settings in `.claude\settings.json`
4. Start using PAI with Claude Code
```

### 9. Update Shared Libraries
**Files**: `.claude/lib/` directory

Create cross-platform utilities:

```typescript
// .claude/lib/platform.ts
export const PLATFORM = process.platform;
export const IS_WINDOWS = PLATFORM === 'win32';
export const IS_MAC = PLATFORM === 'darwin';
export const IS_LINUX = PLATFORM === 'linux';

export const HOME = IS_WINDOWS
  ? process.env.USERPROFILE || require('os').homedir()
  : process.env.HOME || require('os').homedir();

export const CLAUDE_DIR = require('path').join(HOME, '.claude');

export function getCommand(command: string): string {
  // Map Unix commands to Windows equivalents
  const commandMap: Record<string, string> = {
    'ls': IS_WINDOWS ? 'dir' : 'ls',
    'cat': IS_WINDOWS ? 'type' : 'cat',
    'rm': IS_WINDOWS ? 'del' : 'rm',
    'cp': IS_WINDOWS ? 'copy' : 'cp',
    'mv': IS_WINDOWS ? 'move' : 'mv',
    'ps': IS_WINDOWS ? 'tasklist' : 'ps',
    'kill': IS_WINDOWS ? 'taskkill' : 'kill',
  };

  return commandMap[command] || command;
}
```

## Validation Commands

### Windows Testing
```powershell
# 1. Test installation wizard
cd C:\Users\JOSE\Downloads\Orion\Personal_AI_Infrastructure-main\Releases\v2.5\.claude
bun run INSTALL.ts

# 2. Verify settings created
Get-Content $env:USERPROFILE\.claude\settings.json

# 3. Test VoiceServer
cd $env:USERPROFILE\.claude\VoiceServer
.\start.ps1
curl http://localhost:8888/health
.\stop.ps1

# 4. Test status line
cd C:\Users\JOSE\Downloads\Orion\Personal_AI_Infrastructure-main\Releases\v2.5\.claude
.\statusline-command.ps1

# 5. Test Observability
cd $env:USERPROFILE\.claude\Observability
.\start.ps1

# 6. Verify all paths resolve
Test-Path $env:USERPROFILE\.claude
Test-Path $env:USERPROFILE\.claude\skills
Test-Path $env:USERPROFILE\.claude\hooks

# 7. Test PowerShell profile
cat $env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
```

### Cross-Platform Validation
```bash
# On Mac/Linux
cd ~/.claude
bun run INSTALL.ts

# On Windows (PowerShell)
cd $env:USERPROFILE\.claude
bun run INSTALL.ts
```

### Integration Tests
```powershell
# Full installation test
cd C:\Users\JOSE\Downloads\Orion\Personal_AI_Infrastructure-main\Releases\v2.5
.\test-windows-installation.ps1

# Test all hooks load
Get-ChildItem -Recurse .claude\hooks\*.ts | ForEach-Object {
    node $_.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed: $($_.FullName)"
    }
}
```

### Manual Testing Checklist
- [ ] INSTALL.ts runs without errors on Windows
- [ ] Settings file created in correct location
- [ ] PowerShell profile configured correctly
- [ ] Environment variables accessible after restart
- [ ] VoiceServer starts and responds to health check
- [ ] VoiceServer stops cleanly
- [ ] Status line displays in PowerShell
- [ ] Observability dashboard accessible
- [ ] All PAI skills load correctly
- [ ] Hooks execute without errors
- [ ] File paths resolve correctly
- [ ] No hardcoded Unix paths remain
- [ ] Service installation works (optional)

## Notes

### Windows-Specific Challenges

1. **Execution Policy**
   - PowerShell scripts disabled by default
   - User must enable: `Set-ExecutionPolicy RemoteSigned`

2. **Path Length Limitation**
   - 260 character limit (MAX_PATH)
   - Enable long paths via registry
   - Use `\\?\` prefix for long paths

3. **Case Insensitivity**
   - NTFS is case-insensitive but case-preserving
   - Don't rely on case for comparisons

4. **File Locking**
   - Windows locks files more aggressively
   - Ensure proper file closure before operations

5. **Line Endings**
   - Git may convert LF to CRLF
   - Configure: `git config --global core.autocrlf true`

6. **Permissions**
   - UAC may prompt for administrative operations
   - Some operations require elevated privileges

### Recommended Windows Tools

1. **Package Managers**
   - **winget**: Built into Windows 11
   - **Chocolatey**: Third-party package manager
   - **scoop**: User-space package manager

2. **Terminal**
   - **Windows Terminal**: Modern terminal with tabs
   - **PowerShell 7**: Cross-platform PowerShell
   - **Git Bash**: Unix emulation

3. **Services**
   - **NSSM**: Non-Sucking Service Manager
   - **sc.exe**: Built-in service control

4. **Development**
   - **VS Code**: Recommended editor
   - **Windows Subsystem for Linux (WSL)**: Optional Unix layer

### Performance Optimizations

1. **PowerShell Startup**
   - Optimize profile: Remove unnecessary imports
   - Use PowerShell 7 for better performance

2. **File Operations**
   - Use `System.IO` for bulk operations
   - Batch file operations

3. **Process Spawning**
   - Reuse process handles
   - Use `Start-Process -NoNewWindow`

### Testing Strategy

1. **Unit Tests**
   - Test each platform detection function
   - Verify path resolution

2. **Integration Tests**
   - Test installation wizard end-to-end
   - Verify service lifecycle

3. **Platform Tests**
   - Windows 10
   - Windows 11
   - Different PowerShell versions

4. **User Scenarios**
   - Fresh install
   - Upgrade from previous version
   - Uninstall/reinstall

### Dependencies

```json
{
  "dependencies": {
    "cross-spawn": "^7.0.3",
    "node-notifier": "^10.0.1",
    "platform-folders": "^0.5.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0"
  }
}
```

### Breaking Changes
- INSTALL.ts completely rewritten (backward-compatible via platform detection)
- New PowerShell scripts replace shell scripts
- settings.json structure updated (migration path provided)

### Rollback Plan
Keep Unix implementations in functions, use platform detection:

```typescript
if (IS_WINDOWS) {
  // Windows implementation
} else {
  // Unix implementation (original)
}
```

### Related Work
- Hooks Group A adaptation (first half of hooks)
- Hooks Group B adaptation (second half of hooks)
- PowerShell script creation for status line

### Next Steps
1. Update INSTALL.ts first (blocks everything else)
2. Create PowerShell scripts
3. Test installation on clean Windows machine
4. Test upgrade scenario
5. Document any additional issues found

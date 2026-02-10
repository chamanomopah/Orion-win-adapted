# PAI v2.5 - Windows Installation Guide

## Prerequisites

1. **Windows 10/11** (Windows 7/8 not supported)
2. **PowerShell 5.1 or later** (included with Windows 10/11)
3. **PowerShell 7+** (recommended for better performance)
4. **Node.js 18+** or **Bun runtime**
5. **Git** (optional, for version control)
6. **Python 3.8+** (required for VoiceServer)

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
3. **AI name**: What to call your assistant (default: PAI)
4. **ElevenLabs API key**: Optional, for voice notifications

## Post-Installation

### 1. Restart PowerShell

Close and reopen PowerShell to load new environment variables and functions.

### 2. Verify Installation

```powershell
# Check PAI directory
Test-Path $env:USERPROFILE\.claude

# View settings
Get-Content $env:USERPROFILE\.claude\settings.json

# Check PAI version
pai --version
```

### 3. Install Python Dependencies (for VoiceServer)

```powershell
# Install required packages
python -m pip install fastapi uvicorn torch torchaudio
```

### 4. Start VoiceServer (Optional)

```powershell
cd $env:USERPROFILE\.claude\VoiceServer
.\start.ps1

# Test voice
curl.exe -X POST http://localhost:8888/notify -H "Content-Type: application/json" -d '{\"message\": \"Hello from PAI\"}'

# Stop server
.\stop.ps1
```

### 5. Start Observability Dashboard (Optional)

```powershell
cd $env:USERPROFILE\.claude\Observability
.\start.ps1
```

## Optional: Install as Windows Service

Run VoiceServer as a background service using NSSM:

```powershell
cd $env:USERPROFILE\.claude\VoiceServer
.\install-service.ps1
```

This will:
- Install VoiceServer as a Windows service named "PAIVoiceServer"
- Configure auto-start on boot
- Set up logging
- Start the service immediately

### Service Management

```powershell
# Check service status
Get-Service PAIVoiceServer

# Start service
Start-Service PAIVoiceServer

# Stop service
Stop-Service PAIVoiceServer

# Restart service
Restart-Service PAIVoiceServer

# View logs
Get-Content $env:USERPROFILE\.claude\VoiceServer\logs\service-out.log

# Remove service
nssm remove PAIVoiceServer confirm
```

## Platform-Specific Features

### Windows Terminal vs PowerShell

**Recommended**: Use Windows Terminal for the best experience
- Download from Microsoft Store
- Supports multiple tabs, Unicode, and true color
- Better performance than legacy Console

**PowerShell 7**: Install for cross-platform compatibility
```powershell
winget install Microsoft.PowerShell
```

### Path Handling

PAI on Windows handles paths automatically:
- Backslashes (`\`) work everywhere
- Forward slashes (`/`) also work (Node.js normalizes them)
- Environment variables like `$env:USERPROFILE` expand correctly

### File Permissions

Windows uses ACLs instead of Unix permissions:
- INSTALL.ts uses `icacls` for setting permissions
- Default permissions usually work fine
- Admin privileges required for some operations

## Troubleshooting

### Execution Policy Error

**Problem**: "cannot run scripts because execution policy is restricted"

**Solution**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Path Too Long Errors

**Problem**: "The specified path, file name, or both are too long"

Windows has a 260 character path limit (MAX_PATH).

**Solution 1**: Enable long paths (Windows 10+)
```powershell
# Run as Administrator
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
    -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

**Solution 2**: Move installation closer to root
```powershell
# Instead of:
C:\Users\LongName\Downloads\Orion\Personal_AI_Infrastructure-main\Releases\v2.5

# Use:
C:\PAI
```

### VoiceServer Won't Start

**Problem**: Port 8888 already in use

**Solution**:
```powershell
# Find process using port
netstat -ano | findstr :8888

# Kill process (replace PID)
taskkill /F /PID <PID>
```

**Problem**: Python not found

**Solution**:
```powershell
# Install Python
winget install Python.Python.3.11

# Or download from: https://www.python.org/downloads/
```

**Problem**: Missing dependencies

**Solution**:
```powershell
# Install required packages
python -m pip install fastapi uvicorn torch torchaudio soundfile
```

### Git Commands Not Found

**Problem**: git command not recognized

**Solution**:
```powershell
winget install Git.Git
```

Then restart PowerShell.

### PowerShell Profile Issues

**Problem**: PAI alias not working after installation

**Solution**:
```powershell
# Check if profile was created
Test-Path $env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1

# View profile
Get-Content $env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1

# Manually add alias (add to profile)
function pai { bun $env:USERPROFILE\.claude\skills\PAI\Tools\pai.ts $args }
```

### NSSM Service Installation Fails

**Problem**: NSSM not found or installation fails

**Solution**:
```powershell
# Install NSSM manually
# 1. Download from: https://nssm.cc/download
# 2. Extract to C:\nssm
# 3. Add to PATH: $env:Path += ";C:\nssm"

# Or use winget (Windows 11)
winget install nssm
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
# Remove PAI-related lines (look for "# PAI alias" marker)
```

## Windows-Specific Configuration

### Settings.json

The installation wizard creates a Windows-specific settings.json:

```json
{
  "platform": "win32",
  "techStack": {
    "terminal": "windows-terminal",
    "packageManager": "bun"
  },
  "statusLine": {
    "command": "${PAI_DIR}/statusline-command.ps1"
  },
  "paths": {
    "home": "C:\\Users\\YOUR_NAME",
    "claude": "C:\\Users\\YOUR_NAME\\.claude",
    "projects": "C:\\Users\\YOUR_NAME\\Projects"
  }
}
```

### Environment Variables

PAI uses these environment variables on Windows:
- `$env:USERPROFILE` - User home directory
- `$env:PAI_DIR` - PAI installation directory (set by installer)
- `$env:PROJECTS_DIR` - Projects root directory (optional)

### File Locations

Windows-specific file locations:
- **Config**: `%USERPROFILE%\.claude\settings.json`
- **Logs**: `%USERPROFILE%\.claude\VoiceServer\logs\`
- **Memory**: `%USERPROFILE%\.claude\MEMORY\`
- **Hooks**: `%USERPROFILE%\.claude\hooks\`
- **Skills**: `%USERPROFILE%\.claude\skills\`

## Performance Tips

### Use PowerShell 7

PowerShell 7 is faster and more compatible than Windows PowerShell 5.1:

```powershell
# Install PowerShell 7
winget install Microsoft.PowerShell

# Run PAI in PowerShell 7
pwsh
pai
```

### Enable Windows Terminal

Windows Terminal provides better performance and features:
- Tabbed interface
- GPU-accelerated text rendering
- True color support
- Unicode support

### Exclude from Antivirus Scans

Add PAI directories to Windows Defender exclusions for better performance:

```powershell
# Run as Administrator
Add-MpPreference -ExclusionPath "$env:USERPROFILE\.claude"
```

## Next Steps

1. Read the main README.md
2. Explore skills in `.claude\skills\`
3. Configure settings in `.claude\settings.json`
4. Start using PAI with Claude Code

## Getting Help

- **GitHub Issues**: https://github.com/danielmiessler/PAI/issues
- **Documentation**: `.claude\README.md`
- **Troubleshooting**: Check logs in `%USERPROFILE%\.claude\VoiceServer\logs\`

## Compatibility Notes

### What Works on Windows

✅ Full installation wizard
✅ VoiceServer with Windows audio
✅ PowerShell status line
✅ Observability dashboard
✅ All PAI skills
✅ Hooks and automation
✅ Git integration
✅ Claude Code integration

### Limitations

⚠️ Some Unix-specific skills may not work
⚠️ Terminal apps may have limited functionality
⚠️ File permissions work differently

### Workarounds

For Unix-specific features:
- Use WSL (Windows Subsystem for Linux)
- Use Git Bash for Unix commands
- Use WSL2 for full Linux compatibility

```powershell
# Install WSL
wsl --install

# Use PAI from WSL
wsl
cd ~/.claude
```

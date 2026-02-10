# PAI Platform Support

PAI v2.5 supports multiple platforms with cross-platform infrastructure.

## Supported Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| **Windows 10/11** | ✅ Fully Supported | PowerShell + Windows Terminal recommended |
| **macOS 10.15+** | ✅ Fully Supported | zsh (default), bash supported |
| **Linux** | ✅ Fully Supported | Tested on Ubuntu, Debian, Fedora |

## Platform-Specific Features

### Windows

**Installation:**
```powershell
cd .claude
bun run INSTALL.ts
```

**Shell:** PowerShell (primary) or Command Prompt (legacy)

**Features:**
- ✅ Cross-platform installation wizard
- ✅ PowerShell VoiceServer scripts (start.ps1, stop.ps1)
- ✅ Windows Service support (via NSSM)
- ✅ PowerShell status line (statusline-command.ps1)
- ✅ Windows audio playback (PowerShell SoundPlayer)
- ✅ Path handling (backslashes and forward slashes)
- ✅ Permissions (icacls instead of chmod)

**Recommended Tools:**
- **Terminal:** Windows Terminal
- **PowerShell:** PowerShell 7 (cross-platform)
- **Editor:** VS Code
- **Service Manager:** NSSM

**Documentation:** See `INSTALL-Windows.md`

**Limitations:**
- Some Unix-specific skills may not work
- Consider WSL2 for full Unix compatibility

### macOS

**Installation:**
```bash
cd .claude
bun run INSTALL.ts
```

**Shell:** zsh (default), bash supported

**Features:**
- ✅ Native Unix commands (chmod, chown, find)
- ✅ Bash shell scripts (start.sh, stop.sh)
- ✅ afplay audio
- ✅ launchd service support (planned)
- ✅ Bash status line (statusline-command.sh)

**Recommended Tools:**
- **Terminal:** iTerm2 or Terminal.app
- **Editor:** VS Code or Cursor
- **Package Manager:** Homebrew

**Strengths:**
- Full Unix compatibility
- Best development experience
- Most well-tested platform

### Linux

**Installation:**
```bash
cd .claude
bun run INSTALL.ts
```

**Shell:** bash, zsh

**Features:**
- ✅ Native Unix commands
- ✅ Bash shell scripts
- ✅ PulseAudio/ALSA audio (paplay/aplay)
- ✅ systemd service support (planned)
- ✅ Bash status line (statusline-command.sh)

**Supported Distributions:**
- Ubuntu 20.04+
- Debian 11+
- Fedora 35+
- Arch Linux
- Other modern distributions

**Audio Backend:**
- paplay (PulseAudio) - preferred
- aplay (ALSA) - fallback

## Cross-Platform Libraries

### Platform Detection

```typescript
import { PLATFORM, IS_WINDOWS, IS_MAC, IS_LINUX } from './lib/platform';

if (IS_WINDOWS) {
  // Windows-specific code
} else if (IS_MAC) {
  // macOS-specific code
} else if (IS_LINUX) {
  // Linux-specific code
}
```

### Path Handling

```typescript
import { HOME, CLAUDE_DIR, joinPaths } from './lib/platform';

// Works on all platforms
const configPath = joinPaths(CLAUDE_DIR, 'settings.json');
```

### Command Mapping

```typescript
import { getCommand } from './lib/platform';

const lsCommand = getCommand('ls'); // 'dir' on Windows, 'ls' on Unix
```

### Audio Playback

VoiceServer automatically detects platform and uses appropriate audio backend:
- **Windows:** PowerShell Media.SoundPlayer
- **macOS:** afplay
- **Linux:** paplay (PulseAudio) or aplay (ALSA)

## Installation Comparison

| Feature | Windows | macOS | Linux |
|---------|---------|-------|-------|
| **Package Manager** | bun / winget | bun / brew | bun / apt/dnf |
| **Shell Config** | PowerShell profile | .zshrc | .bashrc / .zshrc |
| **Permissions** | icacls | chmod + chown | chmod + chown |
| **Process Mgmt** | taskkill | kill | kill |
| **Service** | NSSM | launchd (planned) | systemd (planned) |
| **Audio** | SoundPlayer | afplay | paplay/aplay |
| **Status Line** | statusline-command.ps1 | statusline-command.sh | statusline-command.sh |

## File Locations

### Windows
- **Config:** `%USERPROFILE%\.claude\settings.json`
- **Logs:** `%USERPROFILE%\.claude\VoiceServer\logs\`
- **Memory:** `%USERPROFILE%\.claude\MEMORY\`

### macOS/Linux
- **Config:** `~/.claude/settings.json`
- **Logs:** `~/.claude/VoiceServer/logs/`
- **Memory:** `~/.claude/MEMORY/`

## Troubleshooting by Platform

### Windows

**Execution Policy Error:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Path Too Long:**
```powershell
# Enable long paths (Windows 10+)
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
    -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

**Port Already in Use:**
```powershell
netstat -ano | findstr :8888
taskkill /F /PID <PID>
```

### macOS

**Permission Errors:**
```bash
sudo chown -R $(whoami) ~/.claude
chmod -R 755 ~/.claude
```

**Command Not Found:**
```bash
# Install Xcode Command Line Tools
xcode-select --install
```

### Linux

**Permission Errors:**
```bash
sudo chown -R $(whoami) ~/.claude
chmod -R 755 ~/.claude
```

**Missing Dependencies:**
```bash
# Ubuntu/Debian
sudo apt install python3 python3-pip nodejs git

# Fedora
sudo dnf install python3 python3-pip nodejs git
```

## Platform-Specific Configuration

### settings.json

The installation wizard creates platform-specific configuration:

```json
{
  "platform": "win32",  // or "darwin" or "linux"
  "techStack": {
    "terminal": "windows-terminal",  // or "kitty" (macOS/Linux)
    "packageManager": "bun"
  },
  "statusLine": {
    "command": "${PAI_DIR}/statusline-command.ps1"  // or .sh
  }
}
```

## Migration Between Platforms

PAI configuration is cross-platform compatible. To migrate:

1. **Copy ~/.claude directory**
   ```bash
   # From macOS to Windows
   scp -r ~/mac/.claude USER@windows:/c/Users/USER/.claude
   ```

2. **Run installation wizard on new platform**
   ```powershell
   cd .claude
   bun run INSTALL.ts
   ```

3. **Settings will be preserved and adapted**

## Development

### Testing on Multiple Platforms

When developing PAI features:

1. **Use cross-platform libraries** (`lib/platform.ts`)
2. **Test on all supported platforms**
3. **Avoid platform-specific code** unless necessary
4. **Document platform limitations**

### Adding Platform Support

To add support for a new platform:

1. **Add platform detection** in `lib/platform.ts`
2. **Create platform-specific scripts** (start.ps1, start.sh)
3. **Test installation wizard**
4. **Update documentation**

## Performance Comparison

| Operation | Windows | macOS | Linux |
|-----------|---------|-------|-------|
| **File I/O** | Fast | Fast | Fastest |
| **Process Spawn** | Slowest | Fast | Fast |
| **Script Execution** | Slow | Fast | Fastest |
| **Audio Playback** | Medium | Fastest | Fast |

**Recommendations:**
- **Windows:** Use PowerShell 7 for better performance
- **macOS:** Native performance is excellent
- **Linux:** Best overall performance

## Security Considerations

### Windows
- Execution policy must allow scripts
- UAC may prompt for admin operations
- Windows Defender may flag scripts (add exclusions)

### macOS/Linux
- Standard Unix permissions apply
- No special security considerations
- Use sudo for administrative operations

## Future Enhancements

Planned platform-specific features:

- **Windows:** Enhanced Windows Service integration
- **macOS:** launchd service support
- **Linux:** systemd service support
- **All:** GUI installation wizard
- **All:** System tray integration

## Support

For platform-specific issues:
1. Check platform-specific troubleshooting guides
2. Review logs in `~/.claude/VoiceServer/logs/`
3. Open GitHub issue with platform details

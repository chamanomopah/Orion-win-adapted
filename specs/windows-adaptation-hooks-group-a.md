# Chore: Windows Compatibility - Hooks Group A

## Chore Description

Adapt the first half of PAI v2.5 hooks (18 files) from Mac/Linux to Windows by addressing platform-specific code including Unix paths, shell commands, terminal operations, file system operations, and environment variable access patterns.

**Scope**: Hooks Group A includes critical event handlers and utility libraries that process Claude Code interactions, manage agent output, handle work creation, and coordinate system notifications.

## Relevant Files

### Hook Files (5)
- `.claude/hooks/AgentOutputCapture.hook.ts`
- `.claude/hooks/AutoWorkCreation.hook.ts`
- `.claude/hooks/CheckVersion.hook.ts`
- `.claude/hooks/ExplicitRatingCapture.hook.ts`
- `.claude/hooks/FormatReminder.hook.ts`

### Handler Files (7)
- `.claude/hooks/handlers/ISCValidator.ts`
- `.claude/hooks/handlers/RebuildSkill.ts`
- `.claude/hooks/handlers/ResponseCapture.ts`
- `.claude/hooks/handlers/SystemIntegrity.ts`
- `.claude/hooks/handlers/TabState.ts`
- `.claude/hooks/handlers/UpdateCounts.ts`
- `.claude/hooks/handlers/VoiceNotification.ts`

### Library Files (6)
- `.claude/hooks/lib/change-detection.ts`
- `.claude/hooks/lib/identity.ts`
- `.claude/hooks/lib/learning-utils.ts`
- `.claude/hooks/lib/metadata-extraction.ts`
- `.claude/hooks/lib/notifications.ts`
- `.claude/hooks/lib/observability.ts`

## Step by Step Tasks

### 1. Create Cross-Platform Path Utilities
**Files**: All 18 files

Create a shared utility library for path operations:

```typescript
// .claude/hooks/lib/platform-paths.ts (NEW FILE)
import * as path from 'path';
import * as os from 'os';

export const PLATFORM = process.platform;

export const HOME_DIR = PLATFORM === 'win32'
  ? process.env.USERPROFILE || os.homedir()
  : process.env.HOME || os.homedir();

export const CLAUDE_DIR = path.join(HOME_DIR, '.claude');

export function joinPath(...segments: string[]): string {
  return path.join(...segments);
}

export function normalizePath(filePath: string): string {
  return path.normalize(filePath.replace(/\//g, path.sep));
}
```

**Changes required in each file:**
- Replace `process.env.HOME` with `HOME_DIR` from platform-paths.ts
- Replace string path concatenation with `joinPath()` function
- Import and use path.join() consistently

### 2. Replace Unix Shell Commands
**Files**: CheckVersion.hook.ts, AutoWorkCreation.hook.ts

**Issue**: Commands like `claude --version`, `npm view`, `bun` may not work the same on Windows

**Solution**:
```typescript
import { spawnSync } from 'child_process';
import { PLATFORM } from './lib/platform-paths';

function runCommand(command: string, args: string[]): string {
  const shell = PLATFORM === 'win32' ? true : false;
  const result = spawnSync(command, args, {
    shell: PLATFORM === 'win32',
    cwd: process.cwd()
  });

  if (result.error) {
    throw new Error(`Command failed: ${command}`);
  }

  return result.stdout.toString().trim();
}
```

### 3. Fix Kitty Terminal Commands
**Files**: TabState.ts, handlers that manipulate terminal tabs

**Issue**: Kitty terminal specific commands (`kitten @ set-tab-color`, `kitty @ set-tab-title`) don't exist on Windows

**Solution**:
```typescript
import { PLATFORM } from './lib/platform-paths';

function setTabTitle(title: string): void {
  if (PLATFORM === 'win32') {
    // Use Windows Terminal escape sequences or skip
    process.stdout.write(`\x1b]0;${title}\x07`);
  } else {
    // Use Kitty commands
    spawnSync('kitty', ['@', 'set-tab-title', `match=id:${sessionId}`, title]);
  }
}
```

### 4. Replace macOS Notifications
**File**: lib/notifications.ts

**Issue**: Uses `osascript` for macOS notifications

**Solution**:
```typescript
import { PLATFORM } from './platform-paths';

function sendNotification(message: string, title?: string): void {
  if (PLATFORM === 'win32') {
    // Use Windows Toast notifications
    const Toast = require('windows-notify'); // or use node-notifier
    const toast = new Toast();
    toast.notify(message, { title: title || 'PAI' });
  } else if (PLATFORM === 'darwin') {
    // Use osascript for macOS
    spawnSync('osascript', ['-e', `display notification "${message}" with title "${title || 'PAI'}"`]);
  } else {
    // Use libnotify for Linux
    spawnSync('notify-send', [title || 'PAI', message]);
  }
}
```

### 5. Fix Symlink Operations
**File**: handlers/SystemIntegrity.ts

**Issue**: Symlinks don't work the same on Windows (require Developer Mode or Admin privileges)

**Solution**:
```typescript
import * as fs from 'fs';
import * as path from 'path';
import { PLATFORM } from './platform-paths';

function createSymlink(target: string, link: string): void {
  try {
    if (PLATFORM === 'win32') {
      // On Windows, try junction for directories or copy as fallback
      try {
        fs.symlinkSync(target, link, 'junction');
      } catch (err) {
        // Fallback: copy directory/file
        fs.copySync(target, link);
      }
    } else {
      // Unix: normal symlink
      fs.symlinkSync(target, link);
    }
  } catch (error) {
    console.warn(`Failed to create symlink: ${error.message}`);
  }
}
```

### 6. Normalize Line Endings
**Files**: All files that read/write text files

**Issue**: Windows uses `\r\n` vs Unix `\n`

**Solution**:
```typescript
import * as fs from 'fs';

function writeFileWithLineEndings(filePath: string, content: string): void {
  // Normalize to \n for consistency, or use platform default
  const normalizedContent = content.replace(/\r\n/g, '\n');
  fs.writeFileSync(filePath, normalizedContent, 'utf8');
}

function readFileWithLineEndings(filePath: string): string {
  let content = fs.readFileSync(filePath, 'utf8');
  // Normalize line endings when reading
  return content.replace(/\r\n/g, '\n');
}
```

### 7. Update Environment Variable Access
**Files**: All files using process.env

**Issue**: Windows uses different environment variable names and access patterns

**Solution**:
```typescript
// Create platform-aware env access
const ENV = {
  HOME: process.platform === 'win32'
    ? process.env.USERPROFILE || process.env.HOME
    : process.env.HOME,
  USER: process.env.USER || process.env.USERNAME || process.env.USER,
  SHELL: process.env.SHELL || (process.platform === 'win32' ? 'powershell' : 'bash'),
  PATH: process.env.PATH || process.env.Path || process.env.path
};
```

### 8. Fix Process Spawning Options
**Files**: Multiple files using spawnSync or spawn

**Issue**: Windows process spawning requires different options (shell: true)

**Solution**:
```typescript
import { spawnSync, SpawnSyncOptions } from 'child_process';
import { PLATFORM } from './platform-paths';

function spawnCommand(command: string, args: string[]): SpawnSyncOptions {
  const options: SpawnSyncOptions = {
    cwd: process.cwd(),
    env: process.env,
  };

  if (PLATFORM === 'win32') {
    options.shell = true; // Windows requires shell for many commands
  }

  return spawnSync(command, args, options);
}
```

### 9. Update File Permissions Handling
**Files**: handlers/SystemIntegrity.ts, handlers/RebuildSkill.ts

**Issue**: Unix file permissions (chmod, chown) don't work on Windows

**Solution**:
```typescript
import { PLATFORM } from './platform-paths';

function setExecutable(filePath: string): void {
  if (PLATFORM === 'win32') {
    // Windows: file permissions are handled differently
    // Check if file needs .exe extension
    if (!filePath.endsWith('.exe') && !filePath.endsWith('.bat')) {
      const renamed = filePath + '.exe';
      if (fs.existsSync(filePath)) {
        fs.renameSync(filePath, renamed);
      }
    }
  } else {
    // Unix: make executable
    fs.chmodSync(filePath, 0o755);
  }
}
```

### 10. Add Windows Path Separator Normalization
**Files**: All files working with paths

**Solution**:
```typescript
import * as path from 'path';

// Helper to ensure paths work on all platforms
function ensurePath(p: string): string {
  // Convert forward slashes to backslashes on Windows
  if (process.platform === 'win32') {
    return p.replace(/\//g, '\\\\');
  }
  return p;
}

// Always use path.join() internally
const configPath = path.join(HOME_DIR, '.claude', 'settings.json');
```

## Validation Commands

### Windows Testing
```powershell
# 1. Test path resolution
cd C:\Users\JOSE\.claude
node -e "console.log(require('path').join(process.env.USERPROFILE, '.claude'))"

# 2. Test file operations
node -e "const fs = require('fs'); fs.writeFileSync('test.txt', 'test'); console.log('OK');"

# 3. Test process spawning
node -e "const { spawnSync } = require('child_process'); console.log(spawnSync('node', ['--version']).stdout.toString())"

# 4. Test hooks load without errors
cd C:\Users\JOSE\Downloads\Orion\Personal_AI_Infrastructure-main\Releases\v2.5
claude . --test-hooks

# 5. Verify path utilities work
node .claude/hooks/lib/platform-paths.ts
```

### Cross-Platform Validation
```bash
# On Mac/Linux
npm test
bun run lint

# On Windows (PowerShell)
npm test
bun run lint
```

### Manual Testing Checklist
- [ ] All hooks load without errors on Windows
- [ ] File paths resolve correctly on Windows
- [ ] Environment variables accessible on Windows
- [ ] Process spawning works on Windows
- [ ] Notifications display on Windows
- [ ] Terminal operations work (or skip gracefully)
- [ ] Symlink operations have proper fallback
- [ ] Line endings consistent across files
- [ ] No hardcoded Unix paths remain
- [ ] PowerShell and Command Prompt both work

## Notes

### Cross-Platform Libraries to Use
- **path**: Node.js built-in, always use instead of string concatenation
- **platform-folders**: Get platform-specific folder paths (Documents, AppData, etc.)
- **cross-spawn**: Cross-platform child process spawning
- **node-notifier**: Cross-platform desktop notifications
- **is-wsl**: Detect Windows Subsystem for Linux

### Windows-Specific Considerations

1. **Path Length Limit**: Windows has a 260 character path limit unless long paths are enabled
   - Prefix paths with `\\?\` for long paths: `\\?\C:\very\long\path`

2. **Case Sensitivity**: Windows paths are case-insensitive but case-preserving
   - Don't rely on case sensitivity for path comparisons

3. **Reserved Characters**: Windows reserves certain characters in filenames:
   - Avoid: `< > : " / \ | ? *`
   - Replace with safe alternatives

4. **Administrative Privileges**: Some operations may require elevated permissions
   - Symlink creation requires Developer Mode or Admin
   - File permissions may be restricted

5. **Drive Letters**: Windows uses drive letters (C:\, D:\, etc.)
   - Use environment variables for user paths (USERPROFILE)

### Testing Strategy

1. **Unit Tests**: Test each utility function in isolation
2. **Integration Tests**: Test hook execution end-to-end
3. **Platform Tests**: Test on Windows 10/11, macOS, and Linux
4. **Shell Tests**: Test on PowerShell, Command Prompt, Git Bash

### Dependencies

```json
{
  "devDependencies": {
    "cross-spawn": "^7.0.3",
    "node-notifier": "^10.0.1",
    "platform-folders": "^0.5.0",
    "is-wsl": "^2.2.0"
  }
}
```

### Related Work
- Hooks Group B adaptation (second half of hooks)
- Core PAI systems adaptation (INSTALL.ts, VoiceServer, Observability)
- PowerShell script creation for status line

### Breaking Changes
None expected - these are backward-compatible adaptations

### Rollback Plan
Keep original Mac/Linux versions in comments for reference. All changes use feature detection rather than platform detection where possible, ensuring fallback behavior.

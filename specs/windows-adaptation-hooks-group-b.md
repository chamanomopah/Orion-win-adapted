# Chore: Windows Compatibility - Hooks Group B

## Chore Description

Adapt the second half of PAI v2.5 hooks (19 files) from Mac/Linux to Windows. This group includes critical infrastructure like path utilities, trace emission, work coordination, and various event hooks that manage session state, tab titles, and learning capture.

**Scope**: Hooks Group B contains path handling utilities, trace emitters, work coordination systems, and session management hooks that heavily interact with the file system and external processes.

## Relevant Files

### Library Files (7)
- `.claude/hooks/lib/paths.ts` ⚠️ **CRITICAL** - Heavily path-dependent
- `.claude/hooks/lib/recovery-types.ts`
- `.claude/hooks/lib/response-format.ts`
- `.claude/hooks/lib/time.ts`
- `.claude/hooks/lib/TraceEmitter.ts` ⚠️ **CRITICAL** - Process/network operations
- `.claude/hooks/lib/work-utils.ts`
- `.claude/hooks/lib/observability.ts` (duplicate from Group A)

### Hook Files (11)
- `.claude/hooks/LoadContext.hook.ts`
- `.claude/hooks/QuestionAnswered.hook.ts`
- `.claude/hooks/README.md` (documentation only)
- `.claude/hooks/RelationshipMemory.hook.ts`
- `.claude/hooks/SecurityValidator.hook.ts`
- `.claude/hooks/SessionSummary.hook.ts`
- `.claude/hooks/SetQuestionTab.hook.ts`
- `.claude/hooks/SoulEvolution.hook.ts`
- `.claude/hooks/StartupGreeting.hook.ts`
- `.claude/hooks/StopOrchestrator.hook.ts`
- `.claude/hooks/UpdateTabTitle.hook.ts`
- `.claude/hooks/WorkCompletionLearning.hook.ts`
- `.claude/hooks/ImplicitSentimentCapture.hook.ts`

## Step by Step Tasks

### 1. Completely Rewrite lib/paths.ts
**File**: `.claude/hooks/lib/paths.ts` ⚠️ **HIGHEST PRIORITY**

**Issue**: This file likely contains hardcoded Unix paths and assumptions

**Current Implementation (Typical):**
```typescript
// Current (Unix-only)
export const CLAUDE_DIR = `${process.env.HOME}/.claude`;
export const MEMORY_DIR = `${process.env.HOME}/.claude/MEMORY`;
export const WORK_DIR = `${process.env.HOME}/.claude/WORK`;
```

**New Cross-Platform Implementation:**
```typescript
import * as path from 'path';
import * as os from 'os';

const PLATFORM = process.platform;
const HOME = PLATFORM === 'win32'
  ? process.env.USERPROFILE || os.homedir()
  : process.env.HOME || os.homedir();

const CLAUDE_ROOT = path.join(HOME, '.claude');

export const paths = {
  // Root directories
  CLAUDE_DIR: CLAUDE_ROOT,
  HOME_DIR: HOME,

  // Memory system
  MEMORY_DIR: path.join(CLAUDE_ROOT, 'MEMORY'),
  WORK_DIR: path.join(CLAUDE_ROOT, 'WORK'),
  STATE_DIR: path.join(CLAUDE_ROOT, 'STATE'),
  LEARNING_DIR: path.join(CLAUDE_ROOT, 'LEARNING'),

  // User data
  USER_DIR: path.join(CLAUDE_ROOT, 'USER'),
  PROJECTS_DIR: path.join(CLAUDE_ROOT, 'USER', 'PROJECTS'),
  TELOS_DIR: path.join(CLAUDE_ROOT, 'USER', 'TELOS'),

  // System
  SKILLS_DIR: path.join(CLAUDE_ROOT, 'skills'),
  HOOKS_DIR: path.join(CLAUDE_ROOT, 'hooks'),
  AGENTS_DIR: path.join(CLAUDE_ROOT, 'agents'),

  // Temp and cache
  TEMP_DIR: PLATFORM === 'win32'
    ? path.join(process.env.TEMP || 'C:\\Temp', 'claude')
    : path.join(os.tmpdir(), 'claude'),

  CACHE_DIR: path.join(CLAUDE_ROOT, 'cache'),
};

// Helper function to resolve paths
export function resolvePath(...segments: string[]): string {
  return path.resolve(...segments);
}

// Helper to check if path exists
export function pathExists(filePath: string): boolean {
  try {
    require('fs').existsSync(filePath);
    return true;
  } catch {
    return false;
  }
}
```

### 2. Fix TraceEmitter.ts
**File**: `.claude/hooks/lib/TraceEmitter.ts` ⚠️ **CRITICAL**

**Issues**:
- May spawn processes for trace collection
- Network operations for observability backend
- File writing for trace logs
- May use Unix-specific process monitoring

**Solution:**
```typescript
import * as fs from 'fs';
import * as path from 'path';
import { EventEmitter } from 'events';
import { PLATFORM, paths } from './paths';

interface TraceEvent {
  timestamp: Date;
  type: string;
  data: any;
}

export class TraceEmitter extends EventEmitter {
  private traceFile: string;
  private traceBuffer: TraceEvent[] = [];

  constructor() {
    super();
    // Use cross-platform path
    this.traceFile = path.join(paths.TEMP_DIR, 'trace.log');

    // Ensure directory exists (cross-platform)
    if (!fs.existsSync(path.dirname(this.traceFile))) {
      fs.mkdirSync(path.dirname(this.traceFile), { recursive: true });
    }
  }

  emitTrace(event: TraceEvent): void {
    this.traceBuffer.push(event);

    // Flush buffer periodically
    if (this.traceBuffer.length >= 100) {
      this.flush();
    }
  }

  flush(): void {
    if (this.traceBuffer.length === 0) return;

    try {
      // Append to trace file
      const content = this.traceBuffer
        .map(e => JSON.stringify(e))
        .join('\n') + '\n';

      fs.appendFileSync(this.traceFile, content, 'utf8');
      this.traceBuffer = [];
    } catch (error) {
      console.error('Failed to write trace:', error);
    }
  }

  // Cross-platform process monitoring
  monitorProcess(pid: number): void {
    if (PLATFORM === 'win32') {
      // Windows: use tasklist or PowerShell
      const { spawn } = require('child_process');
      spawn('tasklist', ['/FI', `PID eq ${pid}`]);
    } else {
      // Unix: use ps
      const { spawn } = require('child_process');
      spawn('ps', ['-p', pid.toString()]);
    }
  }
}
```

### 3. Adapt lib/time.ts
**File**: `.claude/hooks/lib/time.ts`

**Issue**: May use Unix-specific date commands or time zone handling

**Solution:**
```typescript
import { PLATFORM } from './paths';

// Cross-platform time utilities
export const timeUtils = {
  now(): Date {
    return new Date();
  },

  format(date: Date, format: string): string {
    // Use Intl.DateTimeFormat for cross-platform formatting
    return new Intl.DateTimeFormat(PLATFORM === 'win32' ? 'en-US' : 'en-US', {
      // Format options here
    }).format(date);
  },

  timestamp(): number {
    return Date.now();
  },

  // Cross-platform timezone handling
  getTimezone(): string {
    // Works on all platforms
    return Intl.DateTimeFormat().resolvedOptions().timeZone;
  }
};
```

### 4. Update lib/work-utils.ts
**File**: `.claude/hooks/lib/work-utils.ts`

**Issues**:
- Work file operations
- May spawn processes for work coordination
- File locking or synchronization

**Solution:**
```typescript
import * as fs from 'fs';
import * as path from 'path';
import { paths } from './paths';
import { PLATFORM } from './paths';

export function createWorkFile(workId: string, data: any): void {
  const workDir = paths.WORK_DIR;
  const workFile = path.join(workDir, `${workId}.json`);

  // Ensure directory exists (cross-platform mkdir -p)
  if (!fs.existsSync(workDir)) {
    fs.mkdirSync(workDir, { recursive: true });
  }

  // Write with proper error handling
  try {
    fs.writeFileSync(workFile, JSON.stringify(data, null, 2), 'utf8');
  } catch (error) {
    console.error(`Failed to create work file: ${error.message}`);
    throw error;
  }
}

export function lockWorkFile(workId: string): boolean {
  const lockFile = path.join(paths.WORK_DIR, `${workId}.lock`);

  try {
    // Use exclusive flag for cross-platform file locking
    const fd = fs.openSync(lockFile, 'wx');
    fs.writeSync(fd, new Date().toISOString());
    return true;
  } catch (error) {
    // File exists, already locked
    return false;
  }
}
```

### 5. Update Session Management Hooks
**Files**:
- SessionSummary.hook.ts
- LoadContext.hook.ts
- StartupGreeting.hook.ts

**Issues**:
- Session file operations
- Context loading from paths
- Greeting messages may use Unix-specific commands

**Solution:**
```typescript
import * as fs from 'fs';
import * as path from 'path';
import { paths } from './lib/paths';

export function loadSession(sessionId: string): any {
  const sessionFile = path.join(paths.STATE_DIR, 'sessions', `${sessionId}.json`);

  try {
    if (fs.existsSync(sessionFile)) {
      const content = fs.readFileSync(sessionFile, 'utf8');
      return JSON.parse(content);
    }
  } catch (error) {
    console.error(`Failed to load session: ${error.message}`);
  }

  return null;
}

export function saveSession(sessionId: string, data: any): void {
  const sessionDir = path.join(paths.STATE_DIR, 'sessions');
  const sessionFile = path.join(sessionDir, `${sessionId}.json`);

  // Ensure directory exists
  if (!fs.existsSync(sessionDir)) {
    fs.mkdirSync(sessionDir, { recursive: true });
  }

  try {
    fs.writeFileSync(sessionFile, JSON.stringify(data, null, 2), 'utf8');
  } catch (error) {
    console.error(`Failed to save session: ${error.message}`);
  }
}
```

### 6. Fix UpdateTabTitle.hook.ts
**File**: `.claude/hooks/UpdateTabTitle.hook.ts`

**Issue**: Uses Kitty terminal commands (see Group A)

**Solution:**
```typescript
import { PLATFORM } from './lib/paths';

export function updateTabTitle(title: string): void {
  if (PLATFORM === 'win32') {
    // Windows Terminal escape sequence
    process.stdout.write(`\x1b]0;${title}\x07`);
  } else if (process.env.TERM_PROGRAM === 'iTerm.app') {
    // iTerm2
    process.stdout.write(`\x1b]1337;SetUserData=value=${title}\x07`);
  } else if (process.env.TERM_PROGRAM === 'vscode') {
    // VS Code integrated terminal
    process.stdout.write(`\x1b]633;SetLabel=${title}\x07`);
  } else if (process.env.KITTY_WINDOW_ID) {
    // Kitty terminal
    const { spawnSync } = require('child_process');
    spawnSync('kitty', ['@', 'set-tab-title', title]);
  }
}
```

### 7. Update StopOrchestrator.hook.ts
**File**: `.claude/hooks/StopOrchestrator.hook.ts`

**Issue**: Process termination, signal handling

**Solution:**
```typescript
import { spawnSync } from 'child_process';
import { PLATFORM } from './lib/paths';

export function stopOrchestrator(orchestratorId: string): void {
  if (PLATFORM === 'win32') {
    // Windows: use taskkill
    spawnSync('taskkill', ['/F', '/PID', orchestratorId], {
      shell: true
    });
  } else {
    // Unix: use kill
    spawnSync('kill', ['-9', orchestratorId]);
  }
}

export function findProcessByName(name: string): number[] {
  let result: string;

  if (PLATFORM === 'win32') {
    // Windows PowerShell
    result = spawnSync('powershell', [
      '-Command',
      `Get-Process -Name "${name}" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id`
    ], { encoding: 'utf8' }).stdout;
  } else {
    // Unix: pgrep or ps
    result = spawnSync('pgrep', [name], { encoding: 'utf8' }).stdout;
  }

  return result
    .trim()
    .split('\n')
    .filter(Boolean)
    .map(Number);
}
```

### 8. Fix ImplicitSentimentCapture.hook.ts
**File**: `.claude/hooks/ImplicitSentimentCapture.hook.ts`

**Issues**:
- Learning file operations
- May use Unix text processing

**Solution:**
```typescript
import * as fs from 'fs';
import * as path from 'path';
import { paths } from './lib/paths';

export function captureSentiment(data: any): void {
  const learningFile = path.join(
    paths.LEARNING_DIR,
    'sentiment',
    `${Date.now()}.json`
  );

  const learningDir = path.dirname(learningFile);
  if (!fs.existsSync(learningDir)) {
    fs.mkdirSync(learningDir, { recursive: true });
  }

  try {
    fs.appendFileSync(
      learningFile,
      JSON.stringify(data) + '\n',
      'utf8'
    );
  } catch (error) {
    console.error('Failed to capture sentiment:', error);
  }
}
```

### 9. Update RelationshipMemory.hook.ts
**File**: `.claude/hooks/RelationshipMemory.hook.ts`

**Issues**:
- Relationship data file operations
- May use Unix-specific text processing

**Solution:**
```typescript
import * as fs from 'fs';
import * as path from 'path';
import { paths } from './lib/paths';

const RELATIONSHIP_FILE = path.join(paths.USER_DIR, 'relationships.json');

export function loadRelationships(): Map<string, any> {
  try {
    if (fs.existsSync(RELATIONSHIP_FILE)) {
      const content = fs.readFileSync(RELATIONSHIP_FILE, 'utf8');
      const data = JSON.parse(content);
      return new Map(Object.entries(data));
    }
  } catch (error) {
    console.error('Failed to load relationships:', error);
  }

  return new Map();
}

export function saveRelationships(relationships: Map<string, any>): void {
  try {
    const data = Object.fromEntries(relationships);
    fs.writeFileSync(
      RELATIONSHIP_FILE,
      JSON.stringify(data, null, 2),
      'utf8'
    );
  } catch (error) {
    console.error('Failed to save relationships:', error);
  }
}
```

### 10. Adapt Remaining Hooks
**Files**: SecurityValidator.hook.ts, SoulEvolution.hook.ts, WorkCompletionLearning.hook.ts

**Common Issues**:
- File operations with Unix paths
- Validation may check Unix permissions
- Learning capture with Unix-specific text processing

**General Solution Pattern:**
```typescript
import { paths } from './lib/paths';
import * as fs from 'fs';
import * as path from 'path';

// Always use paths from centralized path module
const configFile = path.join(paths.CLAUDE_DIR, 'config.json');

// Use fs with cross-platform options
fs.writeFileSync(file, content, { mode: 0o644 }); // Works on all platforms

// Ensure directories exist before writing
if (!fs.existsSync(dir)) {
  fs.mkdirSync(dir, { recursive: true });
}
```

## Validation Commands

### Windows Testing
```powershell
# 1. Test path resolution
cd C:\Users\JOSE\.claude
node -e "const p = require('./.claude/hooks/lib/paths.ts'); console.log(p.paths.CLAUDE_DIR)"

# 2. Test trace emitter
node -e "const TE = require('./.claude/hooks/lib/TraceEmitter.ts'); const t = new TE(); t.emitTrace({type: 'test', data: {}}); t.flush();"

# 3. Test work file creation
node -e "const w = require('./.claude/hooks/lib/work-utils.ts'); w.createWorkFile('test', {test: true});"

# 4. Test session operations
node -e "const s = require('./.claude/hooks/SessionSummary.hook.ts'); console.log('OK');"

# 5. Test tab title
node .claude/hooks/UpdateTabTitle.hook.ts

# 6. Verify all files load without errors
Get-ChildItem -Recurse .claude\hooks\*.ts | ForEach-Object { node $_.FullName }
```

### Cross-Platform Path Tests
```typescript
// Test file: test-paths.ts
import { paths } from './.claude/hooks/lib/paths';

console.log('Platform:', process.platform);
console.log('Claude Dir:', paths.CLAUDE_DIR);
console.log('Memory Dir:', paths.MEMORY_DIR);
console.log('Work Dir:', paths.WORK_DIR);

// Test path joining
const testPath = paths.resolvePath('user', 'projects', 'test.json');
console.log('Resolved Path:', testPath);
```

### Integration Tests
```powershell
# Run all hook tests
cd C:\Users\JOSE\Downloads\Orion\Personal_AI_Infrastructure-main\Releases\v2.5
npm test

# Test hooks in Claude Code context
claude . --hook-test
```

### Manual Testing Checklist
- [ ] All paths resolve correctly on Windows
- [ ] Trace emitter writes to temp directory
- [ ] Work files created in WORK_DIR
- [ ] Sessions load/save correctly
- [ ] Tab title updates in Windows Terminal
- [ ] Process termination works (taskkill)
- [ ] Relationship memory persists
- [ ] Learning data captured
- [ ] No Unix path separators remain
- [ ] All directories created with recursive option
- [ ] File operations handle Windows permissions

## Notes

### Critical Dependencies
- **lib/paths.ts** must be updated FIRST - all other files depend on it
- **lib/TraceEmitter.ts** affects observability and monitoring
- All hooks that write files must ensure directories exist

### Windows Path Limitations

1. **MAX_PATH (260 characters)**
   - Enable long paths in Windows 10/11:
     ```powershell
     # Enable long path support (requires Admin)
     New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
     ```

2. **Invalid Characters**
   - Avoid: `< > : " / \ | ? *`
   - Replace in filenames: `:` → `-`, `/` → `-`, `\` → `-`

3. **Reserved Names**
   - Avoid: CON, PRN, AUX, NUL, COM1-COM9, LPT1-LPT9

4. **Drive Letters**
   - Never hardcode drive letters (C:, D:)
   - Use environment variables: `USERPROFILE`, `TEMP`, `APPDATA`

### File System Differences

| Feature | Unix | Windows | Solution |
|---------|------|---------|----------|
| Path Separator | `/` | `\` | Use `path.join()` |
| Home Dir | `$HOME` | `%USERPROFILE%` | `os.homedir()` |
| Temp Dir | `/tmp` | `%TEMP%` | `os.tmpdir()` |
| Symlinks | Native | Limited (Admin) | Use junctions or copy |
| Permissions | chmod/chown | ACLs | Use Windows APIs or skip |
| Line Endings | `\n` | `\r\n` | Normalize to `\n` |
| Case Sensitive | Yes | No | Use case-insensitive compares |

### Performance Considerations

1. **File System Operations**
   - Use `fs.mkdirSync(dir, { recursive: true })` instead of multiple calls
   - Batch file writes to reduce I/O

2. **Process Spawning**
   - Reuse process handles where possible
   - Use `shell: true` on Windows for command resolution

3. **Path Operations**
   - Cache resolved paths
   - Use `path.join()` instead of string concatenation

### Testing Strategy

1. **Unit Tests**
   - Test each utility function independently
   - Mock file system operations

2. **Integration Tests**
   - Test hook execution end-to-end
   - Verify file operations complete

3. **Platform Tests**
   - Windows 10/11
   - Windows Server (if applicable)
   - WSL2 (test behavior in Linux subsystem)

4. **Shell Tests**
   - PowerShell (primary)
   - Command Prompt (legacy)
   - Git Bash (Unix emulation)

### Rollback Plan

Keep original implementations in comments:
```typescript
// ORIGINAL (Unix-only):
// export const CLAUDE_DIR = `${process.env.HOME}/.claude`;

// NEW (Cross-platform):
export const CLAUDE_DIR = path.join(HOME, '.claude');
```

### Related Work
- Hooks Group A adaptation (first half of hooks)
- Core PAI systems adaptation (INSTALL.ts, VoiceServer, Observability)
- Status line PowerShell script creation

### Breaking Changes
None - all changes are backward-compatible through platform detection

### Next Steps
1. Update lib/paths.ts first (all other files depend on it)
2. Test path resolution on Windows
3. Update each hook file sequentially
4. Test each change independently
5. Run full integration test suite

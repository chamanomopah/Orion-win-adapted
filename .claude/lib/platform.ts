/**
 * Cross-Platform Utilities for PAI v2.5
 *
 * Provides platform detection and platform-specific helpers
 * for Windows, macOS, and Linux.
 */

import * as os from 'os';
import * as path from 'path';

// ============================================================================
// PLATFORM DETECTION
// ============================================================================

export const PLATFORM = process.platform;
export const IS_WINDOWS = PLATFORM === 'win32';
export const IS_MAC = PLATFORM === 'darwin';
export const IS_LINUX = PLATFORM === 'linux';

// ============================================================================
// PATHS
// ============================================================================

export const HOME = IS_WINDOWS
  ? process.env.USERPROFILE || os.homedir()
  : process.env.HOME || os.homedir();

export const CLAUDE_DIR = path.join(HOME, '.claude');

export const DEFAULT_PROJECTS_DIR = path.join(HOME, 'Projects');

// ============================================================================
// PLATFORM-SPECIFIC PATHS
// ============================================================================

export function getHome(): string {
  return HOME;
}

export function getClaudeDir(): string {
  return CLAUDE_DIR;
}

export function getProjectsDir(projectsDir?: string): string {
  return projectsDir || DEFAULT_PROJECTS_DIR;
}

// ============================================================================
// COMMAND MAPPING
// ============================================================================

/**
 * Map Unix commands to Windows equivalents
 */
export function getCommand(command: string): string {
  const commandMap: Record<string, string> = {
    'ls': IS_WINDOWS ? 'dir' : 'ls',
    'cat': IS_WINDOWS ? 'type' : 'cat',
    'rm': IS_WINDOWS ? 'del' : 'rm',
    'cp': IS_WINDOWS ? 'copy' : 'cp',
    'mv': IS_WINDOWS ? 'move' : 'mv',
    'ps': IS_WINDOWS ? 'tasklist' : 'ps',
    'kill': IS_WINDOWS ? 'taskkill' : 'kill',
    'pwd': IS_WINDOWS ? 'cd' : 'pwd',
    'clear': IS_WINDOWS ? 'cls' : 'clear',
    'echo': 'echo', // Same on all platforms
    'mkdir': IS_WINDOWS ? 'mkdir' : 'mkdir', // Same but flags differ
    'rmdir': IS_WINDOWS ? 'rmdir' : 'rmdir',
  };

  return commandMap[command] || command;
}

/**
 * Get command arguments for platform
 */
export function getCommandArgs(command: string, args: string[]): string[] {
  if (IS_WINDOWS) {
    // Windows-specific argument adjustments
    if (command === 'mkdir' && !args.includes('/p')) {
      // Unix: mkdir -p → Windows: mkdir (already creates parents)
      return args.filter(arg => arg !== '-p');
    }
  }

  return args;
}

// ============================================================================
// SHELL CONFIGURATION
// ============================================================================

export interface ShellConfig {
  shell: string;
  profile: string;
  configCmd: string;
}

export function getShellConfig(): ShellConfig {
  if (IS_WINDOWS) {
    return {
      shell: 'powershell',
      profile: path.join(HOME, 'Documents', 'PowerShell', 'Microsoft.PowerShell_profile.ps1'),
      configCmd: 'pwsh',
    };
  } else if (IS_MAC) {
    return {
      shell: 'zsh',
      profile: path.join(HOME, '.zshrc'),
      configCmd: 'zsh',
    };
  } else {
    // Linux - try zsh first, fallback to bash
    const zshrc = path.join(HOME, '.zshrc');
    const hasZsh = require('fs').existsSync(zshrc);

    return {
      shell: hasZsh ? 'zsh' : 'bash',
      profile: hasZsh ? zshrc : path.join(HOME, '.bashrc'),
      configCmd: hasZsh ? 'zsh' : 'bash',
    };
  }
}

// ============================================================================
// FILE OPERATIONS
// ============================================================================

/**
 * Check if path is absolute
 */
export function isAbsolute(p: string): boolean {
  return path.isAbsolute(p);
}

/**
 * Normalize path for current platform
 */
export function normalizePath(p: string): string {
  return path.normalize(p);
}

/**
 * Join path segments
 */
export function joinPaths(...segments: string[]): string {
  return path.join(...segments);
}

// ============================================================================
// PERMISSIONS
// ============================================================================

/**
 * Set executable permission on file
 * (No-op on Windows, chmod +x on Unix)
 */
export function setExecutable(filePath: string): void {
  if (!IS_WINDOWS) {
    const { execSync } = require('child_process');
    try {
      execSync(`chmod +x "${filePath}"`, { stdio: 'pipe' });
    } catch (e) {
      // Ignore errors
    }
  }
}

/**
 * Set directory permissions
 */
export function setDirectoryPermissions(dirPath: string): void {
  if (IS_WINDOWS) {
    // Windows: Use icacls
    const { execSync } = require('child_process');
    const { userInfo } = require('os');
    const username = userInfo().username;

    try {
      execSync(`icacls "${dirPath}" /grant "${username}:(OI)(CI)F" /T`, {
        stdio: 'pipe',
        shell: true,
      });
    } catch (e) {
      // Ignore errors - default permissions usually OK
    }
  } else {
    // Unix: chmod + chown
    const { execSync } = require('child_process');
    const { userInfo } = require('os');
    const info = userInfo();

    try {
      execSync(`chmod -R 755 "${dirPath}"`, { stdio: 'pipe' });
      execSync(`chown -R ${info.uid}:${info.gid} "${dirPath}"`, { stdio: 'pipe' });
    } catch (e) {
      // Ignore errors
    }
  }
}

// ============================================================================
// PROCESS MANAGEMENT
// ============================================================================

/**
 * Find process using port
 */
export function findProcessOnPort(port: number): number[] {
  const { execSync } = require('child_process');

  try {
    if (IS_WINDOWS) {
      const result = execSync(`netstat -ano | findstr :${port}`, {
        encoding: 'utf-8',
        stdio: ['pipe', 'pipe', 'pipe'],
      });

      const pids: number[] = [];
      const lines = result.trim().split('\n');

      for (const line of lines) {
        const parts = line.trim().split(/\s+/);
        const pid = parseInt(parts[parts.length - 1]);
        if (!isNaN(pid)) {
          pids.push(pid);
        }
      }

      return [...new Set(pids)]; // Unique PIDs
    } else {
      const result = execSync(`lsof -ti:${port}`, {
        encoding: 'utf-8',
        stdio: ['pipe', 'pipe', 'pipe'],
      });

      return result
        .trim()
        .split('\n')
        .map((s: string) => parseInt(s.trim()))
        .filter((n: number) => !isNaN(n));
    }
  } catch (e) {
    return [];
  }
}

/**
 * Kill process by PID
 */
export function killProcess(pid: number): boolean {
  const { execSync } = require('child_process');

  try {
    if (IS_WINDOWS) {
      execSync(`taskkill /F /PID ${pid}`, { stdio: 'pipe' });
    } else {
      execSync(`kill -9 ${pid}`, { stdio: 'pipe' });
    }
    return true;
  } catch (e) {
    return false;
  }
}

// ============================================================================
// AUDIO PLAYBACK
// ============================================================================

export interface AudioConfig {
  platform: string;
  player: string;
  volumeScale: number;
}

export function getAudioConfig(): AudioConfig {
  if (IS_WINDOWS) {
    return {
      platform: 'windows',
      player: 'powershell',
      volumeScale: 1.0, // 0.0 to 1.0
    };
  } else if (IS_MAC) {
    return {
      platform: 'macos',
      player: 'afplay',
      volumeScale: 1.0, // 0.0 to 1.0
    };
  } else {
    return {
      platform: 'linux',
      player: 'paplay', // or aplay
      volumeScale: 65536, // 0 to 65536
    };
  }
}

// ============================================================================
// LOGGING
// ============================================================================

/**
 * Get log directory for platform
 */
export function getLogDir(appName: string = 'PAI'): string {
  if (IS_WINDOWS) {
    return path.join(HOME, 'AppData', 'Local', appName, 'logs');
  } else if (IS_MAC) {
    return path.join(HOME, 'Library', 'Logs', appName);
  } else {
    // Linux
    const xdgDataHome = process.env.XDG_DATA_HOME || path.join(HOME, '.local', 'share');
    return path.join(xdgDataHome, appName, 'logs');
  }
}

// ============================================================================
// ENVIRONMENT
// ============================================================================

/**
 * Get PATH environment variable delimiter
 */
export function getPathDelimiter(): string {
  return IS_WINDOWS ? ';' : ':';
}

/**
 * Add to PATH
 */
export function addToPath(dirToAdd: string): void {
  const delimiter = getPathDelimiter();
  const pathEnv = process.env.PATH || '';

  if (!pathEnv.includes(dirToAdd)) {
    process.env.PATH = `${dirToAdd}${delimiter}${pathEnv}`;
  }
}

// ============================================================================
// TROUBLESHOOTING HELPERS
// ============================================================================

/**
 * Get platform-specific troubleshooting info
 */
export function getTroubleshootingInfo(): string {
  if (IS_WINDOWS) {
    return `
Windows Troubleshooting:
- Run PowerShell as Administrator for permission issues
- Enable Long Paths: New-ItemProperty -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
- Set Execution Policy: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
- Check PATH: echo $env:PATH
`;
  } else if (IS_MAC) {
    return `
macOS Troubleshooting:
- Install Xcode Command Line Tools: xcode-select --install
- Fix permissions: sudo chown -R $(whoami) ~/.claude
- Check shell: echo $SHELL
`;
  } else {
    return `
Linux Troubleshooting:
- Fix permissions: sudo chown -R $(whoami) ~/.claude
- Check dependencies: python3, node, git
- Install missing packages via your package manager (apt, yum, dnf, etc.)
`;
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

export default {
  PLATFORM,
  IS_WINDOWS,
  IS_MAC,
  IS_LINUX,
  HOME,
  CLAUDE_DIR,
  DEFAULT_PROJECTS_DIR,
  getHome,
  getClaudeDir,
  getProjectsDir,
  getCommand,
  getCommandArgs,
  getShellConfig,
  isAbsolute,
  normalizePath,
  joinPaths,
  setExecutable,
  setDirectoryPermissions,
  findProcessOnPort,
  killProcess,
  getAudioConfig,
  getLogDir,
  getPathDelimiter,
  addToPath,
  getTroubleshootingInfo,
};

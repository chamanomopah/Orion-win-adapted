/**
 * Cross-Platform Path Utilities
 *
 * Provides platform-aware path handling for Windows, macOS, and Linux.
 * All hooks should import from this file instead of using process.env.HOME directly.
 */

import * as path from 'path';
import * as os from 'os';

export const PLATFORM = process.platform;

/**
 * Get the home directory in a cross-platform way.
 * Windows: USERPROFILE environment variable
 * macOS/Linux: HOME environment variable
 */
export const HOME_DIR = PLATFORM === 'win32'
  ? process.env.USERPROFILE || os.homedir()
  : process.env.HOME || os.homedir();

/**
 * Get the PAI directory (root of the Claude/PAI system)
 * Uses PAI_DIR env var if set, otherwise defaults to ~/.claude
 */
export const PAI_DIR = process.env.PAI_DIR || path.join(HOME_DIR, '.claude');

/**
 * Get the Claude directory (alias for PAI_DIR for compatibility)
 */
export const CLAUDE_DIR = PAI_DIR;

/**
 * Platform-specific path separator
 */
export const PATH_SEPARATOR = path.sep;

/**
 * Join path segments using the platform-appropriate separator
 */
export function joinPath(...segments: string[]): string {
  return path.join(...segments);
}

/**
 * Normalize a path to use the platform-appropriate separator
 * Converts forward slashes to backslashes on Windows
 */
export function normalizePath(filePath: string): string {
  return path.normalize(filePath.replace(/\//g, path.sep));
}

/**
 * Get the temp directory in a cross-platform way
 */
export const TEMP_DIR = PLATFORM === 'win32'
  ? process.env.TEMP || process.env.TMP || os.tmpdir()
  : os.tmpdir();

/**
 * Get the session start file path for timing
 * Windows: %TEMP%\pai-session-start.txt
 * macOS/Linux: /tmp/pai-session-start.txt
 */
export const SESSION_START_FILE = PLATFORM === 'win32'
  ? path.join(TEMP_DIR, 'pai-session-start.txt')
  : '/tmp/pai-session-start.txt';

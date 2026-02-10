"""Cross-platform audio playback for VoiceServer."""

import asyncio
import subprocess
import platform
import sys
from pathlib import Path
from typing import Optional
import logging

logger = logging.getLogger(__name__)

# Detect platform
IS_WINDOWS = platform.system() == "Windows"
IS_MAC = platform.system() == "Darwin"
IS_LINUX = platform.system() == "Linux"


async def play_audio(
    audio_path: Path | str,
    volume: float = 0.8,
    delete_after: bool = True
) -> bool:
    """
    Play audio file using platform-specific audio player.

    Supports:
    - Windows: PowerShell SoundPlayer
    - macOS: afplay
    - Linux: paplay (PulseAudio) or aplay (ALSA)

    Args:
        audio_path: Path to the audio file
        volume: Playback volume (0.0 to 1.0)
        delete_after: Whether to delete the file after playing

    Returns:
        True if playback succeeded, False otherwise
    """
    audio_path = Path(audio_path)

    if not audio_path.exists():
        logger.error(f"Audio file not found: {audio_path}")
        return False

    try:
        if IS_WINDOWS:
            return await _play_windows(audio_path, volume)
        elif IS_MAC:
            return await _play_macos(audio_path, volume)
        elif IS_LINUX:
            return await _play_linux(audio_path, volume)
        else:
            logger.error(f"Unsupported platform: {platform.system()}")
            return False
    except Exception as e:
        logger.error(f"Audio playback error: {e}")
        return False
    finally:
        # Clean up temp file if requested
        if delete_after and audio_path.exists():
            try:
                audio_path.unlink()
                logger.debug(f"Deleted temp audio: {audio_path}")
            except Exception as e:
                logger.warning(f"Failed to delete temp audio: {e}")


async def _play_windows(audio_path: Path, volume: float) -> bool:
    """Play audio on Windows using PowerShell SoundPlayer."""
    try:
        # Windows: Use PowerShell with Media.SoundPlayer
        # Note: volume control is limited with SoundPlayer
        cmd = [
            "powershell",
            "-Command",
            f"(New-Object Media.SoundPlayer '{audio_path}').PlaySync()"
        ]

        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.PIPE
        )

        _, stderr = await process.communicate()

        if process.returncode != 0:
            logger.error(f"Windows audio playback failed: {stderr.decode()}")
            return False

        logger.info(f"Played audio on Windows: {audio_path}")
        return True

    except Exception as e:
        logger.error(f"Windows audio playback error: {e}")
        return False


async def _play_macos(audio_path: Path, volume: float) -> bool:
    """Play audio on macOS using afplay."""
    try:
        # afplay uses 0.0-1.0 volume scale
        process = await asyncio.create_subprocess_exec(
            "afplay",
            "-v", str(min(1.0, max(0.0, volume))),
            str(audio_path),
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.PIPE
        )

        _, stderr = await process.communicate()

        if process.returncode != 0:
            logger.error(f"afplay failed: {stderr.decode()}")
            return False

        logger.info(f"Played audio on macOS: {audio_path}")
        return True

    except FileNotFoundError:
        logger.error("afplay not found - is this macOS?")
        return False
    except Exception as e:
        logger.error(f"macOS audio playback error: {e}")
        return False


async def _play_linux(audio_path: Path, volume: float) -> bool:
    """Play audio on Linux using paplay or aplay."""
    # Try paplay (PulseAudio) first, then aplay (ALSA)
    for player, args in [
        ("paplay", ["--volume", str(int(volume * 65536))]),  # paplay uses 0-65536
        ("aplay", [])  # aplay doesn't support volume control
    ]:
        try:
            cmd = [player, str(audio_path)] + args
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.PIPE
            )

            _, stderr = await process.communicate()

            if process.returncode == 0:
                logger.info(f"Played audio on Linux using {player}: {audio_path}")
                return True
            else:
                logger.debug(f"{player} failed: {stderr.decode()}, trying next...")

        except FileNotFoundError:
            logger.debug(f"{player} not found, trying next...")
            continue
        except Exception as e:
            logger.debug(f"{player} error: {e}, trying next...")
            continue

    logger.error("No working audio player found on Linux (tried paplay, aplay)")
    return False


def play_audio_sync(
    audio_path: Path | str,
    volume: float = 0.8,
    delete_after: bool = True
) -> bool:
    """Synchronous version of play_audio."""
    audio_path = Path(audio_path)

    if not audio_path.exists():
        logger.error(f"Audio file not found: {audio_path}")
        return False

    try:
        if IS_WINDOWS:
            return _play_windows_sync(audio_path, volume)
        elif IS_MAC:
            return _play_macos_sync(audio_path, volume)
        elif IS_LINUX:
            return _play_linux_sync(audio_path, volume)
        else:
            logger.error(f"Unsupported platform: {platform.system()}")
            return False
    except Exception as e:
        logger.error(f"Audio playback error: {e}")
        return False
    finally:
        if delete_after and audio_path.exists():
            try:
                audio_path.unlink()
            except Exception:
                pass


def _play_windows_sync(audio_path: Path, volume: float) -> bool:
    """Synchronous Windows audio playback."""
    try:
        result = subprocess.run(
            ["powershell", "-Command",
             f"(New-Object Media.SoundPlayer '{audio_path}').PlaySync()"],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            logger.error(f"Windows audio playback failed: {result.stderr}")
            return False

        return True
    except Exception as e:
        logger.error(f"Windows audio playback error: {e}")
        return False


def _play_macos_sync(audio_path: Path, volume: float) -> bool:
    """Synchronous macOS audio playback."""
    try:
        result = subprocess.run(
            ["afplay", "-v", str(volume), str(audio_path)],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            logger.error(f"afplay failed: {result.stderr}")
            return False

        return True
    except FileNotFoundError:
        logger.error("afplay not found - is this macOS?")
        return False
    except Exception as e:
        logger.error(f"macOS audio playback error: {e}")
        return False


def _play_linux_sync(audio_path: Path, volume: float) -> bool:
    """Synchronous Linux audio playback."""
    for player, args in [
        ("paplay", ["--volume", str(int(volume * 65536))]),
        ("aplay", [])
    ]:
        try:
            cmd = [player, str(audio_path)] + args
            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode == 0:
                return True
        except FileNotFoundError:
            continue
        except Exception:
            continue

    logger.error("No working audio player found on Linux")
    return False

#!/usr/bin/env python3
"""log rotation utility for nighty-linux-headless.

Rotates log files in diagnostics/ and NIGHTY_HOME when they exceed a configurable
size threshold, keeping a bounded number of rotated backups.
"""

from __future__ import annotations

import glob
import os
from pathlib import Path
import sys


def rotate_log_file(log_path: Path, max_bytes: int = 10 * 1024 * 1024, max_backups: int = 3) -> bool:
    """Rotate a log file if its size exceeds max_bytes.

    Returns True if the log was rotated, False otherwise.
    """
    if not log_path.is_file():
        return False

    try:
        size = log_path.stat().st_size
    except OSError:
        return False

    if size < max_bytes:
        return False

    # Shift existing backups (.2 -> .3, .1 -> .2, etc.)
    for i in range(max_backups - 1, 0, -1):
        src = log_path.with_name(f"{log_path.name}.{i}")
        dst = log_path.with_name(f"{log_path.name}.{i + 1}")
        if src.is_file():
            try:
                if dst.is_file():
                    dst.unlink()
                src.rename(dst)
            except OSError:
                pass

    # Move primary log to .1
    target = log_path.with_name(f"{log_path.name}.1")
    try:
        if target.is_file():
            target.unlink()
        log_path.rename(target)
        # Re-create empty log file
        log_path.touch(mode=0o644, exist_ok=True)
        return True
    except OSError as e:
        # Fallback: if rename fails (e.g. file is open), truncate in place keeping tail
        try:
            with open(log_path, "r+", encoding="utf-8", errors="replace") as f:
                content = f.read()
                tail_bytes = content[-512 * 1024 :] if len(content) > 512 * 1024 else ""
                f.seek(0)
                f.write(f"[LOG ROTATED - Previous size: {size} bytes]\n" + tail_bytes)
                f.truncate()
            return True
        except OSError:
            print(f"[rotate_logs] Warning: Failed to rotate {log_path}: {e}", file=sys.stderr)
            return False


def find_appdata_logs() -> list[Path]:
    logs = []
    prefix = os.environ.get("WINEPREFIX") or os.path.expanduser("~/.local/share/nighty/prefix")
    pattern = os.path.join(prefix, "drive_c", "users", "*", "AppData", "Roaming", "Nighty Selfbot", "nighty.log")
    for match in glob.glob(pattern):
        p = Path(match)
        if p.is_file():
            logs.append(p)
    return logs


def main() -> int:
    max_mb = float(os.environ.get("MAX_LOG_MB", "10"))
    max_bytes = int(max_mb * 1024 * 1024)
    max_backups = int(os.environ.get("MAX_LOG_BACKUPS", "3"))

    here_dir = Path(__file__).resolve().parents[1]
    diag_dir_env = os.environ.get("NIGHTY_DIAG_DIR")
    diag_path = Path(diag_dir_env) if diag_dir_env else (here_dir / "diagnostics")

    nighty_home = os.environ.get("NIGHTY_HOME") or os.path.expanduser("~/.local/share/nighty")
    home_path = Path(nighty_home)

    if len(sys.argv) > 1:
        targets = [Path(p) for p in sys.argv[1:]]
    else:
        log_names = ["backend.log", "bridge.log", "guard.log", "xvfb.log", "stub_webview.log", "nighty.log"]
        targets = []
        for name in log_names:
            p_diag = diag_path / name
            if p_diag.is_file():
                targets.append(p_diag)
            p_home = home_path / name
            if p_home.is_file() and p_home != p_diag:
                targets.append(p_home)
        # Also check AppData nighty.log
        for app_log in find_appdata_logs():
            if app_log not in targets:
                targets.append(app_log)

    rotated_any = False
    for target in targets:
        if rotate_log_file(target, max_bytes=max_bytes, max_backups=max_backups):
            print(f"[rotate_logs] Rotated {target.name} (exceeded {max_mb} MB)")
            rotated_any = True

    return 0 if rotated_any else 0


if __name__ == "__main__":
    sys.exit(main())

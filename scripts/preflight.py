#!/usr/bin/env python3
"""Small, side-effect-free startup/install checks for Nighty headless."""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import os
from pathlib import Path
import shutil
import struct
import sys
from typing import List, Optional, Tuple


PE_MACHINES = {
    0x014C: "i386 (32-bit)",
    0x8664: "x86-64 (64-bit)",
    0xAA64: "ARM64",
}

WINE_NATIVE_LIBS = (
    ("X11", "libx11-6", True),
    ("Xext", "libxext6", True),
    ("Xrender", "libxrender1", True),
    ("Xfixes", "libxfixes3", True),
    ("Xrandr", "libxrandr2", True),
    ("Xcomposite", "libxcomposite1", True),
    ("Xi", "libxi6", True),
    ("Xcursor", "libxcursor1", True),
    ("Xinerama", "libxinerama1", True),
    # Qt may probe this helper, but the existing RPi5 deployment is healthy
    # without it. Keep it visible in diagnostics without blocking upgrades.
    ("xkbregistry", "libxkbregistry0", False),
)


class PreflightError(RuntimeError):
    pass


def pe_machine(path: Path) -> int:
    try:
        with path.open("rb") as fh:
            header = fh.read(64)
            if len(header) < 64 or header[:2] != b"MZ":
                raise PreflightError("not a Windows PE executable (missing MZ header)")
            pe_offset = struct.unpack_from("<I", header, 0x3C)[0]
            if pe_offset < 64 or pe_offset > path.stat().st_size - 6:
                raise PreflightError("invalid PE header offset")
            fh.seek(pe_offset)
            pe = fh.read(6)
    except OSError as exc:
        raise PreflightError(f"cannot read file: {exc}") from exc
    if len(pe) != 6 or pe[:4] != b"PE\0\0":
        raise PreflightError("invalid PE signature")
    return struct.unpack_from("<H", pe, 4)[0]


def check_pe(path: Path, require_x64: bool) -> int:
    if not path.is_file():
        print(f"[preflight] ERROR: executable not found: {path}", file=sys.stderr)
        return 2
    try:
        machine = pe_machine(path)
    except PreflightError as exc:
        print(f"[preflight] ERROR: {path}: {exc}", file=sys.stderr)
        return 2
    label = PE_MACHINES.get(machine, f"unknown machine 0x{machine:04x}")
    if require_x64 and machine != 0x8664:
        print(
            f"[preflight] ERROR: {path.name} is {label}; ARM/Box64 requires an x86-64 PE32+ build.",
            file=sys.stderr,
        )
        return 3
    if machine not in (0x014C, 0x8664):
        print(f"[preflight] ERROR: unsupported executable architecture: {label}", file=sys.stderr)
        return 3
    print(f"[preflight] {path.name}: {label}")
    return 0


def missing_native_libs() -> List[Tuple[str, str, bool]]:
    missing: List[Tuple[str, str, bool]] = []
    for library, package, required in WINE_NATIVE_LIBS:
        candidate = ctypes.util.find_library(library)
        if not candidate:
            missing.append((library, package, required))
            continue
        try:
            ctypes.CDLL(candidate)
        except OSError:
            missing.append((library, package, required))
    return missing


def check_libs(quiet: bool) -> int:
    missing = missing_native_libs()
    if not missing:
        if not quiet:
            print("[preflight] native Wine/X11 libraries: OK")
        return 0
    required_missing = [item for item in missing if item[2]]
    optional_missing = [item for item in missing if not item[2]]
    if required_missing and not quiet:
        print("[preflight] missing native libraries required by Wine/Box64:", file=sys.stderr)
        for library, package, _required in required_missing:
            print(f"  {library} (Debian package: {package})", file=sys.stderr)
    if optional_missing and not quiet:
        print("[preflight] optional native libraries not present (startup may still work):", file=sys.stderr)
        for library, package, _required in optional_missing:
            print(f"  {library} (Debian package: {package})", file=sys.stderr)
    return 4 if required_missing else 0


def resolve_command(value: str) -> Optional[Path]:
    if os.sep in value or (os.altsep and os.altsep in value):
        return Path(value).expanduser()
    resolved = shutil.which(value)
    return Path(resolved) if resolved else None


def check_wine(value: str) -> int:
    path = resolve_command(value)
    if path is None or not path.is_file():
        print(f"[preflight] ERROR: WINE_BIN does not resolve to a file: {value}", file=sys.stderr)
        return 5
    if not os.access(path, os.X_OK):
        print(f"[preflight] ERROR: WINE_BIN is not executable: {path}", file=sys.stderr)
        return 5
    try:
        with path.open("rb") as fh:
            magic = fh.read(2)
    except OSError as exc:
        print(f"[preflight] ERROR: cannot read WINE_BIN {path}: {exc}", file=sys.stderr)
        return 5
    kind = "launcher script" if magic == b"#!" else "executable"
    print(f"[preflight] WINE_BIN: {path} ({kind})")
    return 0


import socket
import ssl
import urllib.error
import urllib.request


def check_network(quiet: bool = False) -> int:
    """Run comprehensive network diagnostics (DNS, TLS, HTTP/Cloudflare, TCP ports)."""
    results: List[Tuple[str, str, bool]] = []
    has_error = False

    # 1. DNS Resolution checks
    domains = [
        "discord.com",
        "gateway.discord.gg",
        "cdn.discordapp.com",
        "lrclib.net",
        "api.spotify.com",
    ]
    if not quiet:
        print("[diag] Checking DNS resolution...")
    for domain in domains:
        try:
            ip = socket.gethostbyname(domain)
            results.append(("DNS " + domain, f"Resolved to {ip}", True))
        except socket.gaierror as e:
            results.append(("DNS " + domain, f"FAILED ({e})", False))
            has_error = True

    # 2. HTTPS / TLS Handshake to Discord API
    if not quiet:
        print("[diag] Checking HTTPS/TLS connectivity to Discord API...")
    url = "https://discord.com/api/v10/gateway"
    req = urllib.request.Request(url, headers={"User-Agent": "NightyHeadlessDiag/1.0"})
    try:
        ctx = ssl.create_default_context()
        with urllib.request.urlopen(req, timeout=10, context=ctx) as resp:
            results.append(("TLS discord.com", f"HTTP {resp.status} OK", True))
    except urllib.error.HTTPError as e:
        if e.code == 403:
            results.append(("TLS discord.com", f"HTTP 403 Forbidden (Possible Cloudflare / Anti-Bot block)", False))
            has_error = True
        else:
            results.append(("TLS discord.com", f"HTTP {e.code} ({e.reason})", True))
    except (urllib.error.URLError, ssl.SSLError, OSError) as e:
        results.append(("TLS discord.com", f"FAILED ({e})", False))
        has_error = True

    # 3. Port binding checks (8088 bridge, 8090 webui, 8765 stub)
    ports = [
        (8088, "Bridge LAN"),
        (8090, "Web UI Native"),
        (8765, "Stub CTL"),
    ]
    if not quiet:
        print("[diag] Checking local port status...")
    for port, label in ports:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(0.5)
            is_open = s.connect_ex(("127.0.0.1", port)) == 0
            status_str = "BOUND (Listening)" if is_open else "CLOSED (Available)"
            results.append((f"Port :{port} ({label})", status_str, True))

    # Print summary
    if not quiet:
        print("\n=== NETWORK DIAGNOSTICS SUMMARY ===")
        for test_name, detail, ok in results:
            status = "OK" if ok else "FAIL"
            print(f"  [{status}] {test_name:<30}: {detail}")
        print("===================================\n")

    return 1 if has_error else 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    pe = sub.add_parser("pe", help="validate a Windows PE executable")
    pe.add_argument("path", type=Path)
    pe.add_argument("--require-x64", action="store_true")
    libs = sub.add_parser("libs", help="check native Wine/X11 runtime libraries")
    libs.add_argument("--quiet", action="store_true")
    wine = sub.add_parser("wine", help="validate WINE_BIN")
    wine.add_argument("path")
    diag = sub.add_parser("diag", help="run network and environment diagnostics")
    diag.add_argument("--quiet", action="store_true")
    return parser


def main(argv: Optional[List[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "pe":
        return check_pe(args.path, args.require_x64)
    if args.command == "libs":
        return check_libs(args.quiet)
    if args.command == "wine":
        return check_wine(args.path)
    if args.command == "diag":
        return check_network(args.quiet)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())


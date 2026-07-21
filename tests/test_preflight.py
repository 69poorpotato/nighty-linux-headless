from __future__ import annotations

import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("nighty_preflight", ROOT / "scripts" / "preflight.py")
assert SPEC and SPEC.loader
PREFLIGHT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PREFLIGHT)


def write_pe(path: Path, machine: int) -> None:
    data = bytearray(128)
    data[:2] = b"MZ"
    struct.pack_into("<I", data, 0x3C, 64)
    data[64:68] = b"PE\0\0"
    struct.pack_into("<H", data, 68, machine)
    path.write_bytes(data)


class PeValidationTests(unittest.TestCase):
    def test_x64_is_accepted_for_arm_box64(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            exe = Path(tmp) / "Nighty.exe"
            write_pe(exe, 0x8664)
            self.assertEqual(PREFLIGHT.check_pe(exe, require_x64=True), 0)

    def test_i386_is_rejected_for_arm_box64(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            exe = Path(tmp) / "Nighty.exe"
            write_pe(exe, 0x014C)
            self.assertEqual(PREFLIGHT.check_pe(exe, require_x64=True), 3)

    def test_i386_remains_accepted_on_native_x86_for_compatibility(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            exe = Path(tmp) / "Nighty.exe"
            write_pe(exe, 0x014C)
            self.assertEqual(PREFLIGHT.check_pe(exe, require_x64=False), 0)

    def test_invalid_file_is_rejected_before_repack(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            exe = Path(tmp) / "Nighty.exe"
            exe.write_bytes(b"not a PE")
            self.assertEqual(PREFLIGHT.check_pe(exe, require_x64=True), 2)

    def test_unknown_machine_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            exe = Path(tmp) / "Nighty.exe"
            write_pe(exe, 0x1234)
            self.assertEqual(PREFLIGHT.check_pe(exe, require_x64=False), 3)


if __name__ == "__main__":
    unittest.main()

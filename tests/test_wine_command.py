import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which("bash")
LAUNCHER = ROOT / "scripts" / "wine_command.sh"


@unittest.skipIf(BASH is None or os.name == "nt", "requires a POSIX bash environment")
class WineCommandTests(unittest.TestCase):
    def make_executable(self, path: Path) -> None:
        path.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        path.chmod(0o755)

    def run_configure(
        self, arch: str, include_box64: bool = True, include_binfmt: bool = False
    ) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as tmp:
            bindir = Path(tmp)
            wine = bindir / "wine64"
            self.make_executable(wine)
            self.make_executable(bindir / "wineserver")
            if include_box64:
                self.make_executable(bindir / "box64")
            binfmt = bindir / "binfmt"
            binfmt.mkdir()
            if include_binfmt:
                (binfmt / "box64").write_text(
                    f"enabled\ninterpreter {bindir / 'box64'}\n", encoding="utf-8"
                )
            command = (
                f'source "{LAUNCHER}"; '
                f'nighty_configure_wine_command "{wine}" "{arch}"; '
                "printf '%s\\n' \"${NIGHTY_WINE_COMMAND[*]}\""
            )
            env = os.environ.copy()
            env["PATH"] = f"{bindir}{os.pathsep}{env.get('PATH', '')}"
            env["NIGHTY_BINFMT_ROOT"] = str(binfmt)
            return subprocess.run(
                [BASH, "-c", command], capture_output=True, text=True, env=env, check=False
            )

    def test_amd64_executes_wine_directly(self) -> None:
        result = self.run_configure("x86_64")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("box64", result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("wine64"))

    def test_arm64_executes_wine_through_box64_without_binfmt(self) -> None:
        result = self.run_configure("aarch64")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(result.stdout.rstrip(), r"box64 .*/wine64$")

    def test_arm64_uses_direct_wine_with_working_box64_binfmt(self) -> None:
        result = self.run_configure("aarch64", include_binfmt=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("box64 ", result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("wine64"))


if __name__ == "__main__":
    unittest.main()

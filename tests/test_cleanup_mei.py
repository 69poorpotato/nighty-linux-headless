import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "cleanup_mei.sh"
BASH = shutil.which("bash")


@unittest.skipIf(BASH is None or os.name == "nt", "requires a POSIX bash environment")
class CleanupMeiTests(unittest.TestCase):
    def run_cleanup(self, prefix: Path, *args: str) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["WINEPREFIX"] = str(prefix)
        return subprocess.run(
            [BASH, str(SCRIPT), *args],
            text=True,
            capture_output=True,
            env=env,
            check=False,
        )

    @staticmethod
    def make_temp(prefix: Path) -> Path:
        temp = prefix / "drive_c" / "users" / "pi" / "AppData" / "Local" / "Temp"
        temp.mkdir(parents=True)
        return temp

    def test_dry_run_lists_but_does_not_remove(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            prefix = Path(tmp) / "prefix"
            mei = self.make_temp(prefix) / "_MEI12345"
            mei.mkdir()

            result = self.run_cleanup(prefix, "--dry-run")

            self.assertEqual(result.returncode, 0)
            self.assertTrue(mei.is_dir())
            self.assertIn("would remove", result.stdout)

    def test_removes_only_direct_mei_directories(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            prefix = Path(tmp) / "prefix"
            temp = self.make_temp(prefix)
            stale = temp / "_MEIabc"
            keep = temp / "ordinary-cache"
            nested = keep / "_MEInested"
            stale.mkdir()
            keep.mkdir()
            nested.mkdir()

            result = self.run_cleanup(prefix)

            self.assertEqual(result.returncode, 0)
            self.assertFalse(stale.exists())
            self.assertTrue(keep.is_dir())
            self.assertTrue(nested.is_dir())

    def test_does_not_follow_mei_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            prefix = Path(tmp) / "prefix"
            temp = self.make_temp(prefix)
            outside = Path(tmp) / "outside"
            outside.mkdir()
            link = temp / "_MEI-link"
            link.symlink_to(outside, target_is_directory=True)

            result = self.run_cleanup(prefix)

            self.assertEqual(result.returncode, 0)
            self.assertTrue(outside.is_dir())
            self.assertTrue(link.is_symlink())

    def test_rejects_broad_prefix(self) -> None:
        result = self.run_cleanup(Path("/"))

        self.assertEqual(result.returncode, 2)
        self.assertIn("refusing unsafe WINEPREFIX", result.stderr)


if __name__ == "__main__":
    unittest.main()

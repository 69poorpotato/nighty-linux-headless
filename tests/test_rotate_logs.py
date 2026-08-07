import tempfile
import unittest
from pathlib import Path

from scripts import rotate_logs


class RotateLogsTests(unittest.TestCase):
    def test_log_below_limit_is_not_rotated(self):
        with tempfile.TemporaryDirectory() as tmp:
            log_file = Path(tmp) / "backend.log"
            log_file.write_text("small log content\n", encoding="utf-8")
            rotated = rotate_logs.rotate_log_file(log_file, max_bytes=1024, max_backups=3)
            self.assertFalse(rotated)
            self.assertTrue(log_file.is_file())
            self.assertEqual(log_file.read_text(encoding="utf-8"), "small log content\n")
            self.assertFalse((Path(tmp) / "backend.log.1").exists())

    def test_log_above_limit_is_rotated(self):
        with tempfile.TemporaryDirectory() as tmp:
            log_file = Path(tmp) / "backend.log"
            log_file.write_text("x" * 2000, encoding="utf-8")
            rotated = rotate_logs.rotate_log_file(log_file, max_bytes=1000, max_backups=3)
            self.assertTrue(rotated)
            self.assertTrue(log_file.is_file())
            self.assertEqual(log_file.stat().st_size, 0)
            backup1 = Path(tmp) / "backend.log.1"
            self.assertTrue(backup1.is_file())
            self.assertEqual(len(backup1.read_text(encoding="utf-8")), 2000)

    def test_multiple_rotations_shift_backups(self):
        with tempfile.TemporaryDirectory() as tmp:
            log_file = Path(tmp) / "backend.log"
            # First rotation
            log_file.write_text("log round 1", encoding="utf-8")
            rotate_logs.rotate_log_file(log_file, max_bytes=5, max_backups=3)

            # Second rotation
            log_file.write_text("log round 2", encoding="utf-8")
            rotate_logs.rotate_log_file(log_file, max_bytes=5, max_backups=3)

            self.assertEqual((Path(tmp) / "backend.log.1").read_text(encoding="utf-8"), "log round 2")
            self.assertEqual((Path(tmp) / "backend.log.2").read_text(encoding="utf-8"), "log round 1")


if __name__ == "__main__":
    unittest.main()

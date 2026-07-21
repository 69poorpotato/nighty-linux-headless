import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import bridge  # noqa: E402


class BackendLogTailTests(unittest.TestCase):
    def test_small_log_is_returned_in_full(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "backend.log"
            path.write_bytes(b"first\nsecond\n")
            self.assertEqual(bridge._read_backend_log_tail(path, 1024), "first\nsecond\n")

    def test_large_log_discards_partial_first_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "backend.log"
            path.write_bytes(b"old-line\n" + b"x" * 128 + b"\nCTL server up\nready\n")
            result = bridge._read_backend_log_tail(path, 40)
            self.assertEqual(result, "CTL server up\nready\n")
            self.assertNotIn("old-line", result)


if __name__ == "__main__":
    unittest.main()

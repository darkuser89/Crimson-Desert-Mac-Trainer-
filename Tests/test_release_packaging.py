#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Verify rejected release inputs create no output or app copies."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ReleaseInputTests(unittest.TestCase):
    def test_mismatched_tag_creates_no_release(self):
        with tempfile.TemporaryDirectory(prefix="crimson-release-test-") as folder:
            output = Path(folder) / "release"
            result = subprocess.run([sys.executable, "-B", str(ROOT / "script/package_release.py"),
                                     str(output), "--tag", "v999.999.999"], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Release tag must match app version", result.stderr)
            self.assertFalse(output.exists())

    def test_in_source_output_is_rejected_before_writing(self):
        output = ROOT / "release-output-forbidden-fixture"
        self.assertFalse(output.exists())
        result = subprocess.run([sys.executable, "-B", str(ROOT / "script/package_release.py"),
                                 str(output)], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("outside source", result.stderr)
        self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()

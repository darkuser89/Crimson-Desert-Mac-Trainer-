#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Exercise fail-closed UUID, segment and instruction validation with own fixtures."""
import importlib.util
import struct
import tempfile
import unittest
import uuid
from pathlib import Path

spec = importlib.util.spec_from_file_location('verify_build', Path(__file__).resolve().parents[1]/'script/verify_crimson_build.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class BuildChecks(unittest.TestCase):
    def test_changed_builds_and_unmapped_bytes_are_rejected(self):
        identity = uuid.UUID('083C4A58-7D49-307F-8F0F-8F9EEAE8343C')
        header = struct.pack('<8I', 0xfeedfacf, 0x100000c, 0, 2, 2, 96, 0, 0)
        segment = struct.pack('<II16s4Q4I', 0x19, 72, b'__TEXT', 0x100000000, 4096, 0, 160, 5, 5, 0, 0)
        blob = header + segment + struct.pack('<II16s', 0x1b, 24, identity.bytes) + bytes(range(32))
        with tempfile.TemporaryDirectory(prefix='crimson-build-check-') as temporary:
            binary = Path(temporary)/'fixture'
            binary.write_bytes(blob)
            probe = [(128, bytes(range(32)))]
            self.assertEqual(module.verify(binary, str(identity), probe), 1)
            with self.assertRaisesRegex(ValueError, 'UUID'):
                module.verify(binary, '0D6EC6AE-D229-3D5B-BEB9-9DD74EF820DA', probe)
            with self.assertRaisesRegex(ValueError, 'outside'):
                module.verify(binary, str(identity), [(160, b'\0')])
            binary.write_bytes(blob[:-1] + b'\0')
            with self.assertRaisesRegex(ValueError, 'mismatch'):
                module.verify(binary, str(identity), probe)
            binary.write_bytes(blob[:40])
            with self.assertRaisesRegex(ValueError, 'Truncated|Invalid'):
                module.verify(binary, str(identity), probe)


if __name__ == '__main__':
    unittest.main()

#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Pack standard iconset PNGs when iconutil cannot encode an iconset."""
from pathlib import Path
import struct
import sys

ICONS = (
    ("icon_16x16.png", 16, b"icp4"),
    ("icon_16x16@2x.png", 32, b"ic11"),
    ("icon_32x32.png", 32, b"icp5"),
    ("icon_32x32@2x.png", 64, b"ic12"),
    ("icon_128x128.png", 128, b"ic07"),
    ("icon_128x128@2x.png", 256, b"ic13"),
    ("icon_256x256.png", 256, b"ic08"),
    ("icon_256x256@2x.png", 512, b"ic14"),
    ("icon_512x512.png", 512, b"ic09"),
    ("icon_512x512@2x.png", 1024, b"ic10"),
)


def pack(source: Path, output: Path) -> None:
    chunks = []
    for name, size, code in ICONS:
        png = (source / name).read_bytes()
        if (len(png) < 24 or png[:16] != b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
                or struct.unpack(">II", png[16:24]) != (size, size)):
            raise ValueError(f"Invalid PNG size or header: {name}")
        chunks.append(code + struct.pack(">I", len(png) + 8) + png)
    data = b"".join(chunks)
    output.write_bytes(b"icns" + struct.pack(">I", len(data) + 8) + data)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: pack_iconset.py ICONSET OUTPUT.icns")
    pack(Path(sys.argv[1]), Path(sys.argv[2]))

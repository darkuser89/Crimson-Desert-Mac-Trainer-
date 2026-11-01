#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Package and round-trip verify the current signed macOS app outside source."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import plistlib
import re
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = "Crimson-Desert-Trainer-macOS-arm64.zip"


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout.strip()


def package(destination, tag=""):
    destination = Path(destination).expanduser().resolve()
    if destination == ROOT or ROOT in destination.parents:
        raise ValueError("Release output must be outside source.")
    config = json.loads((ROOT / "Resources/TrainerConfig.json").read_text())
    version = config["app"]["version"]
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?", version):
        raise ValueError("Invalid app version.")
    if tag and tag != "v" + version:
        raise ValueError(f"Release tag must match app version: v{version}")
    build = Path(os.environ.get("MT_TRAINER_BUILD_DIR", ROOT.parent / "CrimsonDesertTrainer-Build")).resolve()
    app = build / (config["app"]["name"] + ".app")
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    for key, expected in [("CFBundleIdentifier", config["app"]["bundleIdentifier"]),
                          ("CFBundleShortVersionString", version),
                          ("CFBundleVersion", config["app"]["build"])]:
        if info.get(key) != expected:
            raise ValueError(f"Stale or unexpected app: {key}")
    executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
    overlay = app / "Contents/Resources/TrainerOverlay.dylib"
    for binary in [executable, overlay]:
        if run("lipo", "-archs", str(binary)) != "arm64":
            raise ValueError(f"Expected arm64 binary: {binary.name}")
    run("codesign", "--verify", "--deep", "--strict", str(app))
    destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".release-stage-", dir=destination) as stage:
        stage = Path(stage)
        archive = stage / ARCHIVE
        run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(archive))
        with zipfile.ZipFile(archive) as contents:
            if contents.testzip() is not None:
                raise ValueError("Corrupt release ZIP.")
            for entry in contents.namelist():
                path = Path(entry)
                if path.is_absolute() or ".." in path.parts or path.parts[0] not in [app.name, "__MACOSX"]:
                    raise ValueError("Unexpected ZIP entry.")
        extracted = stage / "verify"
        run("ditto", "-x", "-k", str(archive), str(extracted))
        unpacked = extracted / app.name
        run("codesign", "--verify", "--deep", "--strict", str(unpacked))
        for relative in ["Contents/MacOS/" + info["CFBundleExecutable"], "Contents/Resources/TrainerOverlay.dylib"]:
            if (unpacked / relative).read_bytes() != (app / relative).read_bytes():
                raise ValueError("Archive changed an executable.")
        (stage / "INSTALLATION.txt").write_text(f"Crimson Desert Trainer v{version}\n\n" + (ROOT / "docs/INSTALLATION.txt").read_text())
        (stage / "RELEASE_NOTES.md").write_bytes((ROOT / "docs/RELEASE_NOTES.md").read_bytes())
        checksums = "".join(f"{hashlib.sha256((stage / name).read_bytes()).hexdigest()}  {name}\n"
                            for name in [ARCHIVE, "INSTALLATION.txt"])
        (stage / "SHA256SUMS.txt").write_text(checksums)
        for name in [ARCHIVE, "INSTALLATION.txt", "RELEASE_NOTES.md", "SHA256SUMS.txt"]:
            os.replace(stage / name, destination / name)
    print(f"Verified release package: {destination / ARCHIVE}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination")
    parser.add_argument("--tag", default=os.environ.get("RELEASE_TAG", ""))
    args = parser.parse_args()
    try:
        package(args.destination, args.tag)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Release packaging failed: {error}\n")

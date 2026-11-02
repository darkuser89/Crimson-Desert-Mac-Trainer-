#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Check the trainer's exact UUID and instruction probes without starting a game."""
import argparse
import json
import re
import struct
import uuid
from pathlib import Path


def verify(binary, expected_uuid, probes):
    with binary.open('rb') as file:
        header = file.read(32)
        if len(header) != 32:
            raise ValueError('Truncated Mach-O header')
        magic, cpu, _, kind, count, size, _, _ = struct.unpack('<8I', header)
        if (magic, cpu, kind) != (0xfeedfacf, 0x100000c, 2) or size > 1048576 or count > 4096:
            raise ValueError('Expected a thin arm64 executable')
        commands = file.read(size)
        segments, actual_uuid, offset = [], None, 0
        for _ in range(count):
            if offset + 8 > len(commands):
                raise ValueError('Truncated load command')
            cmd, length = struct.unpack_from('<II', commands, offset)
            if length < 8 or offset + length > len(commands):
                raise ValueError('Invalid load command')
            if cmd == 0x1b:
                if length != 24 or actual_uuid is not None:
                    raise ValueError('Invalid UUID command')
                actual_uuid = uuid.UUID(bytes=commands[offset+8:offset+24])
            if cmd == 0x19:
                if length < 72:
                    raise ValueError('Invalid segment command')
                _, vm, _, disk, disk_size = struct.unpack_from('<16s4Q', commands, offset+8)
                segments.append((vm, disk, disk_size))
            offset += length
        if offset != size or actual_uuid != uuid.UUID(expected_uuid):
            raise ValueError('Executable UUID does not match the trainer')
        bases = [vm for vm, disk, disk_size in segments if disk == 0 and disk_size]
        if len(bases) != 1:
            raise ValueError('Missing or ambiguous main-image segment')
        for relative, expected in probes:
            address = bases[0] + relative
            matches = [(vm, disk) for vm, disk, disk_size in segments
                       if vm <= address and address + len(expected) <= vm + disk_size]
            if len(matches) != 1:
                raise ValueError(f'Probe outside file-backed segment: {relative:#x}')
            vm, disk = matches[0]
            file.seek(disk + address - vm)
            if file.read(len(expected)) != expected:
                raise ValueError(f'Instruction mismatch: {relative:#x}')
    return len(probes)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    config = json.loads((root/'Resources/TrainerConfig.json').read_text())['profiles'][0]
    manifest = (root/'Sources/CrimsonBuild.h').read_text()
    raw_uuid = re.search(r'CDExpectedUUID\[16\]=\{([^}]+)\}', manifest)
    manifest_uuid = str(uuid.UUID(bytes=bytes(int(x, 16) for x in raw_uuid[1].split(',')))).upper()
    if config['uuids'] != [manifest_uuid]:
        raise SystemExit('Profile UUID and native manifest differ')
    probes = [(int(address, 16), bytes(int(x, 16) for x in raw.split(',')))
              for address, raw in re.findall(r'\{(0x[0-9a-f]+),\{([^}]+)\}\}', manifest)]
    if not probes or len({address for address, _ in probes}) != len(probes):
        raise SystemExit('Missing or duplicate native probes')
    binary = args.app/'Contents/MacOS'/config['executable']
    try:
        checked = verify(binary, manifest_uuid, probes)
    except (OSError, ValueError, struct.error) as error:
        raise SystemExit(str(error)) from error
    print(json.dumps({'uuid': manifest_uuid, 'instructionProbes': checked, 'matched': True}))


if __name__ == '__main__':
    main()

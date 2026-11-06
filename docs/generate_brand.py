#!/usr/bin/env python3
"""Distribute the approved PNG identity and generate package wordmark exports.

Run ``python3 docs/generate_brand.py`` from MOSSQuantum. The approved icon is
copied byte-for-byte; only the independent package wordmarks are generated.
The download kit contains the original PNG and font-independent SVG wordmarks.
"""
from __future__ import annotations

from html import escape
import hashlib
import json
import zipfile
from pathlib import Path
import re

RED = '#CB3C33'
GREEN = '#389826'
PURPLE = '#9558B2'
INK = '#202331'
PAPER = '#EEF0F6'
ICON_NAME = 'moos-qubit-grid.png'
APPROVED_ICON_SHA256 = '354838f61a8d1c5cb78106e435b5a4f1854357927aa00a6ccde8cab97ea4d915'

PACKAGES = (
    ('MOSSQuantum', 'Quantum', PURPLE, 'CORE SIMULATOR'),
    ('MOSSMPS', 'MPS', GREEN, 'TENSOR NETWORKS'),
    ('MOSSStabilizer', 'Stabilizer', RED, 'STABILIZER BACKEND'),
    ('MOSSChemistry', 'Chemistry', PURPLE, 'QUANTUM CHEMISTRY'),
    ('MOSSFragmentTN', 'FragmentTN', GREEN, 'FRAGMENT TENSORS'),
    ('MOSSGPU', 'GPU', RED, 'CUDA BACKEND'),
    ('MOSSAlgorithmZoo', 'AlgorithmZoo', PURPLE, 'ALGORITHM EXAMPLES'),
)

# Five-column, nine-row cells. Capitals occupy seven rows; lowercase x-height
# begins on row two, with true ascenders and descenders on the same baseline.
RAW_GLYPHS = {
    'A': '01110/10001/10001/11111/10001/10001/10001',
    'B': '11110/10001/10001/11110/10001/10001/11110',
    'C': '01111/10000/10000/10000/10000/10000/01111',
    'D': '11110/10001/10001/10001/10001/10001/11110',
    'E': '11111/10000/10000/11110/10000/10000/11111',
    'F': '11111/10000/10000/11110/10000/10000/10000',
    'G': '01110/10001/10000/10111/10001/10001/01110',
    'H': '10001/10001/10001/11111/10001/10001/10001',
    'I': '01110/00100/00100/00100/00100/00100/01110',
    'J': '00111/00010/00010/00010/00010/10010/01100',
    'K': '10001/10010/10100/11000/10100/10010/10001',
    'L': '10000/10000/10000/10000/10000/10000/11111',
    'M': '10001/11011/10101/10101/10001/10001/10001',
    'N': '10001/11001/11001/10101/10011/10011/10001',
    'O': '01110/10001/10001/10001/10001/10001/01110',
    'P': '11110/10001/10001/11110/10000/10000/10000',
    'Q': '01110/10001/10001/10001/10101/10010/01101',
    'R': '11110/10001/10001/11110/10100/10010/10001',
    'S': '01111/10000/10000/01110/00001/00001/11110',
    'T': '11111/00100/00100/00100/00100/00100/00100',
    'U': '10001/10001/10001/10001/10001/10001/01110',
    'V': '10001/10001/10001/10001/10001/01010/00100',
    'W': '10001/10001/10001/10101/10101/11011/10001',
    'X': '10001/10001/01010/00100/01010/10001/10001',
    'Y': '10001/10001/01010/00100/00100/00100/00100',
    'Z': '11111/00001/00010/00100/01000/10000/11111',
    'a': '00000/00000/01110/00001/01111/10001/01111',
    'b': '10000/10000/10110/11001/10001/10001/11110',
    'c': '00000/00000/01110/10000/10000/10000/01110',
    'd': '00001/00001/01101/10011/10001/10001/01111',
    'e': '00000/00000/01110/10001/11111/10000/01110',
    'f': '00110/01001/01000/11100/01000/01000/01000',
    'g': '00000/00000/01111/10001/10001/01111/00001/10001/01110',
    'h': '10000/10000/10110/11001/10001/10001/10001',
    'i': '00100/00000/01100/00100/00100/00100/01110',
    'j': '00010/00000/00110/00010/00010/00010/00010/10010/01100',
    'k': '10000/10000/10010/10100/11000/10100/10010',
    'l': '01100/00100/00100/00100/00100/00100/01110',
    'm': '00000/00000/11010/10101/10101/10101/10101',
    'n': '00000/00000/10110/11001/10001/10001/10001',
    'o': '00000/00000/01110/10001/10001/10001/01110',
    'p': '00000/00000/11110/10001/10001/11110/10000/10000/10000',
    'q': '00000/00000/01111/10001/10001/01111/00001/00001/00001',
    'r': '00000/00000/10110/11001/10000/10000/10000',
    's': '00000/00000/01111/10000/01110/00001/11110',
    't': '00100/00100/01110/00100/00100/00101/00010',
    'u': '00000/00000/10001/10001/10001/10001/01111',
    'v': '00000/00000/10001/10001/10001/01010/00100',
    'w': '00000/00000/10001/10001/10101/10101/01010',
    'x': '00000/00000/10001/01010/00100/01010/10001',
    'y': '00000/00000/10001/10001/10001/01111/00001/10001/01110',
    'z': '00000/00000/11111/00010/00100/01000/11111',
    '0': '01110/10001/10011/10101/11001/10001/01110',
    '1': '00100/01100/00100/00100/00100/00100/01110',
    '2': '01110/10001/00001/00010/00100/01000/11111',
    '3': '11110/00001/00001/01110/00001/00001/11110',
    '4': '00010/00110/01010/10010/11111/00010/00010',
    '5': '11111/10000/10000/11110/00001/00001/11110',
    '6': '01110/10000/10000/11110/10001/10001/01110',
    '7': '11111/00001/00010/00100/01000/01000/01000',
    '8': '01110/10001/10001/01110/10001/10001/01110',
    '9': '01110/10001/10001/01111/00001/00001/01110',
    ' ': '00000/00000/00000/00000/00000/00000/00000',
    '#': '01010/01010/11111/01010/11111/01010/01010',
    '-': '00000/00000/00000/11111/00000/00000/00000',
    '/': '00001/00010/00010/00100/01000/01000/10000',
    '+': '00000/00100/00100/11111/00100/00100/00000',
    '.': '00000/00000/00000/00000/00000/00110/00110',
}
GLYPHS = {}
for character, pattern in RAW_GLYPHS.items():
    rows = pattern.split('/')
    assert len(rows) <= 9 and all(len(row) == 5 and set(row) <= {'0', '1'} for row in rows)
    GLYPHS[character] = rows + ['00000'] * (9 - len(rows))


def text_width(text: str, unit: int = 1) -> int:
    return max(0, len(text) * 6 - 1) * unit


def pixel_text(text: str, x: int, y: int, unit: int, color: str) -> str:
    commands = []
    for index, character in enumerate(text):
        for row, pixels in enumerate(GLYPHS[character]):
            for run in re.finditer('1+', pixels):
                px = x + (index * 6 + run.start()) * unit
                py = y + row * unit
                width = len(run.group()) * unit
                commands.append(f'M{px},{py}h{width}v{unit}h-{width}z')
    return f'<path fill="{color}" d="{"".join(commands)}"/>'


def wordmark_geometry(name: str, suffix: str, accent: str, *, dark=False,
                      compact=False, x=0, y=0, unit=1) -> str:
    assert name == 'MOSS' + suffix
    prefix_color = PAPER if dark else INK
    prefix = pixel_text('MOSS', x, y, unit, prefix_color)
    if compact:
        return prefix + pixel_text(suffix, x, y + 10 * unit, unit, accent)
    return prefix + pixel_text(suffix, x + 24 * unit, y, unit, accent)


def svg(width, height, body, label, *, display_width=None, display_height=None,
        description='Original MOSS pixel identity. Geometric paths; no font dependency.'):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{display_width or width}" '
            f'height="{display_height or height}" viewBox="0 0 {width} {height}" '
            f'role="img" aria-label="{escape(label, quote=True)}" shape-rendering="crispEdges">'
            f'<title>{escape(label)}</title><desc>{escape(description)}</desc>{body}</svg>\n')


def package_assets(name, suffix, accent):
    full_width = text_width(name)
    compact_width = max(text_width('MOSS'), text_width(suffix))
    assets = {}
    for dark in (False, True):
        ending = '-dark' if dark else ''
        for compact in (False, True):
            layout = '-compact' if compact else ''
            width, height = (compact_width, 19) if compact else (full_width, 9)
            assets[f'wordmark{layout}{ending}.svg'] = svg(
                width, height, wordmark_geometry(name, suffix, accent, dark=dark, compact=compact),
                name, display_width=width * 2, display_height=height * 2)
    return assets


def write_assets(directory, assets):
    directory.mkdir(parents=True, exist_ok=True)
    for filename, content in assets.items():
        (directory / filename).write_text(content, encoding='utf-8')


def main():
    core = Path(__file__).resolve().parents[1]
    workspace = core.parent
    brand = core / 'docs/assets/brand'
    icon = (brand / ICON_NAME).read_bytes()
    if not icon.startswith(bytes.fromhex('89504e470d0a1a0a')):
        raise SystemExit('Approved icon must be a PNG')
    if hashlib.sha256(icon).hexdigest() != APPROVED_ICON_SHA256:
        raise SystemExit('Approved icon differs; review and update its fingerprint before distribution')
    identity = json.dumps({
        'display_name': 'MOOS',
        'family_name': 'MOSS',
        'letter_rows': ['MO', 'OS'],
        'icon': ICON_NAME,
        'icon_sha256': APPROVED_ICON_SHA256,
        'format': 'image/png',
        'transparent_background': True,
        'packages': [item[0] for item in PACKAGES],
    }, ensure_ascii=False, indent=2) + '\n'
    for name, suffix, accent, _ in PACKAGES:
        assets = package_assets(name, suffix, accent)
        write_assets(brand / 'packages' / name, assets)
        package_exports = brand / 'packages' / name
        for old in ('lockup.svg', 'lockup-dark.svg'):
            (package_exports / old).unlink(missing_ok=True)
        checkout = workspace / name
        if checkout.is_dir():
            target = checkout / 'docs/assets/brand'
            write_assets(target, {**assets, 'identity.json': identity})
            (target / ICON_NAME).write_bytes(icon)
            for old in ('moss-icon.svg', 'lockup.svg', 'lockup-dark.svg'):
                (target / old).unlink(missing_ok=True)
    (brand / 'family-overview.svg').unlink(missing_ok=True)
    # Preserve the previously shared PNG URL while showing the approved image.
    (brand / 'family-overview.png').write_bytes(icon)
    (brand / 'identity.json').write_text(identity)
    note = (
        'MOSS family display assets\n'
        'The approved MOOS mark reads MO / OS in a two-by-two layout.\n'
        'The green and purple O letters contain cartoon qubit arcs and red state dots.\n'
        'The icon is the original transparent PNG, not a vector tracing.\n'
        'Package and repository names retain their canonical MOSS names.\n'
        'Package wordmarks are separate SVG paths with light/dark and compact variants.\n'
        'Keep the original aspect ratio. The icon artwork is identical across the family.\n'
    )
    files = {'README.txt': note.encode(), 'shared/' + ICON_NAME: icon,
             'shared/identity.json': identity.encode()}
    for name, _, _, _ in PACKAGES:
        for asset in sorted((brand / 'packages' / name).glob('wordmark*.svg')):
            files[f'packages/{name}/{asset.name}'] = asset.read_bytes()
    with zipfile.ZipFile(brand / 'moss-family-brand-kit.zip', 'w') as archive:
        for filename, data in sorted(files.items()):
            entry = zipfile.ZipInfo(filename, date_time=(2026, 11, 6, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.create_system = 3
            entry.external_attr = 0o644 << 16
            archive.writestr(entry, data)
    print(f'Distributed approved PNG unchanged; generated wordmarks and {len(files)}-file download kit.')


if __name__ == '__main__':
    main()

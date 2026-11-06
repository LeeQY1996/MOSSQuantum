#!/usr/bin/env python3
"""Generate the original MOSS pixel identity using only Python's standard library.

Run ``python3 docs/generate_brand.py`` from the MOSSQuantum repository. The core
repository receives the shared mark, every package's exports and the overview;
neighboring family checkouts receive their corresponding flat asset set.
The glyphs are original geometry. No installed or embedded font is used.
"""
from __future__ import annotations

from html import escape
from pathlib import Path
import re

RED = '#CB3C33'
GREEN = '#389826'
PURPLE = '#9558B2'
INK = '#202331'
PAPER = '#EEF0F6'

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


def icon_geometry(x=0, y=0, size=32) -> str:
    # The two square heads anchor the upright stems. Three inward pixel steps
    # join the heads into an M with an intentionally open central counter.
    return (f'<g transform="translate({x} {y}) scale({size / 32:g})">'
            f'<path fill="{RED}" d="M4 7h6v21H4zM3 3h8v8H3z"/>'
            f'<path fill="{GREEN}" d="M22 7h6v21h-6zM21 3h8v8h-8z"/>'
            f'<path fill="{PURPLE}" d="M10 10h4v6h-4zM14 14h4v6h-4zM18 10h4v6h-4z"/>'
            '</g>')


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
        width = 16 + 32 + 12 + full_width * 2
        body = icon_geometry(8, 8, 32) + wordmark_geometry(
            name, suffix, accent, dark=dark, x=52, y=17, unit=2)
        assets[f'lockup{ending}.svg'] = svg(width, 48, body, name)
    return assets


def overview():
    body = ['<path fill="#FAFAF8" d="M0 0h1600v1600H0z"/>',
            icon_geometry(80, 76, 128),
            pixel_text('MOSS', 256, 92, 12, INK),
            pixel_text('QUANTUM SOFTWARE FAMILY', 256, 206, 3, '#73776F'),
            pixel_text('07 PACKAGES', 1309, 112, 3, INK),
            '<path fill="#D9DDD5" d="M96 282h1408v2H96z"/>',
            pixel_text('LIGHT', 220, 300, 2, '#73776F'),
            pixel_text('DARK', 968, 300, 2, '#73776F')]
    for index, (name, suffix, accent, descriptor) in enumerate(PACKAGES):
        y = 340 + 132 * index
        body.extend([
            f'<path fill="#FFFFFF" d="M96 {y}h1408v112H96z"/>',
            f'<path fill="{INK}" d="M904 {y}h600v112H904z"/>',
            icon_geometry(116, y + 24, 64),
            wordmark_geometry(name, suffix, accent, x=220, y=y + 23, unit=4),
            pixel_text(descriptor, 220, y + 75, 2, '#73776F'),
            icon_geometry(924, y + 24, 64),
            wordmark_geometry(name, suffix, accent, dark=True, x=1020, y=y + 34, unit=3),
        ])
    body.append('<path fill="#D9DDD5" d="M96 1334h1408v2H96z"/>')
    body.append(pixel_text('JULIA PALETTE', 96, 1370, 2, INK))
    for x, color, label in [(96, RED, '#CB3C33'), (416, GREEN, '#389826'), (736, PURPLE, '#9558B2')]:
        body.append(f'<path fill="{color}" d="M{x} 1410h256v40H{x}z"/>')
        body.append(pixel_text(label, x, 1466, 2, '#73776F'))
    body.append(pixel_text('ORIGINAL PIXEL GEOMETRY', 96, 1534, 2, '#73776F'))
    body.append(pixel_text('SVG / LIGHT + DARK', 1290, 1534, 2, '#73776F'))
    return svg(1600, 1600, ''.join(body), 'MOSS family: seven package identities',
               description='Seven exact CamelCase package wordmarks with the shared MOSS mark, light and dark variants, and the red, green and purple Julia palette.')


def write_assets(directory, assets):
    directory.mkdir(parents=True, exist_ok=True)
    for filename, content in assets.items():
        (directory / filename).write_text(content, encoding='utf-8')


def main():
    core = Path(__file__).resolve().parents[1]
    workspace = core.parent
    brand = core / 'docs/assets/brand'
    icon = svg(32, 32, icon_geometry(), 'MOSS',
               description='Shared MOSS mark: red and green square-headed stems joined by a purple pixel valley.')
    for name, suffix, accent, _ in PACKAGES:
        assets = package_assets(name, suffix, accent)
        write_assets(brand / 'packages' / name, assets)
        checkout = workspace / name
        if checkout.is_dir():
            write_assets(checkout / 'docs/assets/brand', {'moss-icon.svg': icon, **assets})
    write_assets(brand, {'moss-icon.svg': icon, 'family-overview.svg': overview()})
    print('Generated shared MOSS mark, seven exact-name SVG identity sets and family overview.')


if __name__ == '__main__':
    main()

# -*- coding: utf-8 -*-
"""Recover Starlit Dart ru:/en: string literals mangled by UTF-8 ↔ cp1251."""
from __future__ import annotations

import re
import sys
from pathlib import Path


def _trail_byte(ch: str) -> int | None:
    o = ord(ch)
    if o < 0x100:
        return o
    try:
        b = ch.encode('cp1251')
    except UnicodeEncodeError:
        return None
    return b[0] if len(b) == 1 else None


def recover(s: str) -> str:
    out = bytearray()
    i = 0
    n = len(s)
    while i < n:
        ch = s[i]
        if ch in ('Р', 'С') and i + 1 < n:
            lead = 0xD0 if ch == 'Р' else 0xD1
            trail = _trail_byte(s[i + 1])
            if trail is not None:
                out.extend((lead, trail))
                i += 2
                continue
        if ch == 'в' and i + 2 < n and s[i + 1] == 'Ђ':
            trail = _trail_byte(s[i + 2])
            if trail is not None:
                out.extend((0xE2, 0x80, trail))
                i += 3
                continue
        if ch == 'В' and i + 1 < n:
            trail = _trail_byte(s[i + 1])
            if trail is not None and trail in (0xAB, 0xBB):
                out.extend((0xC2, trail))
                i += 2
                continue
        out.extend(ch.encode('utf-8'))
        i += 1
    try:
        return out.decode('utf-8')
    except UnicodeDecodeError:
        return s


def needs_fix(s: str) -> bool:
    return any(x in s for x in ('Р\xa0', 'Рµ', 'Рё', 'Р°', 'вЂ', 'В«', 'В»', 'Сѓ', 'С‚', 'СЂ'))


def main() -> None:
    path = Path(sys.argv[1])
    text = path.read_text(encoding='utf-8-sig')
    changed = 0

    def repl(m: re.Match[str]) -> str:
        nonlocal changed
        prefix, body = m.group(1), m.group(2)
        if not needs_fix(body) and 'Р' not in body and 'вЂ' not in body:
            # Still try recover when capital Cyrillic Er density is high
            if body.count('Р') + body.count('С') < 2:
                return m.group(0)
        fixed = recover(body)
        if fixed == body:
            return m.group(0)
        changed += 1
        return f"{prefix}'{fixed}'"

    # Match ru:/en: labels with single-quoted bodies (possibly after newline).
    new_text = re.sub(
        r"((?:ru|en):\s*)'([^']*)'",
        repl,
        text,
        flags=re.DOTALL,
    )
    path.write_text(new_text, encoding='utf-8', newline='\n')
    print(f'fixed {changed} literals in {path}')


if __name__ == '__main__':
    main()

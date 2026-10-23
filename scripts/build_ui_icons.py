"""Build the original, offline vector icon set used by the island UI."""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "game/assets/ui"
INK = "#456753"
ICONS = {
    "map": '<path fill="#e3ebcf" d="M6 15 23 9 42 15 58 9v42l-16 6-19-6-17 6Z"/><path fill="#c3d8ae" d="m23 9 19 6v42l-19-6Z"/><path d="M23 9v42M42 15v42"/><path stroke="#faf6e4" stroke-width="5" d="m9 35 14-9 15 10 17-13"/><circle fill="#bd684f" stroke="#fff9ed" cx="36" cy="35" r="6"/>',
    "bag": '<path fill="#c09a73" d="M24 17v-5a8 8 0 0 1 16 0v5"/><rect x="12" y="15" width="40" height="43" rx="12" fill="#d8b58c"/><path fill="#e7c7a3" d="M12 30V25q0-10 12-10h16q12 0 12 10v5q-20 12-40 0Z"/><rect x="23" y="39" width="20" height="13" rx="4" fill="#f4dbb2"/><path d="M32 28v8"/>',
    "journal": '<path fill="#c8846b" d="M12 7h34q6 0 6 6v40q0 5-6 5H12Z"/><path fill="#fff3d9" d="M17 8h28v42H17Z"/><path fill="#76a37a" d="M23 12v19l7-5 7 5V12"/><path d="M12 50h34M10 12h7M10 23h7M10 34h7M10 45h7"/>',
    "settings": '<path fill="#90ab93" d="m26 5 12 0 2 8 7 4 8-2 6 11-6 6v8l6 5-6 11-8-2-7 4-2 5H26l-2-5-7-4-8 2-6-11 6-5v-8l-6-6 6-11 8 2 7-4Z" transform="translate(4 1) scale(.87)"/><circle cx="32" cy="31" r="10" fill="#fcf9ed"/>',
    "leaf": '<path fill="#86a972" d="M12 51C3 26 27 10 53 8c4 23-6 49-33 44Z"/><path d="M10 58 42 21M23 43l-2-16M31 35l15-2"/>',
    "apple": '<path fill="#d88870" d="M32 20C16 8 2 25 9 44q8 21 23 11 15 10 23-11C62 25 48 8 32 20Z"/><path d="M32 22V10"/><path fill="#8eaf77" d="M33 14q6-12 18-8-6 13-18 8"/><path stroke="#f6c8af" d="M17 29q-5 5-2 12"/>',
    "cake": '<path fill="#f0d0a2" d="M9 30h46v24H9Z"/><path fill="#f8ead5" d="M9 30q0-14 23-14t23 14v7q-6 7-12 0-6 7-12 0-6 7-11 0-7 7-11 0Z"/><path d="M9 48h46"/><circle cx="32" cy="14" r="7" fill="#c9745c"/><path d="M32 7q2-4 5-4"/>',
    "outfit": '<path fill="#d4a447" d="m17 9 15 6 15-6 14 15-11 10-6-6v29H20V28l-6 6L3 24Z"/><path fill="#f9efd5" d="M24 12q0 13 16 0"/>',
    "home": '<path fill="#e3b48d" d="M12 30h40v28H12Z"/><path fill="#8faf92" d="M4 30 32 6l28 24Z"/><path fill="#f7e4b9" d="M26 37h13v21H26Z"/><path fill="#d4e8e0" d="M15 37h8v10h-8Z"/>',
    "speaker": '<path fill="#91ad98" d="m8 24 12 0 16-13v42L20 40H8Z"/><path fill="none" d="M44 23q11 9 0 18M50 14q20 18 0 36"/>',
    "flower_box": '<path fill="#c79972" d="m8 35 48 0-5 23H13Z"/><path d="M21 37V20M43 37V17M32 37V26"/><path fill="#8eaf77" d="M21 31q-12 0-12-10 12 0 12 10M43 29q12 0 12-10-12 0-12 10"/><circle cx="21" cy="16" r="9" fill="#d89088"/><circle cx="43" cy="12" r="8" fill="#e3bf65"/><circle cx="32" cy="25" r="6" fill="#f0d3ac"/>',
    "picnic": '<path fill="#d7a09b" d="m6 32 39-10 14 31-39 9Z"/><path stroke="#f6e6cf" d="m17 30 13 29M31 26l13 29M10 42l40-11M15 53l40-11"/><path fill="#d0ae7d" d="M19 22h25v17H19Z"/><path fill="none" d="M23 22v-7q8-13 17 0v7"/>',
    "lamp": '<path fill="#ecd8a5" d="M21 10h22l13 29H8Z"/><path d="M32 39v17M21 58h22"/><path fill="none" d="M17 6 14 2M47 6l3-4M3 25H0M64 25h-3"/>',
    "music": '<path fill="#d4ad66" d="M24 12 53 5v37H43V18l-19 5v26H14V13Z"/><ellipse cx="15" cy="49" rx="10" ry="8" fill="#8aa791"/><ellipse cx="44" cy="42" rx="10" ry="8" fill="#8aa791"/>',
    "art": '<path fill="#e7cba2" d="M33 6C3 4-6 43 18 55c14 8 20 1 16-6-5-8 1-12 8-10 23 5 23-28-9-33Z"/><circle cx="18" cy="24" r="5" fill="#c67d69"/><circle cx="30" cy="16" r="5" fill="#dfbd61"/><circle cx="44" cy="20" r="5" fill="#89aa7c"/><circle cx="14" cy="39" r="5" fill="#82acbb"/><path stroke="#7c6951" stroke-width="5" d="m36 54 22-30"/>',
    "science": '<path fill="#d6e5df" d="M23 7h18M26 7v18L12 48q-5 10 7 10h26q12 0 7-10L38 25V7"/><path fill="#91af79" d="m17 40 30 0 5 10q3 8-8 8H20q-11 0-8-8Z"/><circle cx="29" cy="45" r="3" fill="#f1f2d9"/><circle cx="38" cy="35" r="3" fill="#c5dabe"/>',
    "football": '<circle cx="32" cy="32" r="27" fill="#f8f2df"/><path fill="#648476" d="m32 19 13 9-5 15H24l-5-15ZM8 23l7-14 8-2-4 14ZM44 7l10 12-8 7-8-9ZM59 35l-7 17-10-6 3-13ZM35 59 18 55l3-11 14 0Z"/>',
    "arrow": '<path fill="none" stroke-width="5" d="M12 32h38M36 18l14 14-14 14"/>',
    "close": '<path fill="none" stroke-width="5" d="m18 18 28 28M46 18 18 46"/>',
    "check": '<path fill="none" stroke="#fcf9ed" stroke-width="6" d="m12 33 13 13 28-30"/>',
    "sun": '<circle cx="32" cy="32" r="14" fill="#e7bd60"/><path stroke="#c39c4e" d="M32 3v7M32 54v7M3 32h7M54 32h7M11 11l5 5M48 48l5 5M53 11l-5 5M16 48l-5 5"/>',
}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, shapes in ICONS.items():
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 64 64"><g stroke="{INK}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">{shapes}</g></svg>\n'
        (OUT / f"{name}.svg").write_text(svg, encoding="utf-8")
    print(f"Wrote {len(ICONS)} original SVG icons to {OUT}")

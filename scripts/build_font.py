"""Build the game's renamed, offline CJK font subset (SIL OFL 1.1).

Only reads the source font; writes assets/fonts. Re-run when visible game text
changes. --check verifies the packaged font covers current text without writing.
Requires fontTools; known build version is recorded in font_manifest.json.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import unicodedata

import fontTools
from fontTools import subset
from fontTools.ttLib import TTFont


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path(
    r"D:\工具\8.kindle\5.koreader-kindlepw2-v2024.07\koreader\fonts\noto\NotoSansCJKsc-Regular.otf"
)
OUTPUT = ROOT / "game" / "assets" / "fonts"
TARGET = OUTPUT / "IslandSans.otf"
EXTRA_TEXT = "✓×→←↑↓•·…–—“”‘’￥★☆□■△▲○●①②③④⑤⑥⑦⑧⑨⑩"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def json_display_text(value):
    if isinstance(value, str):
        return unicodedata.normalize("NFC", value)
    if isinstance(value, list):
        return "".join(json_display_text(item) for item in value)
    if isinstance(value, dict):
        # The separate combining-mark field is reconstruction metadata. The UI
        # renders NFC raw_character (for example é), never this isolated mark.
        return "".join(str(key) + json_display_text(item) for key, item in value.items()
                       if key != "diacritic" and not (key == "raw" and value.get("type") == "diacritic"))
    return ""


def collect_text():
    paths = sorted((ROOT / "game" / "scripts").rglob("*.gd"))
    paths += sorted((ROOT / "game" / "ui").rglob("*.gd"))
    paths += sorted((ROOT / "game" / "activities").rglob("*.gd"))
    paths += sorted((ROOT / "game" / "data").rglob("*.json"))
    paths += sorted((ROOT / "game" / "assets" / "living").glob("*.json"))
    paths += sorted((ROOT / "game" / "assets" / "world").glob("*.json"))
    # Whole source text also captures all currently hard-coded Chinese labels.
    text = "".join(json_display_text(json.loads(path.read_text(encoding="utf-8-sig")))
                   if path.suffix == ".json" else path.read_text(encoding="utf-8-sig")
                   for path in paths)
    required = {ord(char) for char in text if char.isprintable()}
    required.update(range(0x20, 0x7F))
    required.update(map(ord, EXTRA_TEXT))
    optional = set(range(0x3000, 0x3040)) | set(range(0xFF01, 0xFF60))
    return paths, required, optional


def describe_missing(codepoints):
    return ", ".join(f"U+{cp:04X} {unicodedata.name(chr(cp), 'unnamed')}" for cp in sorted(codepoints))


def metadata(font):
    result = {}
    for record in font["name"].names:
        if record.nameID in (0, 1, 3, 4, 5, 6, 13, 14):
            result.setdefault(str(record.nameID), [])
            text = record.toUnicode()
            if text not in result[str(record.nameID)]:
                result[str(record.nameID)].append(text)
    return result


def rename_font(font):
    replacement = {
        1: "Island Sans", 2: "Regular", 3: "1.004;IslandSans-Regular;LoveStudySubset1",
        4: "Island Sans Regular", 6: "IslandSans-Regular",
        16: "Island Sans", 17: "Regular", 18: "Island Sans Regular", 25: "IslandSans",
    }
    for record in list(font["name"].names):
        if record.nameID in replacement:
            font["name"].setName(replacement[record.nameID], record.nameID,
                                 record.platformID, record.platEncID, record.langID)
    for name_id, value in replacement.items():
        font["name"].setName(value, name_id, 3, 1, 0x409)
    if "CFF " in font:
        cff = font["CFF "].cff
        cff.fontNames = ["IslandSans-Regular"]
        top = cff.topDictIndex[0]
        top.FamilyName = "Island Sans"
        top.FullName = "Island Sans Regular"
        # Keep Notice/Copyright untouched; rename internal FD names as well.
        if hasattr(top, "FDArray"):
            for index, fd in enumerate(top.FDArray):
                if hasattr(fd, "FontName"):
                    fd.FontName = f"IslandSans-Regular-FD{index}"


def check():
    paths, required, _ = collect_text()
    with TTFont(TARGET) as font:
        missing = required - set(font.getBestCmap())
        if missing:
            raise ValueError("Bundled font misses current game text: " + describe_missing(missing))
        if font["name"].getDebugName(6) != "IslandSans-Regular":
            raise ValueError("Modified font has not been renamed")
        result = {
            "status": "ok", "font": str(TARGET.relative_to(ROOT)),
            "input_files": len(paths), "required_codepoints": len(required),
            "covered_codepoints": len(font.getBestCmap()), "glyphs": font["maxp"].numGlyphs,
            "bytes": TARGET.stat().st_size, "sha256": digest(TARGET),
        }
    print(json.dumps(result, ensure_ascii=False))
    return result


def build(source: Path):
    license_path = source.parent / "LICENSE"
    license_text = license_path.read_text(encoding="utf-8")
    if "SIL OPEN FONT LICENSE Version 1.1" not in license_text:
        raise ValueError("Expected the source's SIL Open Font License 1.1")
    paths, required, optional = collect_text()
    font = TTFont(source, recalcTimestamp=False)
    original_names = metadata(font)
    available = set(font.getBestCmap())
    missing = required - available
    if missing:
        raise ValueError("Source font lacks required glyphs: " + describe_missing(missing))
    keep = required | (optional & available)
    options = subset.Options()
    options.notdef_glyph = True
    options.notdef_outline = True
    options.recommended_glyphs = True
    options.glyph_names = True
    options.layout_features = ["*"]
    options.name_IDs = list(range(26))
    options.name_legacy = True
    options.name_languages = ["*"]
    job = subset.Subsetter(options=options)
    job.populate(unicodes=keep)
    job.subset(font)
    rename_font(font)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    font.save(TARGET)
    font.close()
    shutil.copyfile(license_path, OUTPUT / "LICENSE.txt")
    copyright_text = "\n".join(original_names.get("0", []))
    (OUTPUT / "COPYRIGHT.txt").write_text(
        copyright_text + "\n" + license_text.split("\n\n", 1)[0] + "\n\n"
        "Island Sans is a renamed subset of Noto Sans CJK SC Regular, built for LoveStudy.\n"
        "The modified font remains licensed under SIL Open Font License 1.1.\n"
        "Original font author and copyright holder names are retained for attribution only.\n"
        "Only characters currently needed by game scripts/curriculum plus ASCII and\n"
        "selected punctuation are included. Run scripts/build_font.py after adding text.\n",
        encoding="utf-8",
    )
    (OUTPUT / "charset.txt").write_text("".join(chr(cp) for cp in sorted(keep)) + "\n", encoding="utf-8")
    result = check()
    manifest = {
        "schema_version": 1, "family": "Island Sans", "postscript_name": "IslandSans-Regular",
        "license": "SIL Open Font License 1.1", "modified": True,
        "source_filename": source.name, "source_sha256": digest(source),
        "source_metadata": original_names, "fonttools_version": fontTools.__version__,
        "source_license_sha256": digest(license_path), "bundled_license_sha256": digest(OUTPUT / "LICENSE.txt"),
        "input_files": [{"path": str(path.relative_to(ROOT)).replace("\\", "/"),
                         "sha256": digest(path)} for path in paths],
        "charset_sha256": digest(OUTPUT / "charset.txt"),
        "coverage": "Current game script/curriculum printable characters, ASCII and selected punctuation; not a full CJK font.",
        "result": result,
    }
    (OUTPUT / "font_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    check() if args.check else build(args.source)

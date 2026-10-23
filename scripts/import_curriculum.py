"""Build the small offline curriculum from the user's existing Englishbook library.

Reads Englishbook only. Never downloads or synthesizes at runtime. The first build
uses exact, already cached Jenny speech. Re-run with --verify-only to check source
anchors, cached-audio equality, and the generated package without changing files.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil


ROOT = Path(__file__).resolve().parents[1]
G3 = "xiangshao-g3-1"
PROFILE = "edge-v1:en-US-JennyNeural:-10%"

# key, book, file page, source region, exact English, authored Chinese gloss
PHRASE_SPECS = [
    ("hello", G3, 8, "p8-r2", "Hello!", "你好！"),
    ("good_morning", G3, 8, "p8-r10", "Good morning.", "早上好。"),
    ("my_name", G3, 13, "p13-r14", "My name is Lulu.", "我叫露露。"),
    ("what_name", G3, 13, "p13-r11", "What's your name?", "你叫什么名字？"),
    ("how_old", G3, 18, "p18-r11", "How old are you?", "你几岁了？"),
    ("im_nine", G3, 18, "p18-r9", "I'm nine.", "我九岁了。"),
    ("thank_you", G3, 11, "p11-r4", "Thank you.", "谢谢你。"),
    ("goodbye", G3, 13, "p13-r15", "Goodbye.", "再见。"),
    ("apple", G3, 59, "p59-r6", "apple", "苹果"),
    ("cake", G3, 65, "p65-r24", "cake", "蛋糕"),
    ("milk", G3, 30, "p30-r9", "milk", "牛奶"),
    ("bread", "xiangshao-g4-1", 75, "p75-r17", "bread", "面包"),
    ("please", "xiangshao-g3-2", 73, "p73-r4", "please", "请"),
    ("like_apples", G3, 60, "p60-r4", "I like apples.", "我喜欢苹果。"),
    ("im_eight", G3, 18, "p18-r13", "I'm eight.", "我八岁了。"),
    ("nine", G3, 19, "p19-r12", "nine", "九"),
    ("hello_lingling", G3, 8, "p8-r8", "Hello, I'm Lingling.", "你好，我是玲玲。"),
    ("good_afternoon", G3, 13, "p13-r8", "Good afternoon, class.", "同学们，下午好。"),
]

UNIT_SPECS = [
    (1, "Hello!", "问候新朋友", 8, 12, ["hello", "good_morning", "thank_you", "hello_lingling"],
     ["u1_greeting", "u1_morning", "u1_goodbye"]),
    (2, "What's your name?", "认识彼此", 13, 17, ["what_name", "my_name", "goodbye", "good_afternoon"],
     ["u2_name", "u2_intro", "u2_polite"]),
    (3, "How old are you?", "年龄与数字", 18, 22, ["how_old", "im_nine", "im_eight", "nine"],
     ["u3_age", "u3_nine", "u3_birthday"]),
]


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def safe_source_file(public: Path, url: str) -> Path:
    result = (public / url.lstrip("/")).resolve()
    if not result.is_relative_to(public.resolve()):
        raise ValueError("Source URL leaves the public directory")
    return result


def make_questions(phrases):
    def question(qid, unit, phrase_key, instruction, choices, answer):
        phrase = phrases[phrase_key]
        source = deepcopy(phrase["source"])
        source["kind"] = "authored_adaptation"
        source["note"] = "游戏情境与选择题为新编；仅目标英语表达取自所列教材位置。"
        return {
            "id": qid, "unit": unit, "prompt": phrase["en"], "zh": phrase["zh"],
            "audio": phrase_key, "instruction": instruction,
            "choices": [{"id": cid, "text": text, "zh": zh} for cid, text, zh in choices],
            "answer": answer, "source": source,
        }

    return [
        question("u1_greeting", 1, "hello", "第一次见面，朋友在向你问好。选一句回应。", [
            ("greet", "Hello!", "你好！"), ("thanks", "Thank you.", "谢谢你。"),
            ("age", "I'm nine.", "我九岁了。")], "greet"),
        question("u1_morning", 1, "good_morning", "清晨到校，选一句早晨的问候。", [
            ("thanks", "Thank you.", "谢谢你。"), ("morning", "Good morning.", "早上好。"),
            ("bye", "Goodbye.", "再见。")], "morning"),
        question("u1_goodbye", 1, "thank_you", "朋友帮你找到回家的路。离开前，选一句表达感谢。", [
            ("morning", "Good morning.", "早上好。"), ("greet", "Hello!", "你好！"),
            ("thanks", "Thank you.", "谢谢你。")], "thanks"),
        question("u2_name", 2, "what_name", "新同学正在问你的名字。请替露露选一句回答。", [
            ("lulu", "My name is Lulu.", "我叫露露。"), ("nine", "I'm nine.", "我九岁了。"),
            ("thanks", "Thank you.", "谢谢你。")], "lulu"),
        question("u2_intro", 2, "my_name", "听一听露露的自我介绍。选出她介绍的内容。", [
            ("age", "Nine", "九岁"), ("name", "Lulu", "露露"),
            ("morning", "Morning", "早晨")], "name"),
        question("u2_polite", 2, "goodbye", "放学要离开了，选一句向朋友告别的话。", [
            ("name", "What's your name?", "你叫什么名字？"), ("hello", "Hello!", "你好！"),
            ("bye", "Goodbye.", "再见。")], "bye"),
        question("u3_age", 3, "how_old", "朋友问年龄。请替九岁的露露选一句回答。", [
            ("name", "My name is Lulu.", "我叫露露。"), ("nine", "I'm nine.", "我九岁了。"),
            ("hello", "Hello!", "你好！")], "nine"),
        question("u3_nine", 3, "im_nine", "听一听，露露说自己几岁了？", [
            ("eight", "Eight", "八"), ("six", "Six", "六"), ("nine", "Nine", "九")], "nine"),
        question("u3_birthday", 3, "im_eight", "生日名牌上写着 8。请选出八岁的英语表达。", [
            ("eight", "I'm eight.", "我八岁了。"), ("nine", "I'm nine.", "我九岁了。"),
            ("name", "My name is Lulu.", "我叫露露。")], "eight"),
    ]


def build(source: Path, destination: Path):
    public = source / "public"
    library_path = public / "library.json"
    library = read_json(library_path)
    books = {}
    book_summaries = []
    for summary in library["books"]:
        path = safe_source_file(public, summary["url"])
        data = read_json(path)
        books[data["id"]] = data
        book_summaries.append({
            "id": data["id"], "title": summary["title"], "grade": data["grade"],
            "volume": data["volume"], "edition": data["edition"],
            "page_count": len(data["pages"]), "unit_count": sum(
                c["id"].startswith("unit-") for c in data["chapters"]),
            "manifest": summary["url"], "manifest_sha256": sha256(path),
            "source_pdf_sha256": data.get("sourceSha256"),
            "playable_scope": ("opening_three_units" if data["id"] == G3 else
                               "life_preview_only" if data["id"] in {"xiangshao-g3-2", "xiangshao-g4-1"}
                               else "indexed_only"),
        })
    phrases, audio_files = {}, []
    audio_dir = destination / "assets" / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    for key, book_id, page_id, region_id, text, zh in PHRASE_SPECS:
        book = books[book_id]
        page = next(p for p in book["pages"] if p["id"] == page_id)
        region = next(r for r in page["regions"] if r["id"] == region_id)
        if region["text"] != text:
            raise ValueError(f"Source text changed: {book_id}/{region_id}")
        cache = safe_source_file(public, region["audio"])
        if not cache.exists() or cache.stat().st_size < 128:
            raise FileNotFoundError(f"Missing cached audio for {key}; no online fallback")
        if book.get("speechProfile") != PROFILE or not region["audio"].startswith("/audio/edge-jenny-v1/"):
            raise ValueError(f"Unexpected audio provenance for {key}")
        target = audio_dir / f"{key}.mp3"
        if not target.exists() or sha256(target) != sha256(cache):
            shutil.copyfile(cache, target)
        opening = book_id == G3 and page["chapter"] in ("unit-1", "unit-2", "unit-3")
        phrases[key] = {
            "en": text, "zh": zh, "audio": f"res://assets/audio/{key}.mp3",
            "role": "core" if opening else "life_preview",
            "translation_kind": "authored_gloss",
            "source": {
                "book_id": book_id, "page": page["printedPage"], "file_page": page_id,
                "region_id": region_id, "chapter_id": page["chapter"],
                "kind": "textbook_exact", "source_text": text,
                "source_verified_in_manifest": region.get("sourceVerified", False),
            },
            "audio_kind": "cached_synthetic_speech", "voice": "en-US-JennyNeural",
        }
        audio_files.append({
            "phrase_id": key, "path": f"assets/audio/{key}.mp3", "source_cache": region["audio"],
            "sha256": sha256(target), "source_sha256": sha256(cache), "bytes": target.stat().st_size,
            "kind": "cached_synthetic_speech", "profile": PROFILE,
        })
    units = []
    for number, title, zh, start, end, phrase_keys, question_ids in UNIT_SPECS:
        chapter = next(c for c in books[G3]["chapters"] if c["id"] == f"unit-{number}")
        if (chapter["start"], chapter["end"]) != (start, end):
            raise ValueError(f"Unit {number} source page range changed")
        units.append({
            "id": f"unit{number}", "number": number, "title": title, "zh": zh,
            "source": {"book_id": G3, "chapter_id": chapter["id"],
                       "page_start": chapter["printedStart"],
                       "page_end": chapter["printedStart"] + end - start,
                       "file_page_start": start, "file_page_end": end, "kind": "textbook_sequence"},
            "phrase_keys": phrase_keys, "question_ids": question_ids,
        })
    data = {
        "schema_version": 1,
        "title": "小镇英语 · 开场三课",
        "coverage": {
            "library_books_indexed": len(book_summaries), "playable_book_id": G3,
            "playable_units": [1, 2, 3], "full_curriculum_implemented": False,
            "note": "首版仅实装三年级上册开场三个单元中的核心表达与九个新编情境题；不代表完整单元覆盖。生活词汇为额外预览，不计入主线过关。",
        },
        "source_books": book_summaries, "units": units, "phrases": phrases,
        "questions": make_questions(phrases),
        "assessment_policy": {
            "independent": "首次作答正确，且本题未打开中文提示或接受答案辅助。",
            "assisted": "打开中文提示、答案辅助或错后重试所得的正确结果。",
            "audio_replay_is_assistance": False,
            "note": "数据仅声明记录口径，实际记录与解锁逻辑由游戏状态模块执行；九题不构成标准化水平测评。",
        },
    }
    write_json(destination / "data" / "curriculum.json", data)
    manifest = {
        "schema_version": 1, "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "source_library_manifest": "public/library.json", "source_library_sha256": sha256(library_path),
        "curriculum_sha256": sha256(destination / "data" / "curriculum.json"),
        "audio_count": len(audio_files), "audio_kind": "cached_synthetic_speech",
        "voice": "en-US-JennyNeural", "rate": "-10%", "network_required_at_runtime": False,
        "files": audio_files,
    }
    write_json(destination / "data" / "content_manifest.json", manifest)
    return verify(source, destination)


def verify(source: Path, destination: Path):
    data_path = destination / "data" / "curriculum.json"
    data = read_json(data_path)
    manifest = read_json(destination / "data" / "content_manifest.json")
    if sha256(data_path) != manifest["curriculum_sha256"]:
        raise ValueError("Curriculum checksum mismatch")
    if [u["number"] for u in data["units"]] != [1, 2, 3]:
        raise ValueError("Opening progression changed")
    seen = set()
    for question in data["questions"]:
        assert question["id"] not in seen, "Duplicate question ID"
        seen.add(question["id"])
        assert question["answer"] in [c["id"] for c in question["choices"]]
        assert question["audio"] in data["phrases"]
        assert question["source"]["book_id"] == G3
        assert question["source"]["chapter_id"] == f"unit-{question['unit']}"
    for unit in data["units"]:
        assert set(unit["question_ids"]) == {q["id"] for q in data["questions"] if q["unit"] == unit["number"]}
    for entry in manifest["files"]:
        local = destination / entry["path"]
        cache = safe_source_file(source / "public", entry["source_cache"])
        if sha256(local) != entry["sha256"] or sha256(cache) != entry["source_sha256"]:
            raise ValueError(f"Audio hash mismatch: {entry['phrase_id']}")
        if sha256(local) != sha256(cache):
            raise ValueError(f"Copied audio differs from original: {entry['phrase_id']}")
    for phrase in data["phrases"].values():
        anchor = phrase["source"]
        book = read_json(source / "public" / "books" / f"{anchor['book_id']}.json")
        page = next(p for p in book["pages"] if p["id"] == anchor["file_page"])
        region = next(r for r in page["regions"] if r["id"] == anchor["region_id"])
        assert page["printedPage"] == anchor["page"] and region["text"] == phrase["en"]
        assert (destination / phrase["audio"].removeprefix("res://")).is_file()
    result = {"status": "ok", "books_indexed": len(data["source_books"]),
              "playable_units": len(data["units"]), "questions": len(data["questions"]),
              "phrases": len(data["phrases"]), "audio_files": len(manifest["files"]),
              "audio_bytes": sum(x["bytes"] for x in manifest["files"])}
    print(json.dumps(result, ensure_ascii=False))
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path(r"D:\Project\Englishbook"))
    parser.add_argument("--destination", type=Path, default=ROOT / "game")
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    (verify if args.verify_only else build)(args.source, args.destination)

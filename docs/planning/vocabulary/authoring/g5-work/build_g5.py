"""Rebuild the grade-5 planning data. Reads source manifests; writes only authoring/g5*.

Rows and actions are individually authored transcripts/storyboards, not generated
from a common story template. This script attaches source evidence and validates
position counts without rewriting source material.
"""
from __future__ import annotations
import json
import re
import unicodedata
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
PUBLIC = Path(r"D:\Project\Englishbook\public")
BOOK_IDS = {1: "english-grade5-volume1-smartedu-2022", 2: "xiangshao-g5-2"}
SOURCES = {v: json.loads((PUBLIC / "books" / f"{bid}.json").read_text(encoding="utf-8-sig")) for v, bid in BOOK_IDS.items()}
LEVELS = {"w": "listen_speak_read_write", "r": "recognition", "b": "listen_speak_read", "l": "listen_speak"}
LEVEL_NOTES = {
    1: "Word List 注：黑体词要求学生能听、说、读、写；蓝体词只作认读要求。",
    2: "Word List II 注：黑体单词要求学生能听、说、认读；白体单词只作听、说要求。"
}
PRIMARY_OVERRIDES = {
    (2, 77, "a box of"): ["p77-r8", "p77-r6"],
    (2, 77, "a piece of"): ["p77-r10", "p77-r9"],
    (2, 77, "bus stop"): ["p77-r40", "p77-final-stop"],
    (2, 77, "floor"): ["p77-r45"],
    (2, 79, "on time"): ["p79-r17", "p79-r16"],
    (2, 79, "over there"): ["p79-r20", "p79-r19"],
    (2, 79, "shopping centre"): ["p79-r33", "p79-r34"],
    (2, 79, "put on"): ["p79-r36", "p79-r37"],
}
SECONDARY_OVERRIDES = {
    (2, 75, "over there"): ["p75-r10"],
    (2, 75, "get on"): ["p75-r41", "p75-r43"],
    (2, 75, "there"): ["p75-r42"],
}

def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text.replace("’", "'").replace("‘", "'")).strip()

def contains_word(text: str, spelling: str) -> bool:
    return bool(re.search(r"(?<![A-Za-zÀ-ž])" + re.escape(normalize(spelling)) + r"(?![A-Za-zÀ-ž])", normalize(text)))

def matching_regions(page: dict, spelling: str) -> list[str]:
    exact = [r["id"] for r in page["regions"] if normalize(r["text"]) == normalize(spelling)]
    if exact:
        return exact
    return [r["id"] for r in page["regions"] if contains_word(r["text"], spelling)]

def letter_count(word: str) -> int:
    return sum(c.isalpha() for c in word)

def primary_source(volume: int, page: dict, spelling: str, meaning: str, lesson: int) -> dict:
    ids = PRIMARY_OVERRIDES.get((volume, page["id"], spelling), matching_regions(page, spelling))
    return {
        "file_page": page["id"], "page": page["printedPage"], "region_ids": ids,
        "row_label": spelling + " " + meaning, "listed_lesson_page": lesson,
        "section": "Word List" if volume == 1 else "Word List II",
        "image": page["image"], "image_only_row": not ids,
        "visual_review": "assistant_page_image_checked",
        "evidence_note": ("原JSON漏行；依据本次实际页面图逐行抄录。" if not ids else
                          "印刷行与译义对照实际页面图；region可覆盖多行，须结合row_label定位。"),
    }

def topical_map(volume: int) -> dict[str, list[dict]]:
    result: dict[str, list[dict]] = {}
    current_unit = None
    pages = [p for p in SOURCES[volume]["pages"] if (75 <= p["id"] <= 77 if volume == 1 else 74 <= p["id"] <= 76)]
    for page in pages:
        for col in (0, 1):
            for r in sorted((r for r in page["regions"] if int(r["rect"][0] >= .5) == col), key=lambda r: (r["rect"][1], r["rect"][0])):
                heading = re.fullmatch(r"Unit (\d+)", r["text"].strip())
                if heading:
                    current_unit = int(heading.group(1))
                result.setdefault(r["id"], []).append({"file_page": page["id"], "page": page["printedPage"], "unit": current_unit, "region": r})
    return result

def chapter_at(volume: int, printed: int) -> int | None:
    for ch in SOURCES[volume]["chapters"]:
        if not ch["id"].startswith("unit-"):
            continue
        start = ch.get("printedStart", next(p["printedPage"] for p in SOURCES[volume]["pages"] if p["id"] == ch["start"]))
        end = start + ch["end"] - ch["start"]
        if start <= printed <= end:
            return int(ch["id"].split("-")[1])
    return None

rows = []
for line in (HERE / "rows.tsv").read_text(encoding="utf-8").splitlines():
    if not line or line.startswith("#"):
        continue
    cols = line.split("|")
    volume, page, spelling, meaning, lesson, level = cols[:6]
    rows.append({"volume": int(volume), "file_page": int(page), "spelling": spelling, "meaning": meaning,
                 "lesson": int(lesson), "level": level, "unit": int(cols[6]) if len(cols) > 6 else None})

stories = {}
meanings = {}
for row in rows:
    meanings.setdefault(row["spelling"], []).append(row["meaning"])
for line in (HERE / "stories.tsv").read_text(encoding="utf-8").splitlines():
    if not line or line.startswith("#"):
        continue
    spelling, setting, actions, transfer = line.split("|")
    assert spelling not in stories, spelling
    steps = actions.split("/")
    assert len(steps) == letter_count(spelling), (spelling, len(steps), letter_count(spelling))
    repeated = [letter for letter, count in Counter(normalize(spelling).lower()).items() if letter.isalpha() and count > 1]
    stories[spelling] = {
        "meaning_anchor": "目标义项：" + "；".join(dict.fromkeys(meanings[spelling])) + "。本条分镜以" + setting + "中的具体事件联结含义。",
        "setting": setting,
        "actions": steps,
        "transfer": transfer,
        "contrast": ("重复字母 " + ", ".join(repeated) + " 保留各自位置与第几次出现；" if repeated else "") +
                    "固定地标只编码字母顺序；不能用本故事推导词源、读音或语法。",
    }

books = []
image_only_rows = []
for volume, bid in BOOK_IDS.items():
    entries = []
    source_book = SOURCES[volume]
    pages_by_id = {p["id"]: p for p in source_book["pages"]}
    tm = topical_map(volume)
    for row in (r for r in rows if r["volume"] == volume):
        spelling, meaning, page_id = row["spelling"], row["meaning"], row["file_page"]
        source = primary_source(volume, pages_by_id[page_id], spelling, meaning, row["lesson"])
        if row["unit"] is not None:
            source["listed_unit_number"] = row["unit"]
        if source["image_only_row"]:
            image_only_rows.append({"book_id": bid, "spelling": spelling, "file_page": page_id})
        sources = [source]
        top_units = set()
        for p in source_book["pages"]:
            if not (75 <= p["id"] <= 77 if volume == 1 else 74 <= p["id"] <= 76):
                continue
            ids = SECONDARY_OVERRIDES.get((volume, p["id"], spelling), matching_regions(p, spelling))
            if not ids:
                continue
            # Do not treat explanatory base forms in was/were glosses as new entries.
            if spelling in {"am", "is", "are"}:
                continue
            unit_values = [v["unit"] for rid in ids for v in tm.get(rid, []) if v["unit"]]
            top_units.update(unit_values)
            sources.append({"file_page": p["id"], "page": p["printedPage"], "region_ids": ids,
                            "row_label": spelling + " " + meaning, "listed_lesson_page": None,
                            "section": "Vocabulary" if volume == 1 else "Word List I", "image": p["image"],
                            "image_only_row": False, "visual_review": "assistant_page_image_checked",
                            "topical_unit_numbers": sorted(set(unit_values))})
        # Formal term is one exact row; a substring within a longer term does not add a second unit.
        unit = row["unit"] if row["unit"] is not None else chapter_at(volume, row["lesson"])
        units = sorted(top_units | ({unit} if unit else set()))
        notes = []
        if top_units and unit and unit not in top_units:
            notes.append("字母表引用页与单元表归属不完全一致；同时保留表内引用和单元表定位，不改教材页号。")
        if spelling == "café":
            notes.append("é是教材拼写；按一个E形象编码，重音符号单独保留，不规范成cafe。")
        if spelling == "beef" and volume == 1:
            notes.append("Word List印刷71页标注课文页3；Vocabulary列于Unit 2。原样保留这一教材内部引用差异，待编辑核查课文索引。")
        if spelling in {"was", "were"}:
            notes.append("释义中的is/am/are是语法说明，不单独算该表的新增词条。")
        proper = spelling in {"London", "New York", "Indian", "Mrs", "the Spring Festival", "the Great Wall", "the West Lake",
                                "International Children's Day", "Mother's Day", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
        kind = "proper_name" if proper else "contraction" if "'" in spelling else "phrase" if " " in spelling else "word"
        group, relation = spelling, None
        variants = {
            "chip": ("chip (pl. chips)", "base"), "chips": ("chip (pl. chips)", "plural"),
            "glass": ("glass (pl. glasses)", "base"), "glasses": ("glass (pl. glasses)", "plural_and_lexicalized_plural"),
            "regard": ("regard (pl. regards)", "base"), "regards": ("regard (pl. regards)", "plural"),
            "shoe": ("shoe (pl. shoes)", "base"), "shoes": ("shoe (pl. shoes)", "plural"),
            "sock": ("sock (pl. socks)", "base"), "socks": ("sock (pl. socks)", "plural"),
            "I'd like": ("I'd like=I would like", "contraction"), "I would like": ("I'd like=I would like", "expansion"),
            "don't": ("don't=do not", "contraction"), "do not": ("don't=do not", "expansion"),
            "I'll": ("I'll=I will", "contraction"), "I will": ("I'll=I will", "expansion"),
        }
        if spelling in variants:
            group, relation = variants[spelling]
        if spelling == "glass":
            notes.append("原行合列玻璃杯与眼镜：本条仅玻璃杯；眼镜义分配给glasses，不将单数glass误释为眼镜。")
        entries.append({"spelling": spelling, "meaning_zh": meaning, "kind": kind,
                        "requirement": LEVELS[row["level"]], "requirement_note": LEVEL_NOTES[volume],
                        "sources": sources, "unit_numbers": units, "surface_group": group,
                        "variant_relation": relation, "notes": "；".join(notes)})
    assert len(entries) == len({e["spelling"] for e in entries}), bid
    reviewed = list(range(75, 82)) if volume == 1 else list(range(74, 81))
    books.append({"book_id": bid, "visual_reviewed_file_pages": reviewed, "entries": entries,
                  "exclusions": [
                      {"kind": "table_metadata", "description": "表头、Page、Unit、字母分栏、pl.和等号为说明符，均不作为独立词条。"},
                      {"kind": "grammatical_gloss", "description": "was/were释义中的is/am/are不计新增词条。"} if volume == 2 else
                      {"kind": "outside_formal_wordlist", "description": "本册课文中未列入正式词表的任意英文片段不自动收词。"}
                  ], "corrections": []})

for book in books:
    if book["book_id"] == BOOK_IDS[2]:
        book["exclusions"].extend([
            {"file_page": 76, "region_id": "p76-r29", "reason": "Word List I中were释义为are的过去式；are属释义说明，非独立表头词条。"},
            {"file_page": 76, "region_id": "p76-r34", "reason": "Word List I中was释义为is、am的过去式；is属释义说明，非独立表头词条。"},
            {"file_page": 76, "region_id": "p76-r36", "reason": "Word List I中was释义为is、am的过去式；am属释义说明，非独立表头词条。"},
            {"file_page": 80, "region_id": "p80-r12", "reason": "Word List II中was一行的释义片段am，不是独立新增词。"},
            {"file_page": 80, "region_id": "p80-r21", "reason": "Word List II中were一行的释义片段are，不是独立新增词。"},
        ])

# Meaning branches remain under the same fixed story location and spelling key.
branches = {
    "fan": [{"meaning_zh": "扇子", "book_id": BOOK_IDS[2], "setting": stories["fan"]["setting"],
             "actions": ["把应援旗折成扇面", "握住扇柄扇出凉风", "把扇子放进原来应援角的巢形小格"],
             "transfer": "新夏日礼物任务按fan取扇子；足球迷情境复用原故事的应援旗分支，听语境选义。"}],
    "take": [{"meaning_zh": "乘（车/船/飞机等）", "book_id": BOOK_IDS[2], "setting": stories["take"]["setting"],
              "actions": ["载着带好的行李停到车门", "滚上停稳的交通工具", "拉好乘客模型安全带", "把乘车图贴到同一出发垫旁"],
              "transfer": "新出行指令take a bus时选择乘公交；take a book to school时选择带物，不重置固定出发地点。"}],
    "show": [{"meaning_zh": "演示；节目／展示；给……看", "book_id": BOOK_IDS[2],
              "transfer": "五下把风筝展示给伙伴；五上整段展示可作为节目。沿用同一展示台与逐字母动作。"}],
    "glasses": [{"meaning_zh": "玻璃杯的复数形式", "book_id": BOOK_IDS[1],
                 "actions": ["托起一只透明水杯", "照见杯内的水", "滚来第二只相同水杯", "把两杯分开放稳", "再看确实有多只杯", "将杯子放入壳形托盘", "把复数杯子图挂在眼镜盒旁的对比卡上"],
                 "transfer": "在明确two glasses of water的情境中交付两杯水；在戴着眼镜的语境中选眼镜。"}],
    "old": [{"meaning_zh": "年老的", "transfer": "沿用新旧相册台，在相册年龄线上找到年长人物；只描述年龄，不贬低能力或价值。"}],
    "may": [{"meaning_zh": "可能", "transfer": "沿用借玩具角的许可卡，旁加尚未确定的天气卡；may rain表示可能，不能据此断言一定下雨。"}],
    "little": [{"meaning_zh": "小的", "transfer": "沿用量杯场景，把小杯与大杯并排比较大小；水量义看水线，小的义看杯体。"}],
    "short": [{"meaning_zh": "矮的", "transfer": "沿用长短尺位置，换为同尺度站直的人物模型比较身高；不把身高当优劣。"}],
    "work": [{"meaning_zh": "工作", "book_id": BOOK_IDS[2], "transfer": "沿用修理运转台，看人物正在承担修理工作，区别机器运行状态。"}],
    "email": [{"meaning_zh": "电子邮件（名词）", "book_id": BOOK_IDS[2], "transfer": "沿用电子信箱屏，指已收到的一封邮件；五上发送动作则对应动词义。"}],
    "new": [{"meaning_zh": "新来的", "transfer": "沿用新旧物比较台，换成欢迎新同学的名牌；判断刚加入的身份而非物品使用痕迹。"}],
    "back": [{"meaning_zh": "回应", "actions": ["载着收到的问候返回出发点", "把自己的答复滚到对方面前", "端出回复卡", "用风筝线把来问与回复连接"],
              "transfer": "沿用回家入口垫的往返箭头，换成消息发来再回复；say back等表达按教材句子呈现。"}],
    "eraser": [{"meaning_zh": "黑板擦", "actions": ["把壳上的错误粉笔字朝上", "握住黑板擦轻轻擦", "滚出掉下的粉笔灰模型", "扫一扫露出干净板面", "对照错误已经消失", "把黑板擦放回板槽"],
                "transfer": "沿用改错垫，换新黑板书写面时选择黑板擦；纸面仍选择橡皮。"}],
    "visit": [{"meaning_zh": "参观", "actions": ["从山台出发带上参观卡", "滑到博物馆入口", "轻按入场星钮", "按参观路线看展品", "把参观记录装上车"],
               "transfer": "沿用访客门的行程，换成博物馆参观分支；不重建字母锚点。"}],
    "think": [{"meaning_zh": "认为", "transfer": "沿用思考垫，在人物特点图旁提出自己的看法并说明看到的依据；不将看法自动视为事实。"}],
    "with": [{"meaning_zh": "用……", "actions": ["摆尾铺平要剪的纸", "滑出指定剪刀模型", "运来需要使用的工具", "抬帽指明用这件工具完成操作"],
              "transfer": "沿用合作制作桌，cut with scissors突出使用工具；with my friend突出和某人一起。"}],
}
for word, extension in branches.items():
    stories[word]["sense_extensions"] = extension
    for branch in extension:
        branch.setdefault("meaning_anchor", "分支目标义项：" + branch["meaning_zh"] + "。" + branch["transfer"])
        branch.setdefault("setting", stories[word]["setting"])
        if "actions" in branch:
            assert len(branch["actions"]) == letter_count(word), word

for book in books:
    volume = 1 if book["book_id"] == BOOK_IDS[1] else 2
    missing = [row for row in image_only_rows if row["book_id"] == book["book_id"]]
    book["corrections"] = [
        {"type": "ocr_omitted_row", **row, "resolution": "依据已查看的页面图补录；无虚构region ID。"} for row in missing
    ]
    if volume == 2:
        book["corrections"].extend([
            {"type": "ocr_split_phrase", "terms": ["a box of", "a piece of", "bus stop", "on time", "over there", "shopping centre", "put on", "get on"],
             "resolution": "按页面同一印刷行恢复词组；全部源region保留或注明部分缺字。"},
            {"type": "unicode_preserved", "term": "café", "resolution": "保留é，字母编码归E，重音单独处理。"},
            {"type": "ocr_wrong_word", "term": "floor", "file_page": 77, "region_ids": ["p77-r45"],
             "source_text": "door", "resolution": "实际页面印刷为floor；源JSON误识door，在策划词表中改正，源文件不回写。"},
            {"type": "gloss_not_entry", "terms": ["are", "is", "am"], "resolution": "was/were释义中的基础形式不误计新增词条。"},
        ])
    else:
        book["corrections"].extend([
            {"type": "plural_expansion", "terms": ["chip/chips", "glass/glasses", "regard/regards", "shoe/shoes", "sock/socks"],
             "resolution": "保留括号中的完整复数拼写目标并关联同一原始表面行。"},
            {"type": "source_reference_discrepancy", "term": "beef", "resolution": "字母表标页3，单元表在Unit 2；两者原样保留待编辑复核。"},
        ])

result = {"grade": 5, "books": books, "stories": stories,
          "review": {"assistant_visual_pages": 14, "editorial_human_review": "pending", "child_trial": "not_conducted",
                     "runtime_implemented": False, "voice_generation": "not_performed"}}
# Retain the original manifest assertions as evidence values, never as our review status.
for book in books:
    volume = 1 if book["book_id"] == BOOK_IDS[1] else 2
    for entry in book["entries"]:
        for source in entry["sources"]:
            page = next(p for p in SOURCES[volume]["pages"] if p["id"] == source["file_page"])
            regions = {r["id"]: r for r in page["regions"]}
            source["manifest_region_evidence"] = [
                {"region_id": rid, "raw_text": regions[rid]["text"],
                 "source": regions[rid].get("source"), "sourceVerified": regions[rid].get("sourceVerified"),
                 "reviewed": regions[rid].get("reviewed"), "sourceIds": regions[rid].get("sourceIds", [])}
                for rid in source["region_ids"]
            ]
            source["source_surface"] = entry["surface_group"]
output = HERE.parent / "g5.json"
output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
assert set(stories) == {r["spelling"] for r in rows}
for book in books:
    for entry in book["entries"]:
        source_book = SOURCES[1 if book["book_id"] == BOOK_IDS[1] else 2]
        for source in entry["sources"]:
            page = next(p for p in source_book["pages"] if p["id"] == source["file_page"])
            assert source["page"] == page["printedPage"]
            assert all(rid in {r["id"] for r in page["regions"]} for rid in source["region_ids"])

summary = {"book_counts": {b["book_id"]: len(b["entries"]) for b in books}, "unique_spellings": len(stories),
           "letter_actions": sum(len(s["actions"]) for s in stories.values()), "image_only_rows": image_only_rows,
           "levels": {b["book_id"]: dict(Counter(e["requirement"] for e in b["entries"])) for b in books}}
(HERE / "build-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(summary, ensure_ascii=False, indent=2))

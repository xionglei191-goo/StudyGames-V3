"""Derive planning-only mainline adapters from the vocabulary source catalog.

Writes only inside docs/planning/vocabulary. It does not author new stories,
assign a textbook character by name, or bind thousands of pages to SG nodes.
"""
from __future__ import annotations
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path

SCHEMA = "vocabulary-mainline-adapter-v1"
PROMPTS = [
    (0, "H0", "自主", "unassisted_attempt"),
    (1, "H1", "位置与意义", "location_and_meaning"),
    (2, "H2", "第一步", "first_step"),
    (3, "H3", "缺口接续", "gap_completion"),
    (4, "H4", "逐步搭桥", "step_bridge"),
    (5, "H5", "完整示范", "full_demonstration"),
]
REQUIREMENTS = {
    "listen_speak_read_write": {
        "curriculum_task_dimensions": ["meaning", "listening", "spoken_expression", "written_recognition", "orthography"],
        "formal_spelling_eligible": True,
        "display_note": "本册听说读写；可提供书写练习，但不是章节通行条件。",
    },
    "recognition": {
        "curriculum_task_dimensions": ["meaning", "written_recognition"],
        "formal_spelling_eligible": False,
        "display_note": "本册仅认读；不自动安排拼写测验，故事与字母链仅作可选支持。",
    },
    "listen_speak_read": {
        "curriculum_task_dimensions": ["meaning", "listening", "spoken_expression", "written_recognition"],
        "formal_spelling_eligible": False,
        "display_note": "本册听说认读；不升级为四会或强制书写。",
    },
    "listen_speak": {
        "curriculum_task_dimensions": ["meaning", "listening", "spoken_expression"],
        "formal_spelling_eligible": False,
        "display_note": "本册仅听说；文字和故事可选，不自动升级认读或拼写验收。",
    },
    "not_distinguished": {
        "curriculum_task_dimensions": ["meaning"],
        "formal_spelling_eligible": False,
        "display_note": "原表要求未区分；先保留理解与支持，正式读写要求待编辑核定。",
    },
}
for _permission in REQUIREMENTS.values():
    _permission.update({
        "spelling_required_for_story_progress": False,
        "mnemonic_story_optional": True,
        "extra_practice_is_not_curriculum_requirement": True,
        "audio_task_requires_reviewed_available_whole_word_audio": True,
        "automatic_pronunciation_score_available": False,
    })

PROMPT_CONTRACT = {
    "schema_version": "support-evidence-v1",
    "levels": [{"level": n, "id": h, "name": name, "support_kind": kind} for n, h, name, kind in PROMPTS],
    "help_direction": "H0 -> H5",
    "demonstration_fade_direction": "H5 -> H0",
    "highest_level_is_mastery": False,
    "level_zero_implies_independent": False,
    "child_requested_replay_still_counts_as_cue": True,
    "required_attempt_fields": [
        "invocation_id", "attempt_id", "task_mode", "target_dimension",
        "declared_stimulus", "answer_visible_at_start", "cue_events",
        "first_response", "later_response", "observation_status",
    ],
    "cue_event_fields": [
        "event_id", "shown_at", "requested_by", "support_level",
        "support_kind", "asset_or_content_ref", "revealed_letter_positions",
        "answer_revealing_dimensions",
    ],
    "task_modalities": [
        {"task_mode": "listen_and_select_meaning", "target_dimension": "meaning",
         "whole_word_audio_role": "declared_stimulus",
         "independence_limit": "正确答案物体的高亮、中文义项或示范动作是答案线索；无合格音频不记听力通过。"},
        {"task_mode": "dictation", "target_dimension": "orthography",
         "whole_word_audio_role": "declared_stimulus",
         "independence_limit": "完整词音可作合法题干；字母、字母图链、故事答案或拼写显示会辅助本次拼写。"},
        {"task_mode": "pronunciation_recall", "target_dimension": "spoken_expression",
         "whole_word_audio_role": "answer_support",
         "independence_limit": "播放目标读音后属于跟读/有辅助表达；本项目无自动口语评分，不生成发音分数。"},
        {"task_mode": "picture_to_spelling", "target_dimension": "orthography",
         "whole_word_audio_role": "additional_cue",
         "independence_limit": "题干可含实义图；额外目标声音、字母链或故事回看都记录，不能悄悄改成听写。"},
        {"task_mode": "written_word_recognition", "target_dimension": "written_recognition",
         "whole_word_audio_role": "additional_cue",
         "independence_limit": "印出的目标词是题干；中文答案、高亮正确物体或先播目标声音须按任务标为辅助。"},
        {"task_mode": "copy_visible_spelling", "target_dimension": "orthography",
         "whole_word_audio_role": "optional_exposure",
         "independence_limit": "看范例抄写单独记录，不等于撤去范例后的拼写回忆。"},
    ],
    "result_rule": "按任务模态与实际暴露线索判定每一维度；首次和帮助后响应分开。H0、主动求助、看过示范、退出重进均不能自动生成独立正确。",
    "unobserved_rule": "未测维度为null/未尝试；不可从看完故事、人物动作或学习意愿推断正确。",
}

ASSET_POLICY = {
    "status": "planning_not_runtime_verified",
    "representation_mode": "mnemonic_fantasy",
    "default_renderer": "card_storyboard",
    "optional_renderer": "small_tabletop_stage_after_prototype",
    "shared_codebook_asset_count": 26,
    "max_active_letter_instances_per_frame": 4,
    "max_visible_story_pages_per_group": 5,
    "full_chain_view": "可静态展开全部槽位；超过4个活动实例时不要求同屏播放全部动画。",
    "repeated_letters": "同一图像资源的独立位置实例，不新增模型或去重槽位。",
    "numeric_limits_status": "注意与制作预算草案，待设备和儿童试玩；不是性能或学习效果保证。",
    "story_specific_rig_required": False,
    "story_specific_film_required": False,
    "physics_simulation_required": False,
    "complex_action_fallback": "分镜定格/图层切换/简单节点移动。不能画清或含义有疑义则返回内容待制作，保留原故事位置及剧情继续路径。",
    "environment_rule": "记忆阅读/听题期间冻结环境表现时钟与非必要NPC动作；故事内部当前镜头按玩家操作播放。",
    "semantic_boundary": "先用准确实物/图示教义项；夸张动作只是助记想象，不作为动物解剖、物理、历史、地理、文化或NPC经历事实。",
    "npc_identity_rule": "codebook_R机器人不等于textbook_robbie，恐龙模型不等于textbook_dino，O猫头鹰不自动成为教材鸟类人物；任何具名演员需显式character_id和来源审校。",
    "proper_name_rule": "名称卡的地点/人物/文化事实素材另行核对；作者文字提到经核对的地图不证明该地图资产已经存在或已通过审校。",
}

def _read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))

def _hash(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()

def _write(root, relative, value):
    path = (root / relative).resolve()
    assert path.is_relative_to(root.resolve()), path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

def _letter_slots(tokens):
    result = []
    word_index = 1
    word_letter_index = 0
    for token in tokens:
        if token["type"] in {"space", "hyphen"}:
            word_index += 1
            word_letter_index = 0
        elif token["type"] == "letter":
            word_letter_index += 1
            result.append({
                "letter_index": token["letter_position"],
                "raw_char_index": token["surface_position"],
                "word_index": word_index,
                "word_letter_index": word_letter_index,
                "raw_character": token["raw"],
                "letter": token["letter"],
                "landmark": token["letter"],
                "occurrence": token["occurrence"],
                "anchor_en": token["anchor_en"],
                "anchor_zh": token["anchor_zh"],
                "diacritic": token.get("diacritic"),
            })
    return result

def build_integration_artifacts(catalog, manifests, root, project):
    prologue = _read(project / "docs/planning/mainline/alphabet_prologue.json")
    interiors = _read(project / "game/data/interiors_manifest.json")
    rooms = {r["room_id"]: set(r["validation"]["required_markers"]) for r in interiors["rooms"]}
    codebook = []
    for item in prologue["letters"]:
        letter = item["letter"]["uppercase"]
        source = catalog["landmarks"][letter]
        assert source["anchor_en"] == item["anchor"]["canonical_word"], (letter, "codebook mismatch")
        scene = item["scene_ref"]
        assert scene["learning_node"] in rooms[scene["room_id"]], (letter, "missing SG node")
        codebook.append({
            "letter": letter, "asset_identity": "codebook_" + letter,
            "anchor_en": source["anchor_en"], "legacy_anchor_zh": source["anchor_zh"],
            "canonical_word_zh": "鸡蛋" if letter == "E" else source["anchor_zh"],
            "representative_label_zh": "蛋壳（完整蛋形）" if letter == "E" else source["anchor_zh"],
            "landmark_room_id": scene["room_id"],
            "prologue_learning_node": scene["learning_node"],
            "representative_image_ref": item["anchor"]["representative_image_ref"],
            "node_binding_scope": "序章认识该固定形象的入口；不是每个词故事的存放位置。",
        })
    assert sorted(x["letter"] for x in codebook) == list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    codebook_revision = "codebook-" + _hash([{k: x[k] for k in ("letter", "asset_identity", "anchor_en", "representative_label_zh")} for x in codebook])[:16]
    lexemes = {x["id"]: x for x in catalog["lexemes"]}
    stories = {x["id"]: x for x in catalog["stories"]}
    for story in stories.values():
        assert [p["level"] for p in story["prompt_ladder"]] == list(range(6))
        for prompt, (_, h, name, kind) in zip(story["prompt_ladder"], PROMPTS):
            assert prompt["name"] == name
            prompt.update({"id": h, "support_kind": kind, "independence_inferred_from_level": False})
        story["representation_contract"] = {
            "mode": "mnemonic_fantasy", "npc_cast_implicit": False,
            "default_renderer": "card_storyboard", "max_active_letter_instances_per_frame": 4,
            "meaning_reference_review": "pending_human_editor",
            "facts_or_real_npc_biography": False,
        }
        story["storage"]["existing_scene_binding"] = None
        story["storage"]["binding_status"] = "persistent_content_index_not_existing_sg_node"
    for occurrence in catalog["occurrences"]:
        occurrence["entry_id"] = occurrence["id"]
        occurrence["unit_ids"] = ["unit-" + str(n) for n in occurrence["unit_numbers"]]
        valid_units = {c["id"] for c in manifests[occurrence["book_id"]]["chapters"] if c["id"].startswith("unit-")}
        assert set(occurrence["unit_ids"]) <= valid_units, (occurrence["id"], "unknown unit")
        occurrence["task_permissions"] = dict(REQUIREMENTS[occurrence["requirement"]])
    content_revision = "vocabulary-" + _hash({
        "lexemes": catalog["lexemes"], "stories": catalog["stories"],
        "occurrences": catalog["occurrences"], "source_manifest_hashes": [b["manifest_sha256"] for b in catalog["books"]],
        "prompt_contract": PROMPT_CONTRACT, "codebook_revision": codebook_revision,
    })[:16]
    entries = []
    unit_entries = defaultdict(list)
    for occurrence in catalog["occurrences"]:
        lexeme = lexemes[occurrence["lexeme_id"]]
        story = stories[occurrence["story_id"]]
        slots = _letter_slots(lexeme["tokens"])
        boundaries = [{"type": t["type"], "raw": t["raw"], "raw_char_index": t["surface_position"]}
                      for t in lexeme["tokens"] if t["type"] != "letter"]
        beats = [{"beat_id": story["id"] + "/frame-" + str(f["frame"]), "role": "encoding",
                  "order": f["frame"], "letter_positions": f["letter_positions"], "text": f["text"]}
                 for f in story["frames"]]
        assert [p for beat in beats for p in beat["letter_positions"]] == list(range(1, len(slots) + 1))
        assert all(len(beat["letter_positions"]) <= 4 for beat in beats)
        assert "".join(t["raw"] for t in lexeme["tokens"]) == occurrence["spelling"]
        supplemental = [{"beat_id": e["id"], "role": "sense_extension",
                         "ref_letter_positions": [s["letter_position"] for s in e["steps"]],
                         "meaning_zh": e["meaning_zh"], "book_ids": e["book_ids"],
                         "source_story_id": story["id"],
                         "narrative": e.get("narrative"), "frames": e.get("frames", [])}
                        for e in story.get("sense_extensions", []) if occurrence["book_id"] in e["book_ids"]]
        for extra in supplemental:
            assert extra["ref_letter_positions"] == list(range(1, len(slots) + 1))
        entry = {
            "entry_id": occurrence["id"], "provider_occurrence_id": occurrence["id"],
            "lexeme_id": occurrence["lexeme_id"], "sense_id": occurrence["story_id"], "story_id": occurrence["story_id"],
            "content_revision": content_revision, "codebook_revision": codebook_revision,
            "source_unit": {"book_id": occurrence["book_id"], "unit_ids": occurrence["unit_ids"]},
            "spelling_display": occurrence["spelling"], "meaning_zh": occurrence["meaning_zh"],
            "kind": occurrence["kind"], "requirement": occurrence["requirement"],
            "task_permissions": occurrence["task_permissions"], "source_ids": occurrence["source_ids"],
            "letter_slots": slots, "boundaries": boundaries,
            "reconstruction_tokens": lexeme["tokens"],
            "orthography_events": story["orthography_events"],
            "story_beats": beats, "supplemental_beats": supplemental,
            "narrative": story.get("narrative"),
            "memory_home": {
                "storage_slot": story["storage"]["storage_slot"],
                "root_location_label": story["storage"]["root_location"],
                "story_page": story["storage"]["story_page"],
                "existing_scene_binding": None,
                "host_mode": "persistent_memory_book",
                "authored_setting_is_real_scene": False,
            },
            "guidance": story["prompt_ladder"],
            "audio": occurrence["audio"], "review_status": occurrence["review"],
            "source_refs_are_word_list_locations": True,
            "runtime_invocation_requires_reviewed_content": True,
            "blocks_story_progress_if_skipped": False,
        }
        entries.append(entry)
        for unit_id in occurrence["unit_ids"]:
            unit_entries[(occurrence["book_id"], unit_id)].append(occurrence["id"])
    unit_index = [{"book_id": bid, "unit_id": chapter["id"], "entry_ids": unit_entries[(bid, chapter["id"])]}
                  for bid in [b["book_id"] for b in catalog["books"]]
                  for chapter in manifests[bid]["chapters"] if chapter["id"].startswith("unit-")]
    contract = {
        "schema_version": SCHEMA, "status": "planning_only",
        "content_revision": content_revision, "codebook_revision": codebook_revision,
        "source_catalog": "data/catalog.json", "adapted_entries": "data/mainline_entries.json",
        "id_mapping": {"entry_id": "occurrences.id (book/spelling/meaning occurrence)",
                       "lexeme_id": "occurrences.lexeme_id -> lexemes.id",
                       "sense_id": "occurrences.story_id -> stories.id",
                       "story_id": "occurrences.story_id",
                       "unit_ids": "occurrences.unit_numbers -> validated source chapter IDs unit-N",
                       "spelling_display": "occurrences.spelling",
                       "sources": "occurrences.source_ids -> catalog.sources",
                       "letter_slots": "lexemes.letter_chain plus token-derived word indexes",
                       "story_beats": "stories.frames, role=encoding",
                       "supplemental_beats": "stories.sense_extensions, role=sense_extension; reference existing positions",
                       "memory_home": "stories.storage persistent index; no automatic SG scene binding"},
        "selected_unit_rule": "调用source_unit.book_id必须相同，source_unit.unit_id必须属于entry.source_unit.unit_ids；空数组禁止自动分配章节，且未选词不代表教材单元全覆盖。",
        "source_location_rule": "sources.chapter_id是词表章节，不是教学单元；page是词表印刷页，file_page是文件页，listed_lesson_page是表内课文页，三者分开。",
        "index_base": 1,
        "raw_character_index_unit": "NFC-normalized Unicode code point, not byte offset",
        "word_index_rule": "空格与连字符后开始下一可视词段；撇号、缩略点、重音符号不重置。此段号是书写定位，不宣称词源/音节切分。",
        "reconstruction_rule": "按reconstruction_tokens.raw顺序拼接严格等于spelling_display；letter_slots不含标点，重音保留原字形并独立展示。",
        "encoding_rule": "只展开role=encoding的letter_positions，严格等于1..letter_count一次；supplemental_beats只引用已有位置，不重复算拼写。",
        "codebook": codebook, "prompt_contract": PROMPT_CONTRACT,
        "requirement_permissions": REQUIREMENTS, "asset_policy": ASSET_POLICY,
        "storage_contract": {
            "authority": "lexeme_id/story_id/storage_slot", "sg_memory_is_story_slot": False,
            "default_host": "固定回忆册页（拟开发）", "public_anchor_geometry_changes": False,
            "child_override": "另存儿童自选位置/故事及版本；不覆盖系统原页，迁移保留旧位置指向。",
            "revision_migration": "已有ID语义不静默变更；内容修订保存新版本。若词义/ID变更，提供显式迁移表，旧记录不能按新内容重解释。",
        },
        "npc_contract_ref": "../art/textbook_characters.json",
        "sample_entry_ids": {w: next(o["id"] for o in catalog["occurrences"] if o["spelling"] == w)
                             for w in ["nose", "book", "apple", "school", "dinosaur", "T-shirt", "café"]},
    }
    catalog.update({"schema_version": 2, "planning_version": "v2-narrative" if catalog.get("narrative_revision") else "v1.1-integration",
                    "content_revision": content_revision, "codebook_revision": codebook_revision,
                    "integration_contract": "data/integration_contract.json"})
    adapted = {"schema_version": SCHEMA, "status": "planning_only",
               "content_revision": content_revision, "codebook_revision": codebook_revision,
               "entries": entries, "unit_index": unit_index}
    counts = Counter(o["requirement"] for o in catalog["occurrences"])
    report = {
        "status": "passed", "schema_version": SCHEMA,
        "entry_count": len(entries), "lexeme_count": len(lexemes), "sense_story_count": len(stories),
        "unit_count": len(unit_index), "unit_entry_relations": sum(len(x["entry_ids"]) for x in unit_index),
        "multi_unit_entries": sum(len(e["source_unit"]["unit_ids"]) > 1 for e in entries),
        "unassigned_entries": sum(not e["source_unit"]["unit_ids"] for e in entries),
        "requirement_counts": dict(counts), "formal_spelling_eligible_occurrences": counts["listen_speak_read_write"],
        "codebook_count": len(codebook), "source_sg_nodes_verified": len(codebook),
        "h_levels": list(range(6)), "maximum_letters": max(len(e["letter_slots"]) for e in entries),
        "maximum_frames": max(len(e["story_beats"]) for e in entries),
        "maximum_active_letters_per_frame": 4, "source_ids_preserved": True,
        "all_character_sequences_reconstruct": True, "all_encoding_positions_covered_once": True,
        "existing_map_scene_binding_count": 0,
        "content_revision": content_revision, "codebook_revision": codebook_revision,
        "runtime_test": "not_run_no_runtime_changes", "editorial_review": "pending", "child_trial": "not_conducted",
    }
    _write(root, "data/integration_contract.json", contract)
    _write(root, "data/mainline_entries.json", adapted)
    _write(root, "review/integration_validation.json", report)
    return report


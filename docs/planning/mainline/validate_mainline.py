"""Validate planning coverage against the readonly textbook and map sources.

This checks provenance and structure, not runtime behavior or learning outcomes.
It writes only validation_report.json alongside this script.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import re
import string
from urllib.parse import unquote


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def read(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-public", type=Path, default=Path(r"D:\Project\Englishbook\public"))
    options = parser.parse_args()
    checks = []
    warnings = []

    def check(name, condition, details=None):
        entry = {"name": name, "pass": bool(condition)}
        if details is not None:
            entry["details"] = details
        checks.append(entry)

    source = options.source_public.resolve()
    library = read(source / "library.json")
    books = {}
    actual_units = {}
    for summary in library["books"]:
        path = (source / summary["url"].lstrip("/")).resolve()
        if not path.is_relative_to(source):
            raise ValueError("Library manifest path escapes source public directory")
        book = read(path)
        books[book["id"]] = {"book": book, "path": path, "sha256": digest(path)}
        for unit in book["chapters"]:
            if unit["id"].startswith("unit-"):
                actual_units[(book["id"], unit["id"])] = unit

    check("source_book_count", len(books) == 8, len(books))
    check("source_unit_count", len(actual_units) == 81, len(actual_units))

    snapshot = read(HERE / "source_snapshot.json")
    check("library_unchanged_since_snapshot", digest(source / "library.json") == snapshot["source_library"]["sha256"])
    for book in snapshot["books"]:
        check("source_unchanged:" + book["book_id"], books[book["book_id"]]["sha256"] == book["sha256"])
    for file in snapshot["workspace_files"]:
        path = ROOT / file["path"]
        if not path.exists() or digest(path) != file["sha256"]:
            warnings.append({"kind": "workspace_changed_after_readonly_snapshot", "path": file["path"], "note": "Other active work can change code; this is not a runtime validation."})

    plan = read(ROOT / "game/data/landmark_interiors.json")
    alphabet_sources = {item["id"]: item for item in plan["landmarks"] if item["id"] in string.ascii_uppercase}
    rooms = set(plan["binding_contract"]["room_ids"]) | {"village"}
    prologue = read(HERE / "alphabet_prologue.json")
    letters = prologue["letters"]
    check("prologue_26_unique_letters", [item["letter"]["uppercase"] for item in letters] == list(string.ascii_uppercase))
    check("prologue_order", [item["order"] for item in letters] == list(range(1, 27)))
    for item in letters:
        letter = item["letter"]["uppercase"]
        expected = alphabet_sources[letter]
        ref = item["scene_ref"]
        check("letter_case:" + letter, item["letter"]["lowercase"] == letter.lower())
        check("letter_anchor:" + letter, item["anchor"]["canonical_word"].casefold() == expected["english_word"].casefold())
        check("letter_room:" + letter, ref["room_id"] == expected["room_id"])
        anchor_map = {anchor["node_name"]: anchor["label"] for anchor in expected["anchors"]}
        check("letter_existing_anchor:" + letter, ref["learning_node"] in anchor_map)
        check("letter_anchor_label:" + letter, anchor_map.get(ref["learning_node"]) == ref["learning_point_label"])
        check("letter_assistance_allowed:" + letter, item["micro_action"]["assisted_or_demonstrated_completion_allowed"] is True)
        check("letter_not_26_separate_minigames:" + letter, item["micro_action"]["separate_full_minigame_required"] is False)
    district_letters = [district["letters"] for district in prologue["districts"]]
    check("district_groups", district_letters == [list("ABCDEF"), list("GHIJK"), list("LMNOP"), list("QRSTU"), list("VWXYZ")])
    contract = prologue["completion_contract"]
    check("complete_26_experiences", contract["hard_required_letter_count"] == 26)
    accepted_modes = set(contract["accepted_completion_modes"])
    check("supported_completion_modes", {"hinted_action", "companion_action", "demonstration_viewed"}.issubset(accepted_modes))

    arcs = read(HERE / "curriculum_arcs.json")
    units = arcs["units"]
    keys = [(unit["book_id"], unit["unit_id"]) for unit in units]
    check("81_unique_unit_mappings", len(keys) == len(set(keys)) == 81)
    check("all_source_units_mapped", set(keys) == set(actual_units), {"missing": ["/".join(k) for k in sorted(set(actual_units) - set(keys))], "extra": ["/".join(k) for k in sorted(set(keys) - set(actual_units))]})
    evidence_counts = Counter()
    for item in units:
        key = (item["book_id"], item["unit_id"])
        book_record = books[key[0]]
        source_book = book_record["book"]
        expected = actual_units[key]
        label = "/".join(key)
        check("unit_key:" + label, item["source_unit_key"] == label)
        check("unit_title:" + label, item["source_title"] == expected["title"])
        check("unit_edition:" + label, item["edition"] == source_book["edition"])
        origin = item["source"]
        check("unit_source_hash:" + label, origin["manifest_sha256"] == book_record["sha256"])
        check("unit_file_pages:" + label, origin["file_pages"]["start"] == expected["start"] and origin["file_pages"]["end"] == expected["end"])
        pages = [page for page in source_book["pages"] if expected["start"] <= page["id"] <= expected["end"]]
        expected_printed = [page["printedPage"] for page in pages]
        printed = origin["printed_pages"]
        check("unit_printed_endpoints:" + label, printed["start"] == expected_printed[0] and printed["end"] == expected_printed[-1])
        check("unit_existing_rooms:" + label, bool(item["room_ids"]) and set(item["room_ids"]).issubset(rooms), sorted(set(item["room_ids"]) - rooms))
        for field in ["event_title", "player_goal", "actions", "world_change", "learning_goals", "completion", "pending_features"]:
            check("unit_content:" + label + ":" + field, bool(item.get(field)))
        check("unit_reuse_list:" + label, isinstance(item.get("prior_knowledge_reuse"), list))
        evidence_counts[origin["evidence_level"]] += 1

    # Cross-domain contracts use the built adapter rather than invented catalog fields.
    integration = read(HERE / "integration_contract.json")
    vocabulary = read(ROOT / "docs/planning/vocabulary/data/catalog.json")
    adapter = read(ROOT / "docs/planning/vocabulary/data/mainline_entries.json")
    vocabulary_contract = read(ROOT / "docs/planning/vocabulary/data/integration_contract.json")
    characters = read(ROOT / "docs/planning/art/textbook_characters.json")
    npc_plan = read(ROOT / "docs/planning/art/npc_animation_assets.json")
    entries = {item["entry_id"]: item for item in adapter["entries"]}
    occurrences = {item["id"]: item for item in vocabulary["occurrences"]}
    unit_index = {(item["book_id"], item["unit_id"]): item["entry_ids"] for item in adapter["unit_index"]}
    character_ids = {item["id"] for item in characters["characters"]}
    npc_ids = {item["id"] for item in npc_plan["characters"]}
    role_ids = {item["id"] for item in npc_plan["functional_role_slots"]}
    codebook = {item["letter"]: item for item in vocabulary_contract["codebook"]}
    check("adapter_schema", adapter["schema_version"] == integration["vocabulary_call"]["adapter_schema"] == vocabulary_contract["schema_version"])
    check("adapter_entry_identity", set(entries) == set(occurrences) and len(entries) == len(adapter["entries"]) == 1314)
    check("vocabulary_counts", (len(vocabulary["occurrences"]), len(vocabulary["lexemes"]), len(vocabulary["stories"])) == (1314, 1073, 1096))
    check("adapter_81_unit_index", set(unit_index) == set(actual_units))
    association_count = sum(len(value) for value in unit_index.values())
    check("adapter_association_count", association_count == integration["coverage"]["unit_vocabulary_associations"] == 1359)
    check("adapter_multi_unit_count", sum(len(item["source_unit"]["unit_ids"]) > 1 for item in entries.values()) == 45)
    for field in ("content_revision", "codebook_revision"):
        check("integration_revision:" + field, integration["vocabulary_call"][field] == adapter[field] == vocabulary_contract[field])
    support_projection = lambda rows: [(row["level"], row["id"], row["name"]) for row in rows]
    check("help_levels_H0_H5", support_projection(integration["assistance"]["levels"]) == support_projection(vocabulary_contract["prompt_contract"]["levels"]))
    check("h0_not_independent_by_label", integration["assistance"]["h0_opening_story_counts_as_help"] and not vocabulary_contract["prompt_contract"]["level_zero_implies_independent"])
    unassisted = set(integration["assistance"]["unassisted_attempt_requires"])
    independent_success = set(integration["assistance"]["independent_success_requires"])
    check("unassisted_attempt_can_be_incorrect", "first_response_correct" not in unassisted and "task_actual_response_observed" in unassisted and set(integration["assistance"]["unassisted_attempt_outcomes"]) == {"correct", "not_correct"})
    check("independent_success_adds_first_correct", independent_success == unassisted | {"first_response_correct"} and "independent_requires" not in integration["assistance"])
    for unit in units:
        key = (unit["book_id"], unit["unit_id"])
        join = unit["vocabulary_join"]
        label = "/".join(key)
        check("vocabulary_join:" + label, join["entry_ids"] == unit_index[key])
        check("vocabulary_join_versions:" + label, all(join[field] == adapter[field] for field in ("content_revision", "codebook_revision")))
        check("vocabulary_membership:" + label, all(entry_id in entries and entries[entry_id]["source_unit"]["book_id"] == key[0] and key[1] in entries[entry_id]["source_unit"]["unit_ids"] for entry_id in join["entry_ids"]))
        cast = unit["cast_binding"]
        expected_cast = {item["id"] for item in characters["characters"] if any(ref.get("book_id") == key[0] and ref.get("unit_id") == key[1] for ref in item["source_refs"])}
        check("source_cast_candidates:" + label, set(cast["source_character_candidates"]) == expected_cast)
        check("cast_review_boundary:" + label, cast["status"] == "source_candidates_only_event_cast_review_pending" and cast["automatic_cast_from_name_mentions"] is False)
        for binding in cast.get("planned_role_bindings", []):
            check("npc_binding:" + label + ":" + binding["role"], (binding.get("npc_id") in npc_ids) if "npc_id" in binding else binding.get("functional_role_slot_id") in role_ids)
    for item in letters:
        letter = item["letter"]["uppercase"]
        shared = codebook[letter]
        check("shared_codebook_anchor:" + letter, item["anchor"]["canonical_word"].casefold() == shared["anchor_en"].casefold())
        check("shared_codebook_labels:" + letter, all(item["anchor"][field] == shared[field] for field in ("canonical_word_zh", "representative_label_zh")))
        check("shared_codebook_node:" + letter, item["scene_ref"]["learning_node"] == shared["prologue_learning_node"] and item["scene_ref"]["room_id"] == shared["landmark_room_id"])
    check("nose_single_story_authority", "example_story_cn" not in prologue["later_encoding_bridge"] and prologue["later_encoding_bridge"]["content_ref"]["entry_id"] in entries)
    nose_ref = prologue["later_encoding_bridge"]["content_ref"]
    check("nose_identity", all(nose_ref[field] == entries[nose_ref["entry_id"]][field] for field in ("lexeme_id", "sense_id")))
    handoff = prologue["handoff"]["curriculum_entry_ref"]
    check("selected_start_book_handoff", set(handoff["start_book_options"]) == set(books) and handoff["event_id_rule"] == "event/{curriculum_route.selected_start_book_id}/unit-1")
    check("all_start_events_exist", all(any(unit["book_id"] == book_id and unit["unit_id"] == "unit-1" for unit in units) for book_id in handoff["start_book_options"]))
    check("new_and_legacy_route_boundary", integration["curriculum_route"]["new_save_requires_all_26_supported_experiences"] and not integration["curriculum_route"]["legacy_save_forced_prologue_retake"])
    check("supported_reward_equality", integration["rewards"]["same_for_supported_and_independent_story_completion"] and integration["rewards"]["announce_after_successful_save"] and not integration["rewards"]["replay_grants_again"])
    check("optional_review", integration["review"]["optional"] and not integration["review"]["blocks_next_chapter"] and not integration["review"]["missed_days_penalty"])
    world_clock = integration["clocks"]["environment_world_clock"]
    check("all_npc_pause_scope", world_clock["all_npc_schedule_and_background_motion_paused"] and world_clock["includes_offscreen_npcs"] and set(world_clock["pause_during"]) == {"dialogue", "memory", "teaching", "pause_menu", "application_background"})
    check("retention_not_game_day", not integration["clocks"]["learning_real_time"]["sleep_advances_retention"] and not integration["clocks"]["game_day"]["advanced_by_visual_day_cycle"])
    check("recognition_not_forced_spelling", vocabulary_contract["requirement_permissions"]["recognition"]["formal_spelling_eligible"] is False)

    required_docs = ["README.md", "字母岛主线总策划.md", "字母探索序章.md", "首章详细流程.md", "教材章节与主线事件.md", "主线状态与成长规则.md", "词汇记忆模块接入约定.md", "整合核查与修订.md", "integration_contract.json"]
    for name in required_docs:
        path = HERE / name
        check("document_exists:" + name, path.is_file())
    for path in HERE.glob("*.md"):
        for raw in re.findall(r"\[[^\]]*\]\(([^)]+)\)", path.read_text(encoding="utf-8")):
            target = raw.strip("<>").split("#", 1)[0]
            if not target or re.match(r"^[a-z]+://", target, re.I):
                continue
            linked = (path.parent / unquote(target)).resolve()
            if linked == HERE / "validation_report.json":
                continue
            check("local_link:" + path.name + ":" + target, linked.exists())

    failures = [entry for entry in checks if not entry["pass"]]
    result = {
        "schema_version": 1,
        "validated_at": datetime.now(timezone(timedelta(hours=8))).isoformat(),
        "result": "PASS" if not failures else "FAIL",
        "scope": "Planning provenance, unit/letter coverage, vocabulary adapter identity/unit/revision joins, source-cast candidates, H0-H5 evidence rules, clock/reward/route contracts, existing anchors and local links. Source snapshot is historical; current hashes are checked separately. No gameplay or learning-efficacy test.",
        "books": len(books), "unit_events": len(units), "alphabet_entries": len(letters),
        "vocabulary_occurrences": len(entries), "vocabulary_unit_associations": association_count,
        "content_revision": adapter["content_revision"], "codebook_revision": adapter["codebook_revision"],
        "evidence_levels": dict(evidence_counts),
        "checks": len(checks), "failures": failures, "warnings": warnings,
    }
    (HERE / "validation_report.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
